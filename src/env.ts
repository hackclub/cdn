import { type } from 'arktype';

const envSchema = type({
  AWS_REGION: 'string',
  AWS_ENDPOINT: 'string',
  AWS_ACCESS_KEY_ID: 'string',
  AWS_SECRET_ACCESS_KEY: 'string',
  AWS_BUCKET_NAME: 'string',
  AWS_CDN_URL: 'string',
  API_TOKEN: 'string',
  PORT: 'string.numeric.parse = "4553"',
});

export type Env = typeof envSchema.infer;

function validateEnv(): Env {
  const result = envSchema(process.env);

  if (result instanceof type.errors) {
    console.error('❌ Invalid environment variables:');
    for (const error of result) {
      console.error(`  - ${error.path}: ${error.message}`);
    }
    process.exit(1);
  }

  return result;
}

export const env = validateEnv();
