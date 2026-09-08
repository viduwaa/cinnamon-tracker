import "reflect-metadata";
import { NestFactory } from "@nestjs/core";
import { type NestExpressApplication } from "@nestjs/platform-express";
import { AppModule } from "./app.module";

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  // Behind nginx/Cloudflare (or a tunnel) req.ip must come from X-Forwarded-For,
  // otherwise every client shares the proxy's IP and rate limits collapse
  // into one bucket. TRUST_PROXY = number of proxy hops in front of us.
  app.set("trust proxy", Number(process.env.TRUST_PROXY ?? 1));
  // The public verify portal stays prefix-free so QR codes can encode a clean
  // URL (PLAN §3.7); the same handler is mirrored under /v1/verify for API
  // clients (see verify-v1.controller.ts). Both paths are excluded from the
  // global prefix.
  app.setGlobalPrefix("v1", {
    exclude: ["health", "verify/:batchNo", "v1/verify/:batchNo"],
  });
  // Validation, error normalization, idempotency and rate limiting are wired
  // via APP_PIPE / APP_FILTER / APP_GUARD / APP_INTERCEPTOR in AppModule.
  app.enableCors();
  const port = Number(process.env.PORT ?? 3100); // matches the Flutter dev base URL
  await app.listen(port);
  // eslint-disable-next-line no-console
  console.log(`Cinnamon Trace API listening on :${port}`);
}

void bootstrap();
