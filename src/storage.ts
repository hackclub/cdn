import { S3Client } from 'bun';
import crypto from 'crypto';
import { env } from './env';

export const MAX_FILE_SIZE = 2 * 1024 * 1024 * 1024;

const s3 = new S3Client({
  accessKeyId: env.S3_ACCESS_KEY_ID,
  secretAccessKey: env.S3_SECRET_ACCESS_KEY,
  endpoint: env.S3_ENDPOINT,
  bucket: env.S3_BUCKET,
});

export function sanitizeFileName(fileName: string): string {
  return fileName.replace(/[^a-zA-Z0-9.-]/g, '_') || `upload_${Date.now()}`;
}

export function generateUniqueFileName(fileName: string): string {
  return `${Date.now()}-${crypto.randomBytes(8).toString('hex')}-${sanitizeFileName(fileName)}`;
}

export function generateFileUrl(userDir: string, fileName: string): string {
  return `${env.CDN_URL}/${userDir}/${fileName}`;
}

export async function uploadToStorage(
  userDir: string,
  uniqueFileName: string,
  bodyData: Buffer,
  contentType = 'application/octet-stream'
): Promise<{ success: boolean; error?: string }> {
  try {
    await s3.write(`${userDir}/${uniqueFileName}`, bodyData, {
      type: contentType,
    });
    return { success: true };
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return { success: false, error: message };
  }
}

export async function uploadStream(
  key: string,
  stream: ReadableStream,
  contentType: string
): Promise<{ success: boolean; error?: string }> {
  try {
    const file = s3.file(key);
    const writer = file.writer({ type: contentType });
    
    for await (const chunk of stream) {
      writer.write(chunk);
    }
    await writer.end();
    
    return { success: true };
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return { success: false, error: message };
  }
}
