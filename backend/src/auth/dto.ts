import {
  ArrayNotEmpty,
  IsArray,
  IsEmail,
  IsEnum,
  IsIn,
  IsOptional,
  IsString,
  Length,
  Matches,
  MaxLength,
} from "class-validator";

/** E.164-ish mobile: +94771234567 etc. */
const MOBILE_REGEX = /^\+?[0-9]{7,15}$/;

export const ROLE_CODES = [
  "FARMER",
  "PROCESSOR_L1",
  "COLLECTOR",
  "PROCESSOR_L2",
  "EXPORTER",
] as const;
export type RoleCode = (typeof ROLE_CODES)[number];

export class RegisterDto {
  @IsString()
  @Length(2, 100)
  name!: string;

  @Matches(MOBILE_REGEX)
  mobile!: string;

  @IsOptional()
  @IsEmail()
  email?: string;

  @IsArray()
  @ArrayNotEmpty()
  @IsEnum(ROLE_CODES, { each: true })
  roles!: RoleCode[];

  @IsOptional()
  @IsIn(["si", "ta", "en"])
  preferred_lang?: "si" | "ta" | "en";
}

export class OtpRequestDto {
  @Matches(MOBILE_REGEX)
  mobile!: string;
}

export class OtpVerifyDto {
  @Matches(MOBILE_REGEX)
  mobile!: string;

  @IsString()
  @Matches(/^\d{6}$/)
  code!: string;
}

export class UpdateMeDto {
  @IsOptional()
  @IsString()
  @Length(2, 100)
  name?: string;

  @IsOptional()
  @IsEmail()
  email?: string;

  @IsOptional()
  @IsIn(["si", "ta", "en"])
  preferred_lang?: "si" | "ta" | "en";
}

export class AddRoleDto {
  @IsEnum(ROLE_CODES)
  role!: RoleCode;
}

export class RemoveRoleParams {
  @IsEnum(ROLE_CODES)
  role!: RoleCode;
}

export class IdParam {
  @IsString()
  @MaxLength(64)
  id!: string;
}
