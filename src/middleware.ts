import type { Context, Next } from 'hono';
import { logger } from './logger';

export async function authMiddleware(c: Context, next: Next) {
  const authHeader = c.req.header('Authorization');
  const token = authHeader?.split('Bearer ')[1];

  if (!token || token !== process.env.API_TOKEN) {
    return c.json({ error: 'Unauthorized - Invalid or missing API token' }, 401);
  }

  await next();
}

export async function errorHandler(c: Context, next: Next) {
  try {
    await next();
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    logger.error('Request error:', {
      error: message,
      path: c.req.path,
      method: c.req.method
    });
    return c.json({ error: 'Internal server error' }, 500);
  }
}
