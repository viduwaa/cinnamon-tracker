import { HttpException, HttpStatus } from "@nestjs/common";

/**
 * Domain errors mapped to HTTP. Controllers/services throw these; the global
 * filter (AllExceptionsFilter) converts everything — DomainError, validation
 * errors, pg constraint violations, unknown errors — to the standard error
 * envelope: { error: { code, message, details? } }
 */

export class DomainError extends HttpException {
  constructor(
    public readonly code: string,
    message: string,
    status: HttpStatus = HttpStatus.BAD_REQUEST,
    public readonly details?: unknown,
  ) {
    super({ error: { code, message, details } }, status);
  }
}

export const Errors = {
  notFound: (code: string, message: string) =>
    new DomainError(code, message, HttpStatus.NOT_FOUND),
  forbidden: (code: string, message: string) =>
    new DomainError(code, message, HttpStatus.FORBIDDEN),
  conflict: (code: string, message: string, details?: unknown) =>
    new DomainError(code, message, HttpStatus.CONFLICT, details),
  badRequest: (code: string, message: string, details?: unknown) =>
    new DomainError(code, message, HttpStatus.BAD_REQUEST, details),
  unauthorized: (code: string, message: string) =>
    new DomainError(code, message, HttpStatus.UNAUTHORIZED),
  tooManyRequests: (code: string, message: string) =>
    new DomainError(code, message, HttpStatus.TOO_MANY_REQUESTS),
  serviceUnavailable: (code: string, message: string) =>
    new DomainError(code, message, HttpStatus.SERVICE_UNAVAILABLE),
};

/** Thrown by the ValidationPipe exceptionFactory; field-level details[]. */
export class ValidationError extends DomainError {
  constructor(details: Array<{ field: string; constraints: string[] }>) {
    super("VALIDATION_ERROR", "Please check your input", HttpStatus.BAD_REQUEST, details);
  }
}
