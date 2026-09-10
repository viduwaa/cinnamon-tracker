import { IsBoolean, IsEmail, IsIn, IsOptional, IsString, MaxLength } from "class-validator";

/**
 * Admin-console DTOs. Validation rules mirror the auth DTO conventions
 * (field-level details[] via the global ValidationPipe).
 */

export class AdminLoginDto {
  @IsEmail()
  email!: string;

  @IsString()
  @MaxLength(200)
  password!: string;
}

export class AdminSetUserActiveDto {
  @IsBoolean()
  is_active!: boolean;
}

export class AdminAddRoleDto {
  @IsIn(["FARMER", "PROCESSOR_L1", "COLLECTOR", "PROCESSOR_L2", "EXPORTER"])
  role!: string;
}

/** Query params accepted by the user list endpoint. */
export class AdminUserQueryDto {
  @IsOptional() @IsString() @MaxLength(120)
  q?: string;

  @IsOptional() @IsIn(["FARMER", "PROCESSOR_L1", "COLLECTOR", "PROCESSOR_L2", "EXPORTER"])
  role?: string;

  @IsOptional() @IsIn(["active", "suspended", "all"])
  status?: string;

  @IsOptional() @IsIn(["name", "created", "batches"])
  sort?: string;
}

/** Query params accepted by the batch list endpoint. */
export class AdminBatchQueryDto {
  @IsOptional() @IsString() @MaxLength(80)
  q?: string;

  @IsOptional() @IsIn(["AUTHENTIC", "TAMPERED", "PENDING"])
  verdict?: string;

  @IsOptional()
  @IsIn(["HARVESTED", "IN_TRANSIT", "RECEIVED", "PROCESSED", "MERGED", "EXPORTED"])
  status?: string;

  @IsOptional()
  @IsIn(["FARMER", "PROCESSOR_L1", "COLLECTOR", "PROCESSOR_L2", "EXPORTER"])
  role?: string;

  @IsOptional() @IsString() @MaxLength(4)
  district?: string;

  @IsOptional() @IsIn(["newest", "oldest", "weight"])
  sort?: string;

  @IsOptional() @IsIn(["csv"])
  format?: string;
}

/** Query params accepted by the audit-log endpoint. */
export class AdminAuditQueryDto {
  @IsOptional() @IsString() @MaxLength(120)
  q?: string;

  @IsOptional() @IsString() @MaxLength(80)
  action?: string;

  @IsOptional() @IsString() @MaxLength(80)
  entity?: string;

  @IsOptional() @IsIn(["newest", "oldest"])
  sort?: string;
}
