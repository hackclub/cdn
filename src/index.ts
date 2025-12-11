import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { env } from './env';
import { logger } from './logger';
import { authMiddleware, errorHandler } from './middleware';
import uploadRoutes from './routes/upload';

const app = new Hono();

app.use('*', cors());
app.use('*', errorHandler);

app.get('/', (c) => c.redirect('https://github.com/hackclub/cdn'));

app.route('/api', new Hono()
  .use('*', authMiddleware)
  .get('/health', (c) => c.json({ status: 'ok' }))
  .route('/', uploadRoutes)
);

app.notFound((c) => {
  logger.warn(`Unhandled route: ${c.req.method} ${c.req.path}`);
  return c.json({ error: 'Not found' }, 404);
});

export default {
  port: env.PORT,
  fetch: app.fetch
};
