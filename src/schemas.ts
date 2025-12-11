import { type } from 'arktype';

export const urlArraySchema = type('string[]');

export const uploadBodySchema = type({
  url: 'string'
}).or('string');

export const envSchema = type({
  AWS_REGION: 'string',
  AWS_ENDPOINT: 'string',
  AWS_ACCESS_KEY_ID: 'string',
  AWS_SECRET_ACCESS_KEY: 'string',
  AWS_BUCKET_NAME: 'string',
  AWS_CDN_URL: 'string',
  API_TOKEN: 'string',
  'PORT?': 'string',
  'SLACK_BOT_TOKEN?': 'string'
});

export type Env = typeof envSchema.infer;
