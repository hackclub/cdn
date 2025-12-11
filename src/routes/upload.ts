import { Hono } from 'hono';
import crypto from 'crypto';
import { type } from 'arktype';
import { Readable } from 'stream';
import { env } from '../env';
import { logger } from '../logger';
import {
  uploadToStorage,
  uploadStream,
  sanitizeFileName,
  generateUniqueFileName,
  generateFileUrl,
  MAX_FILE_SIZE
} from '../storage';

const upload = new Hono();

const urlArraySchema = type('string[]').narrow((urls, ctx) => {
  if (urls.length === 0) {
    return ctx.mustBe('a non-empty array');
  }
  if (urls.length > 100) {
    return ctx.mustBe('an array with at most 100 URLs');
  }
  return true;
});

const singleUrlSchema = type('string').narrow((url, ctx) => {
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    return ctx.mustBe('a valid HTTP(S) URL');
  }
  return true;
});

const uploadBodySchema = type({
  url: 'string'
}).or('string');

interface UploadResult {
  url: string;
  sha: string;
  size: number;
  type: string | null;
}

interface UploadError {
  error: {
    message: string;
    code: string;
    url?: string;
  };
  success: false;
}

async function uploadFromUrl(url: string, downloadAuth?: string): Promise<UploadResult> {
  const headers: Record<string, string> = {};
  if (downloadAuth) {
    headers['Authorization'] = downloadAuth.startsWith('Bearer ') ? downloadAuth : `Bearer ${downloadAuth}`;
  }

  const response = await fetch(url, { headers });

  if (!response.ok) {
    const error: UploadError = {
      error: {
        message: response.status === 401 || response.status === 403 
          ? 'Authentication failed for protected resource' 
          : `Download failed: ${response.statusText}`,
        code: response.status === 401 || response.status === 403 ? 'AUTH_FAILED' : 'DOWNLOAD_FAILED',
        url
      },
      success: false
    };
    throw error;
  }

  const buffer = Buffer.from(await response.arrayBuffer());
  const sha = crypto.createHash('sha1').update(buffer).digest('hex');
  const originalName = url.split('/').pop() || 'file';
  const sanitized = sanitizeFileName(originalName);
  const fileName = `${sha}_${sanitized}`;
  const contentType = response.headers.get('content-type') || 'application/octet-stream';

  const uploadResult = await uploadToStorage('s/v3', fileName, buffer, contentType, buffer.length);
  if (!uploadResult.success) {
    throw new Error(`Storage upload failed: ${uploadResult.error}`);
  }

  return {
    url: generateFileUrl('s/v3', fileName),
    sha,
    size: buffer.length,
    type: contentType
  };
}

function formatResponse(results: UploadResult[], version: number) {
  switch (version) {
    case 1:
      return results.map((r) => r.url);
    case 2:
      return results.reduce<Record<string, string>>((acc, r, i) => {
        const fileName = r.url.split('/').pop()!;
        acc[`${i}${fileName}`] = r.url;
        return acc;
      }, {});
    default:
      return {
        files: results.map((r, i) => ({
          deployedUrl: r.url,
          file: `${i}_${r.url.split('/').pop()}`,
          sha: r.sha,
          size: r.size
        })),
        cdnBase: env.AWS_CDN_URL
      };
  }
}

async function handleBulkUpload(c: any, version: number) {
  const body = await c.req.json();
  const parsed = urlArraySchema(body);

  if (parsed instanceof type.errors) {
    return c.json({ error: parsed.summary, code: 'VALIDATION_ERROR' }, 422);
  }

  const downloadAuth = c.req.header('x-download-authorization');
  logger.debug(`Processing ${parsed.length} URLs`);

  const results = await Promise.all(parsed.map((url) => uploadFromUrl(url, downloadAuth)));
  return c.json(formatResponse(results, version));
}

upload.post('/v1/new', (c) => handleBulkUpload(c, 1));
upload.post('/v2/new', (c) => handleBulkUpload(c, 2));
upload.post('/v3/new', (c) => handleBulkUpload(c, 3));
upload.post('/new', (c) => handleBulkUpload(c, 3));

upload.post('/upload', async (c) => {
  try {
    const body = await c.req.text();
    let rawUrl: string;

    try {
      const parsed = JSON.parse(body);
      rawUrl = typeof parsed === 'string' ? parsed : parsed.url;
    } catch {
      rawUrl = body;
    }

    const urlResult = singleUrlSchema(rawUrl);
    if (urlResult instanceof type.errors) {
      return c.json(
        { error: { message: urlResult.summary, code: 'VALIDATION_ERROR' }, success: false },
        400
      );
    }

    const url = urlResult;
    const downloadAuth = c.req.header('x-download-authorization');

    if (url.includes('files.slack.com') && !downloadAuth) {
      return c.json(
        {
          error: {
            message: 'X-Download-Authorization required for Slack files',
            code: 'AUTH_REQUIRED',
            details: 'Slack files require authentication'
          },
          success: false
        },
        400
      );
    }

    const result = await uploadFromUrl(url, downloadAuth);
    return c.json(result);
  } catch (error) {
    if (error && typeof error === 'object' && 'error' in error) {
      return c.json(error, 500);
    }
    logger.error('Upload failed:', error);
    return c.json({ error: { message: 'Internal server error', code: 'INTERNAL_ERROR' }, success: false }, 500);
  }
});

upload.post('/file', async (c) => {
  try {
    const formData = await c.req.formData();
    const file = formData.get('file');

    if (!file || !(file instanceof File)) {
      return c.json({ error: 'No file uploaded' }, 400);
    }

    if (file.size > MAX_FILE_SIZE) {
      return c.json({ error: 'File too large' }, 413);
    }

    const uniqueName = generateUniqueFileName(file.name);
    const contentType = file.type || 'application/octet-stream';
    const key = `s/v3/${uniqueName}`;

    const webStream = file.stream();
    const nodeStream = Readable.fromWeb(webStream as any);

    const result = await uploadStream(key, nodeStream, contentType, file.size);
    if (!result.success) {
      throw new Error(result.error);
    }

    return c.json({
      url: generateFileUrl('s/v3', uniqueName),
      size: file.size,
      type: contentType
    });
  } catch (error) {
    logger.error('Direct upload error:', error);
    return c.json({ error: 'Upload failed' }, 500);
  }
});

upload.post('/files', async (c) => {
  try {
    const formData = await c.req.formData();
    const files = formData.getAll('files');

    if (!files.length) {
      return c.json({ error: 'No files uploaded' }, 400);
    }

    if (files.length > 10) {
      return c.json({ error: 'Maximum 10 files allowed' }, 400);
    }

    const results = await Promise.all(
      files.map(async (file) => {
        if (!(file instanceof File)) {
          throw new Error('Invalid file');
        }

        if (file.size > MAX_FILE_SIZE) {
          throw new Error(`File ${file.name} too large`);
        }

        const uniqueName = generateUniqueFileName(file.name);
        const contentType = file.type || 'application/octet-stream';
        const key = `s/v3/${uniqueName}`;

        const webStream = file.stream();
        const nodeStream = Readable.fromWeb(webStream as any);

        const result = await uploadStream(key, nodeStream, contentType, file.size);
        if (!result.success) {
          throw new Error(result.error);
        }

        return {
          url: generateFileUrl('s/v3', uniqueName),
          size: file.size,
          type: contentType
        };
      })
    );

    return c.json({ files: results, cdnBase: env.AWS_CDN_URL });
  } catch (error) {
    logger.error('Bulk direct upload error:', error);
    return c.json({ error: 'Upload failed' }, 500);
  }
});

export default upload;
