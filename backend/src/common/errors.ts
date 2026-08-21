import { HttpException, HttpStatus } from "@nestjs/common";

/**
 * Domain errors mapped to HTTP. Controllers/services throw these; a global
 * filter (registered in main) converts them to the standard error envelope:
 * { error: { code, message, details? } }
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
};
