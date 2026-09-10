import { Injectable } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { JwtService } from "@nestjs/jwt";
import * as bcrypt from "bcryptjs";
import { DatabaseService } from "../database/database.service";
import { Errors } from "../common/errors";

/**
 * Admin authentication — completely separate credential store from app users.
 * Government operators log in with email + password (bcrypt, cost 12); there
 * is deliberately no registration endpoint: admins are seeded by the operator
 * (scripts/create-admin.ts) on the server.
 */
@Injectable()
export class AdminAuthService {
  constructor(
    private readonly db: DatabaseService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async login(email: string, password: string) {
    const admin = await this.db.queryOne<{
      id: string;
      email: string;
      name: string;
      password_hash: string;
      is_active: boolean;
    }>(
      "SELECT id, email, name, password_hash, is_active FROM admin_users WHERE lower(email) = lower($1)",
      [email],
    );
    // Same error either way — do not reveal whether the email exists.
    if (!admin) throw Errors.unauthorized("ADMIN_INVALID", "Invalid email or password");
    const ok = await bcrypt.compare(password, admin.password_hash);
    if (!ok) throw Errors.unauthorized("ADMIN_INVALID", "Invalid email or password");
    if (!admin.is_active) {
      throw Errors.forbidden("ADMIN_DISABLED", "This admin account is disabled");
    }

    await this.db.query(
      "INSERT INTO audit_log (user_id, action, entity, entity_id) VALUES ($1, $2, $3, $4)",
      [admin.id, "ADMIN_LOGIN", "admin_user", admin.id],
    );

    const token = this.jwt.sign({ sub: admin.id, email: admin.email, kind: "admin" });
    return {
      token,
      expires_in: this.expiresInSeconds(),
      admin: { id: admin.id, email: admin.email, name: admin.name },
    };
  }

  private expiresInSeconds(): number {
    const raw = this.config.get<string>("JWT_EXPIRES_IN") ?? "1d";
    const match = raw.match(/^(\d+)([smhd])$/);
    if (!match) return 86400;
    const n = Number(match[1]);
    const unit = match[2];
    const mult = unit === "s" ? 1 : unit === "m" ? 60 : unit === "h" ? 3600 : 86400;
    return n * mult;
  }
}

/** Shape attached to the request by AdminGuard after verification. */
export interface AdminPrincipal {
  id: string;
  email: string;
}
