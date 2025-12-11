import {
  S3Client,
  PutObjectCommand,
  CreateMultipartUploadCommand,
  UploadPartCommand,
  CompleteMultipartUploadCommand,
  AbortMultipartUploadCommand
} from '@aws-sdk/client-s3';
import { Upload } from '@aws-sdk/lib-storage';
import { NodeHttpHandler } from '@smithy/node-http-handler';
import crypto from 'crypto';
import { env } from './env';
import { logger } from './logger';

export const MAX_FILE_SIZE = 2 * 1024 * 1024 * 1024;
export const MULTIPART_THRESHOLD = 10 * 1024 * 1024;
const PART_UPLOAD_CONCURRENCY = 4;

let s3Client: S3Client | null = null;

export function getS3Client(): S3Client {
  if (!s3Client) {
    s3Client = new S3Client({
      region: env.AWS_REGION,
      endpoint: env.AWS_ENDPOINT,
      requestHandler: new NodeHttpHandler({
        connectionTimeout: 5000,
        socketTimeout: 300000
      }),
      credentials: {
        accessKeyId: env.AWS_ACCESS_KEY_ID,
        secretAccessKey: env.AWS_SECRET_ACCESS_KEY
      },
      forcePathStyle: true,
      maxAttempts: 3
    });
  }
  return s3Client;
}

export function sanitizeFileName(fileName: string): string {
  const sanitized = fileName.replace(/[^a-zA-Z0-9.-]/g, '_');
  return sanitized || `upload_${Date.now()}`;
}

export function generateUniqueFileName(fileName: string): string {
  const sanitized = sanitizeFileName(fileName);
  return `${Date.now()}-${crypto.randomBytes(8).toString('hex')}-${sanitized}`;
}

export function generateFileUrl(userDir: string, fileName: string): string {
  return `${env.AWS_CDN_URL}/${userDir}/${fileName}`;
}

function calculatePartSize(fileSize: number): number {
  const MIN_PSIZE = 5242880;
  const MAX_PSIZE = 100 * 1024 * 1024;
  const MAX_PARTS = 1000;

  let partSize = MIN_PSIZE;

  if (fileSize / MIN_PSIZE > MAX_PARTS) {
    partSize = Math.ceil(fileSize / MAX_PARTS);
  }

  if (fileSize > 100 * 1024 * 1024) partSize = Math.max(partSize, 10 * 1024 * 1024);
  if (fileSize > 500 * 1024 * 1024) partSize = Math.max(partSize, 25 * 1024 * 1024);
  if (fileSize > 1024 * 1024 * 1024) partSize = Math.max(partSize, 50 * 1024 * 1024);

  return Math.min(Math.max(partSize, MIN_PSIZE), MAX_PSIZE);
}

export interface UploadResult {
  success: boolean;
  error?: string;
}

export async function uploadToStorage(
  userDir: string,
  uniqueFileName: string,
  bodyData: Buffer,
  contentType = 'application/octet-stream',
  fileSize: number
): Promise<UploadResult> {
  try {
    const key = `${userDir}/${uniqueFileName}`;
    const client = getS3Client();

    if (fileSize >= MULTIPART_THRESHOLD) {
      return await uploadMultipart(key, bodyData, contentType);
    }

    await client.send(
      new PutObjectCommand({
        Bucket: env.AWS_BUCKET_NAME,
        Key: key,
        Body: bodyData,
        ContentType: contentType,
        CacheControl: 'public, immutable, max-age=31536000',
        ContentLength: fileSize
      })
    );

    return { success: true };
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    logger.error(`Upload failed: ${message}`, { path: `${userDir}/${uniqueFileName}` });
    return { success: false, error: message };
  }
}

export async function uploadStream(
  key: string,
  stream: import('stream').Readable,
  contentType: string,
  contentLength?: number
): Promise<UploadResult> {
  try {
    const client = getS3Client();

    const upload = new Upload({
      client,
      params: {
        Bucket: env.AWS_BUCKET_NAME,
        Key: key,
        Body: stream,
        ContentType: contentType,
        CacheControl: 'public, immutable, max-age=31536000',
        ContentLength: contentLength
      },
      queueSize: PART_UPLOAD_CONCURRENCY,
      partSize: MULTIPART_THRESHOLD
    });

    await upload.done();
    return { success: true };
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    logger.error(`Stream upload failed: ${message}`, { key });
    return { success: false, error: message };
  }
}

async function uploadMultipart(
  key: string,
  bodyData: Buffer,
  contentType: string
): Promise<UploadResult> {
  const client = getS3Client();
  let uploadId: string | undefined;

  try {
    const createResult = await client.send(
      new CreateMultipartUploadCommand({
        Bucket: env.AWS_BUCKET_NAME,
        Key: key,
        ContentType: contentType,
        CacheControl: 'public, immutable, max-age=31536000'
      })
    );
    uploadId = createResult.UploadId;

    const partSize = calculatePartSize(bodyData.length);
    const totalParts = Math.ceil(bodyData.length / partSize);

    const uploadPromises: Promise<{ PartNumber: number; ETag: string | undefined }>[] = [];

    for (let partNumber = 1; partNumber <= totalParts; partNumber++) {
      const start = (partNumber - 1) * partSize;
      const end = Math.min(start + partSize, bodyData.length);
      const partData = bodyData.subarray(start, end);

      uploadPromises.push(
        client
          .send(
            new UploadPartCommand({
              Bucket: env.AWS_BUCKET_NAME,
              Key: key,
              PartNumber: partNumber,
              UploadId: uploadId,
              Body: partData
            })
          )
          .then((result) => ({
            PartNumber: partNumber,
            ETag: result.ETag
          }))
      );
    }

    const parts = await Promise.all(uploadPromises);
    parts.sort((a, b) => a.PartNumber - b.PartNumber);

    await client.send(
      new CompleteMultipartUploadCommand({
        Bucket: env.AWS_BUCKET_NAME,
        Key: key,
        UploadId: uploadId,
        MultipartUpload: { Parts: parts }
      })
    );

    return { success: true };
  } catch (error) {
    if (uploadId) {
      try {
        await client.send(
          new AbortMultipartUploadCommand({
            Bucket: env.AWS_BUCKET_NAME,
            Key: key,
            UploadId: uploadId
          })
        );
      } catch (abortError) {
        const msg = abortError instanceof Error ? abortError.message : 'Unknown';
        logger.error(`Failed to abort multipart upload: ${msg}`);
      }
    }
    throw error;
  }
}

export async function downloadFile(url: string, authHeader?: string): Promise<Buffer> {
  const headers: Record<string, string> = {};
  if (authHeader) {
    headers['Authorization'] = authHeader.startsWith('Bearer ') ? authHeader : `Bearer ${authHeader}`;
  }

  const response = await fetch(url, { headers });

  if (!response.ok) {
    throw new Error(`Download failed: ${response.status} ${response.statusText}`);
  }

  return Buffer.from(await response.arrayBuffer());
}
