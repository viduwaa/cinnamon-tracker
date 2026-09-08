import type { ConfigService } from "@nestjs/config";

/**
 * Single source of truth for the JWT signing/verification secret.
 * Fails fast in production when unset — a publicly-known fallback secret
 * would let anyone mint valid tokens. Falls back to a labeled dev-only
 * secret outside production so local flows still work.
 */
export function resolveJwtSecret(config?: Pick<ConfigService, "get">): string {
  const secret = config?.get<string>("JWT_SECRET") ?? process.env.JWT_SECRET;
  const nodeEnv =
    config?.get<string>("NODE_ENV") ?? (process.env.NODE_ENV || "development");
  if (!secret) {
    if (nodeEnv === "production") {
      throw new Error("JWT_SECRET must be set when NODE_ENV=production");
    }
    return "dev-only-insecure-secret";
  }
  return secret;
}

export function isProduction(config?: Pick<ConfigService, "get">): boolean {
  return (
    (config?.get<string>("NODE_ENV") ?? (process.env.NODE_ENV || "development")) ===
    "production"
  );
}
