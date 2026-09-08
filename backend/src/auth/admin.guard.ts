import {
  CanActivate,
  ExecutionContext,
  Injectable,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { Errors } from "../common/errors";

/**
 * Gates /admin/* routes on an explicit allowlist of user ids
 * (ADMIN_USER_IDS env, comma-separated). Unset/empty list → nobody is admin,
 * which is the safe default until an operator promotes themselves.
 */
@Injectable()
export class AdminGuard implements CanActivate {
  constructor(private readonly config: ConfigService) {}

  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest() as {
      user?: { id: string };
    };
    const allowed = (this.config.get<string>("ADMIN_USER_IDS") ?? "")
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean);
    const uid = req.user?.id;
    if (!uid || !allowed.includes(uid)) {
      throw Errors.forbidden("ADMIN_REQUIRED", "Admin access is required for this endpoint");
    }
    return true;
  }
}
