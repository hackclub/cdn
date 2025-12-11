import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from './logger';
import { authMiddleware, errorHandler } from './middleware';
import uploadRoutes from './routes/upload';

logger.info('Starting CDN application 🚀');

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

const port = parseInt(process.env.PORT || '4553', 10);

export default {
  port,
  fetch: app.fetch
};

logger.info('CDN started successfully 🔥', {
  apiPort: port,
  startTime: new Date().toISOString()
});
