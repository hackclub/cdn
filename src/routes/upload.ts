import { Hono } from 'hono';
import crypto from 'crypto';
import { type } from 'arktype';
import { env } from '../env';
import { logger } from '../logger';
import {
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

interface UploadResult {
  url: string;
  id: string;
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

  const id = crypto.randomBytes(8).toString('hex');
  const originalName = url.split('/').pop() || 'file';
  const fileName = `${id}_${sanitizeFileName(originalName)}`;
  const contentType = response.headers.get('content-type') || 'application/octet-stream';
  const size = Number(response.headers.get('content-length')) || 0;

  const uploadResult = await uploadStream(`s/v3/${fileName}`, response.body!, contentType);
  if (!uploadResult.success) {
    throw new Error(`Storage upload failed: ${uploadResult.error}`);
  }

  return { url: generateFileUrl('s/v3', fileName), id, size, type: contentType };
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
          id: r.id,
          size: r.size
        })),
        cdnBase: env.CDN_URL
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

  const settled = await Promise.allSettled(parsed.map((url) => uploadFromUrl(url, downloadAuth)));

  const results: UploadResult[] = [];
  const errors: { url: string; error: string }[] = [];

  settled.forEach((result, index) => {
    if (result.status === 'fulfilled') {
      results.push(result.value);
    } else {
      const errorMessage = result.reason?.error?.message || result.reason?.message || 'Unknown error';
      errors.push({ url: parsed[index], error: errorMessage });
      logger.warn(`Failed to upload URL: ${parsed[index]} - ${errorMessage}`);
    }
  });

  if (errors.length > 0) {
    return c.json({ error: 'One or more uploads failed', code: 'UPLOAD_FAILED', failed: errors }, 400);
  }

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

    const url = singleUrlSchema(rawUrl);
    if (url instanceof type.errors) {
      return c.json(
        { error: { message: url.summary, code: 'VALIDATION_ERROR' }, success: false },
        400
      );
    }

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
    const file = (await c.req.formData()).get('file');

    if (!file || !(file instanceof File)) {
      return c.json({ error: 'No file uploaded' }, 400);
    }

    if (file.size > MAX_FILE_SIZE) {
      return c.json({ error: 'File too large' }, 413);
    }

    const uniqueName = generateUniqueFileName(file.name);
    const contentType = file.type || 'application/octet-stream';

    const result = await uploadStream(`s/v3/${uniqueName}`, file.stream(), contentType);
    if (!result.success) {
      throw new Error(result.error);
    }

    return c.json({ url: generateFileUrl('s/v3', uniqueName), size: file.size, type: contentType });
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

        const result = await uploadStream(`s/v3/${uniqueName}`, file.stream(), contentType);
        if (!result.success) {
          throw new Error(result.error);
        }

        return { url: generateFileUrl('s/v3', uniqueName), size: file.size, type: contentType };
      })
    );

    return c.json({ files: results, cdnBase: env.CDN_URL });
  } catch (error) {
    logger.error('Bulk direct upload error:', error);
    return c.json({ error: 'Upload failed' }, 500);
  }
});

export default upload;
