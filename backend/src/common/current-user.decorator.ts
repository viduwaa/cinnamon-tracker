import { createParamDecorator, ExecutionContext } from "@nestjs/common";

/** Extracts the authenticated user id placed on the request by the JWT guard. */
export const CurrentUserId = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): string => {
    const request = ctx.switchToHttp().getRequest();
    return request.user?.id as string;
  },
);
