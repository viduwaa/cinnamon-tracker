import { createParamDecorator, ExecutionContext } from "@nestjs/common";
import type { AdminPrincipal } from "./admin-auth.service";

/** Extracts the verified admin principal placed on the request by AdminGuard. */
export const CurrentAdmin = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): AdminPrincipal => {
    const request = ctx.switchToHttp().getRequest();
    return request.user as AdminPrincipal;
  },
);
