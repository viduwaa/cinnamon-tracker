import {
  CanActivate,
  ExecutionContext,
  Injectable,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { JwtService } from "@nestjs/jwt";
import { Errors } from "../common/errors";
import type { AdminPrincipal } from "./admin-auth.service";

/**
 * Governs every /v1/admin/* route (except /auth/login). Verifies the JWT
 * signature against the same secret as app tokens but ALSO requires the
 * `kind: "admin"` claim — an app-user JWT, even if valid, can never open the
 * admin namespace. Env-var allowlist (ADMIN_USER_IDS) is retired by this
 * module: admins are now rows in admin_users, seeded by scripts/create-admin.ts.
 */
@Injectable()
export class AdminGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest() as {
      headers: Record<string, string | undefined>;
      user?: AdminPrincipal;
    };
    const header = req.headers.authorization;
    if (!header?.startsWith("Bearer ")) {
      throw Errors.unauthorized("ADMIN_TOKEN_REQUIRED", "Admin authentication required");
    }
    let payload: Record<string, unknown>;
    try {
      payload = this.jwt.verify(header.slice(7), {
        secret: this.config.get<string>("JWT_SECRET") ?? process.env.JWT_SECRET,
      });
    } catch {
      throw Errors.unauthorized("ADMIN_TOKEN_INVALID", "Invalid or expired admin session");
    }
    if (payload.kind !== "admin" || typeof payload.sub !== "string") {
      throw Errors.unauthorized("ADMIN_TOKEN_INVALID", "Not an admin token");
    }
    req.user = { id: payload.sub, email: String(payload.email ?? "") };
    return true;
  }
}
