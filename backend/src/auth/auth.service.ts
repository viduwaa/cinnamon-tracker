import { Injectable } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { JwtService } from "@nestjs/jwt";
import { createHash, randomInt } from "node:crypto";
import { DatabaseService } from "../database/database.service";
import { Errors } from "../common/errors";
import { allocateExporterCode } from "../common/exporter-codes";
import { normalizeMobile } from "../common/phone";
import { uuidv7 } from "../common/uuid";
import {
  AddRoleDto,
  OtpRequestDto,
  OtpVerifyDto,
  RegisterDto,
  RoleCode,
  UpdateMeDto,
} from "./dto";
import { SMS_PROVIDER, SmsProvider } from "./sms.provider";
import { Inject } from "@nestjs/common";

interface UserRow {
  id: string;
  name: string;
  mobile: string;
  email: string | null;
  preferred_lang: string;
  created_at: string;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly db: DatabaseService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    @Inject(SMS_PROVIDER) private readonly sms: SmsProvider,
  ) {}

  async register(dto: RegisterDto) {
    const mobile = this.normalizeMobile(dto.mobile);
    const existing = await this.db.queryOne<UserRow>(
      "SELECT id FROM users WHERE mobile = $1",
      [mobile],
    );
    if (existing) {
      throw Errors.conflict("MOBILE_TAKEN", "This mobile number is already registered");
    }

    const userId = uuidv7();
    await this.db.transaction(async (client) => {
      await client.query(
        `INSERT INTO users (id, name, mobile, email, preferred_lang)
         VALUES ($1, $2, $3, $4, $5)`,
        [userId, dto.name, mobile, dto.email ?? null, dto.preferred_lang ?? "si"],
      );
      for (const role of dto.roles) {
        await client.query(
          "INSERT INTO user_roles (user_id, role) VALUES ($1, $2) ON CONFLICT DO NOTHING",
          [userId, role],
        );
      }
      // Exporter identity is baked into lot numbers — allocate at registration
      // so the client can generate lot numbers offline before the first export.
      if (dto.roles.includes("EXPORTER")) {
        await allocateExporterCode(client, userId);
      }
    });

    return this.getPublicUser(userId);
  }

  async requestOtp(dto: OtpRequestDto) {
    const mobile = this.normalizeMobile(dto.mobile);
    const user = await this.db.queryOne<UserRow>(
      "SELECT id FROM users WHERE mobile = $1",
      [mobile],
    );
    if (!user) {
      // Do not reveal whether a mobile is registered.
      return { sent: true };
    }

    const ttl = Number(this.config.get("OTP_TTL_SECONDS") ?? 300);
    const length = Number(this.config.get("OTP_LENGTH") ?? 6);
    const code = this.generateCode(length);
    const codeHash = this.hashCode(code);

    await this.db.query(
      `INSERT INTO otp_codes (id, mobile, code_hash, purpose, expires_at)
       VALUES ($1, $2, $3, 'LOGIN', now() + ($4 || ' seconds')::interval)`,
      [uuidv7(), mobile, codeHash, String(ttl)],
    );

    await this.sms.send({
      to: mobile,
      body: `Cinnamon Trace: your verification code is ${code}. It expires in ${Math.round(ttl / 60)} minutes.`,
    });

    return { sent: true };
  }

  async verifyOtp(dto: OtpVerifyDto) {
    const mobile = this.normalizeMobile(dto.mobile);
    const user = await this.db.queryOne<UserRow>(
      "SELECT * FROM users WHERE mobile = $1",
      [mobile],
    );
    if (!user) {
      throw Errors.unauthorized("OTP_INVALID", "Invalid code");
    }

    // Dev bypass: when OTP_BYPASS_CODE is set, that fixed code verifies any
    // registered mobile without touching otp_codes. Ignored in production —
    // unset it there too (defense in depth).
    const bypassCode = this.config.get<string>("OTP_BYPASS_CODE");
    const bypassAllowed =
      (this.config.get<string>("NODE_ENV") || process.env.NODE_ENV || "development") !==
      "production";
    if (bypassAllowed && bypassCode && dto.code === bypassCode) {
      const token = this.jwt.sign({ sub: user.id, mobile: user.mobile });
      return {
        token,
        expires_in: this.expiresInSeconds(),
        user: await this.getPublicUser(user.id),
      };
    }

    const otp = await this.db.queryOne<{
      id: string;
      code_hash: string;
      expires_at: string;
      used_at: string | null;
      attempts: number;
    }>(
      `SELECT * FROM otp_codes
       WHERE mobile = $1 AND purpose = 'LOGIN' AND used_at IS NULL
       ORDER BY created_at DESC LIMIT 1`,
      [mobile],
    );

    if (!otp || new Date(otp.expires_at) < new Date()) {
      throw Errors.unauthorized("OTP_INVALID", "Invalid or expired code");
    }
    if (otp.attempts >= 5) {
      throw Errors.tooManyRequests("OTP_LOCKED", "Too many attempts, request a new code");
    }

    if (this.hashCode(dto.code) !== otp.code_hash) {
      await this.db.query(
        "UPDATE otp_codes SET attempts = attempts + 1 WHERE id = $1",
        [otp.id],
      );
      throw Errors.unauthorized("OTP_INVALID", "Invalid code");
    }

    await this.db.query("UPDATE otp_codes SET used_at = now() WHERE id = $1", [otp.id]);

    const token = this.jwt.sign({ sub: user.id, mobile: user.mobile });
    const profile = await this.getPublicUser(user.id);
    return { token, expires_in: this.expiresInSeconds(), user: profile };
  }

  async getMe(userId: string) {
    const user = await this.getPublicUser(userId);
    if (!user) throw Errors.notFound("USER_NOT_FOUND", "User not found");
    return user;
  }

  async updateMe(userId: string, dto: UpdateMeDto) {
    const sets: string[] = [];
    const params: unknown[] = [];
    let i = 1;
    if (dto.name !== undefined) {
      sets.push(`name = $${i++}`);
      params.push(dto.name);
    }
    if (dto.email !== undefined) {
      sets.push(`email = $${i++}`);
      params.push(dto.email);
    }
    if (dto.preferred_lang !== undefined) {
      sets.push(`preferred_lang = $${i++}`);
      params.push(dto.preferred_lang);
    }
    if (sets.length === 0) return this.getPublicUser(userId);
    params.push(userId);
    await this.db.query(
      `UPDATE users SET ${sets.join(", ")} WHERE id = $${i}`,
      params,
    );
    return this.getPublicUser(userId);
  }

  async addRole(userId: string, dto: AddRoleDto) {
    await this.db.transaction(async (client) => {
      await client.query(
        "INSERT INTO user_roles (user_id, role) VALUES ($1, $2) ON CONFLICT DO NOTHING",
        [userId, dto.role],
      );
      if (dto.role === "EXPORTER") {
        await allocateExporterCode(client, userId);
      }
    });
    return this.getPublicUser(userId);
  }

  async removeRole(userId: string, role: RoleCode) {
    const roles = await this.getRoles(userId);
    if (roles.length <= 1) {
      throw Errors.badRequest("LAST_ROLE", "You must keep at least one role");
    }
    await this.db.query(
      "DELETE FROM user_roles WHERE user_id = $1 AND role = $2",
      [userId, role],
    );
    return this.getPublicUser(userId);
  }

  private async getRoles(userId: string): Promise<RoleCode[]> {
    const rows = await this.db.query<{ role: RoleCode }>(
      "SELECT role FROM user_roles WHERE user_id = $1 ORDER BY role",
      [userId],
    );
    return rows.map((r) => r.role);
  }

  private async getPublicUser(userId: string) {
    const user = await this.db.queryOne<{
      id: string;
      name: string;
      mobile: string;
      email: string | null;
      preferred_lang: string;
      created_at: string;
      exporter_code: string | null;
    }>(
      "SELECT id, name, mobile, email, preferred_lang, created_at, exporter_code FROM users WHERE id = $1",
      [userId],
    );
    if (!user) return null;
    const roles = await this.getRoles(userId);
    return { ...user, roles };
  }

  private normalizeMobile(mobile: string): string {
    return normalizeMobile(mobile);
  }

  private generateCode(length: number): string {
    let code = "";
    for (let i = 0; i < length; i++) code += randomInt(0, 10).toString();
    return code;
  }

  private hashCode(code: string): string {
    return createHash("sha256").update(code).digest("hex");
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
