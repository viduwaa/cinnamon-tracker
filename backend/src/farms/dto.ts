import {
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  Length,
  Matches,
  Max,
  MaxLength,
  Min,
} from "class-validator";
import { Type } from "class-transformer";

export class CreateFarmDto {
  @IsString()
  @Matches(/^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i)
  id!: string; // client-generated UUIDv7

  @IsString()
  @Length(2, 100)
  name!: string;

  @IsString()
  @Matches(/^[A-Z]{2}$/)
  area_code!: string;

  @Type(() => Number)
  @IsNumber()
  @Min(0.01)
  @Max(100000)
  size_value!: number;

  @IsOptional()
  @IsIn(["ACRE", "PERCH", "HECTARE"])
  size_unit?: "ACRE" | "PERCH" | "HECTARE";

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  lat?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  lng?: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  address_text?: string;

  @IsOptional()
  @IsIn(["EXACT", "DISTRICT", "HIDDEN"])
  location_public_level?: "EXACT" | "DISTRICT" | "HIDDEN";
}

export class UpdateFarmDto {
  @IsOptional()
  @IsString()
  @Length(2, 100)
  name?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0.01)
  @Max(100000)
  size_value?: number;

  @IsOptional()
  @IsIn(["ACRE", "PERCH", "HECTARE"])
  size_unit?: "ACRE" | "PERCH" | "HECTARE";

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  lat?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  lng?: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  address_text?: string;

  @IsOptional()
  @IsIn(["EXACT", "DISTRICT", "HIDDEN"])
  location_public_level?: "EXACT" | "DISTRICT" | "HIDDEN";
}
