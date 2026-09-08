import { Injectable, NestMiddleware } from "@nestjs/common";
import { randomUUID } from "node:crypto";
import type { NextFunction, Request, Response } from "express";

/** Attach a per-request id for log correlation; echoed back on responses
 *  (also by the exception filter on errors). */
@Injectable()
export class RequestIdMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction) {
    const incoming = req.header("x-request-id");
    const id = incoming && /^[\w-]{8,64}$/.test(incoming) ? incoming : randomUUID();
    (req as Request & { id: string }).id = id;
    res.setHeader("X-Request-Id", id);
    next();
  }
}
