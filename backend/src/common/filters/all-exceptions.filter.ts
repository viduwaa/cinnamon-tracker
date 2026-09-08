import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from "@nestjs/common";

interface PgViolationLike {
  code?: string;
  constraint?: string;
}

/**
 * Global error normalization. Everything leaving the API uses the envelope:
 *   { "error": { "code": "...", "message": "...", "details"?: ... } }
 * - DomainError passes through (already shaped).
 * - pg unique violations (SQLSTATE 23505) map to domain codes — the race-safe
 *   fallback for BATCH_NO_TAKEN / MOBILE_TAKEN and duplicate client ids.
 * - ValidationPipe / framework exceptions map to stable codes per api-spec §11.
 * - Unknown errors → 500 INTERNAL_ERROR; stack logged server-side only.
 */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const res = ctx.getResponse() as import("express").Response;
    const req = ctx.getRequest() as import("express").Request & { id?: string };
    const { status, body } = this.normalize(exception);
    if (status >= 500) {
      this.logger.error(
        `req=${req.id ?? "-"} ${req.method} ${req.originalUrl} → ${status}`,
        exception instanceof Error ? exception.stack : String(exception),
      );
    }
    if (!res.headersSent) {
      if (req.id) res.setHeader("X-Request-Id", req.id);
      res.status(status).json(body);
    } else {
      res.end();
    }
  }

  private normalize(exception: unknown): {
    status: number;
    body: { error: { code: string; message: string; details?: unknown } };
  } {
    // 1. Our domain errors are already in envelope shape.
    if (
      exception instanceof HttpException &&
      typeof (exception as { code?: string }).code === "string" &&
      exception.getResponse() !== null &&
      typeof exception.getResponse() === "object" &&
      "error" in (exception.getResponse() as object)
    ) {
      return {
        status: exception.getStatus(),
        body: exception.getResponse() as { error: { code: string; message: string; details?: unknown } },
      };
    }

    // 2. pg unique violations → domain codes (pg surfaces these as plain
    //    DatabaseError objects carrying .code/.constraint).
    if (exception instanceof Error && isPgViolation(exception)) {
      const mapped = this.fromPgViolation(exception as PgViolationLike);
      if (mapped) return mapped;
    }

    // 3. Framework/HttpException mapping (ValidationPipe, guards, throttler…).
    if (exception instanceof HttpException) {
      return this.fromHttpException(exception);
    }

    // 4. Non-HttpException errors that still carry an HTTP status (e.g.
    //    body-parser's SyntaxError with .status = 400).
    if (exception instanceof Error) {
      const status = (exception as { status?: unknown }).status;
      if (typeof status === "number" && status >= 400 && status < 500) {
        return {
          status,
          body: {
            error: {
              code: this.codeFor(status),
              message: "Please check your input",
            },
          },
        };
      }
    }

    return {
      status: HttpStatus.INTERNAL_SERVER_ERROR,
      body: {
        error: {
          code: "INTERNAL_ERROR",
          message: "Something went wrong. Please try again.",
        },
      },
    };
  }

  private fromPgViolation(err: PgViolationLike): {
    status: number;
    body: { error: { code: string; message: string } };
  } | null {
    switch (err.constraint) {
      case "users_mobile_key":
        return {
          status: 409,
          body: {
            error: {
              code: "MOBILE_TAKEN",
              message: "This mobile number is already registered",
            },
          },
        };
      case "batches_batch_no_key":
        return {
          status: 409,
          body: {
            error: { code: "BATCH_NO_TAKEN", message: "Batch number already exists" },
          },
        };
      default:
        return null;
    }
  }

  private fromHttpException(exception: HttpException): {
    status: number;
    body: { error: { code: string; message: string; details?: unknown } };
  } {
    const status = exception.getStatus();
    const response = exception.getResponse();

    // class-validator payload: { message: string[] | string, error?, statusCode? }
    if (typeof response === "object" && response !== null && "message" in response) {
      const msg = (response as { message: unknown }).message;
      if (Array.isArray(msg)) {
        return {
          status,
          body: {
            error: {
              code: status === HttpStatus.BAD_REQUEST ? "VALIDATION_ERROR" : this.codeFor(status),
              message: "Please check your input",
              details: msg,
            },
          },
        };
      }
      return {
        status,
        body: {
          error: {
            code: this.codeFor(status),
            message: typeof msg === "string" ? msg : "Please check your input",
          },
        },
      };
    }

    return {
      status,
      body: {
        error: {
          code: this.codeFor(status),
          // 429 from the throttler carries the literal class name as its
          // string body — never show that to farmers (PLAN §8 plain language).
          message:
            status === HttpStatus.TOO_MANY_REQUESTS
              ? "Too many requests. Please wait a moment and try again."
              : typeof response === "string"
                ? response
                : exception.message,
        },
      },
    };
  }

  private codeFor(status: number): string {
    switch (status) {
      case HttpStatus.BAD_REQUEST:
        return "VALIDATION_ERROR";
      case HttpStatus.UNAUTHORIZED:
        return "UNAUTHORIZED";
      case HttpStatus.FORBIDDEN:
        return "FORBIDDEN";
      case HttpStatus.NOT_FOUND:
        return "NOT_FOUND";
      case HttpStatus.CONFLICT:
        return "CONFLICT";
      case HttpStatus.TOO_MANY_REQUESTS:
        return "RATE_LIMITED";
      case HttpStatus.SERVICE_UNAVAILABLE:
        return "SERVICE_UNAVAILABLE";
      default:
        return "ERROR_" + status;
    }
  }
}

function isPgViolation(err: Error): err is Error & PgViolationLike {
  // pg-protocol's DatabaseError carries SQLSTATE in .code and the violated
  // constraint name in .constraint for unique violations (23505).
  const e = err as PgViolationLike;
  return typeof e.constraint === "string" && (e.code?.startsWith("23") ?? false);
}
