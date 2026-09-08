import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from "@nestjs/common";
import { Observable, lastValueFrom, of } from "rxjs";
import { Errors } from "../errors";
import { IdempotencyService } from "./idempotency.service";

const IDEMPOTENT_METHODS = new Set(["POST", "PATCH", "PUT"]);

/**
 * Applies idempotency semantics when a request carries an Idempotency-Key:
 * - first execution → handler runs; a 2xx response body is stored;
 * - replay (same key + same body) → stored body returned with an
 *   `Idempotency-Replayed: true` header — this is what makes the offline
 *   outbox safe against lost responses (duplicate client UUIDv7 ids);
 * - same key + different body → 409 IDEMPOTENCY_KEY_REUSED;
 * - failed executions release the claim so the key stays retryable.
 *
 * Runs after guards: unauthenticated routes and /auth/* are skipped (register
 * is naturally idempotent via MOBILE_TAKEN; OTP re-requests must resend).
 */
@Injectable()
export class IdempotencyInterceptor implements NestInterceptor {
  constructor(private readonly idempotency: IdempotencyService) {}

  async intercept(context: ExecutionContext, next: CallHandler): Promise<Observable<unknown>> {
    const req = context.switchToHttp().getRequest() as {
      method: string;
      originalUrl: string;
      headers: Record<string, string | string[] | undefined>;
      user?: { id: string };
      body?: unknown;
    };

    const header = req.headers["idempotency-key"];
    const key = Array.isArray(header) ? header[0] : header;
    if (!key || !IDEMPOTENT_METHODS.has(req.method) || !req.user?.id) {
      return next.handle();
    }
    const path = req.originalUrl.split("?")[0];
    if (/^\/(v1\/)?auth(\/|$)/.test(path)) return next.handle();

    const endpoint = `${req.method} ${path}`;
    const userId = req.user.id;
    const requestHash = IdempotencyService.requestHash(req.body);

    const claim = await this.idempotency.claim(key, endpoint, userId, requestHash);
    switch (claim.state) {
      case "in_progress":
        throw Errors.conflict(
          "IDEMPOTENCY_IN_PROGRESS",
          "A request with this key is still being processed",
        );
      case "completed": {
        if (claim.requestHash !== requestHash) {
          throw Errors.conflict(
            "IDEMPOTENCY_KEY_REUSED",
            "This key was already used with a different request body",
          );
        }
        const res = context.switchToHttp().getResponse<{ setHeader(k: string, v: string): void }>();
        res.setHeader("Idempotency-Replayed", "true");
        return of(claim.responseBody);
      }
    }

    try {
      const body = await lastValueFrom(next.handle());
      await this.idempotency.complete(
        key,
        endpoint,
        userId,
        req.method as "POST" | "PATCH" | "PUT",
        body,
      );
      return of(body);
    } catch (err) {
      await this.idempotency.release(key, endpoint, userId).catch(() => undefined);
      throw err;
    }
  }
}
