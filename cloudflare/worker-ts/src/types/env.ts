export interface Env {
  DB: D1Database;
  PASSWORD_HASHER?: Fetcher;
  JWT_SECRET?: string;
  AUTH_SECRET?: string;
  STOREFRONT_BASE_URL?: string;
  ENVIRONMENT?: string;
  CORS_ALLOW_ORIGIN?: string;
  WHATSAPP_VERIFY_TOKEN?: string;
  [key: string]: any;
}
