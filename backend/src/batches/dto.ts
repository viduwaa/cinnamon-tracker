import { Type } from "class-transformer";
import {
  IsDateString,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  Max,
  Min,
} from "class-validator";

/** Root batch number: AA-JULIAN-SEQ-YEAR-FM-FARMERCODE-T|Q */
export const ROOT_BATCH_NO_REGEX =
  /^[A-Z]{2}-\d{3}-\d{2}-\d{4}-FM-[A-Z0-9]{1,4}-[TQ]$/;

export class CreateBatchDto {
  @IsString()
  @Matches(/^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i)
  id!: string; // client-generated UUIDv7

  @IsString()
  farm_id!: string;

  @IsString()
  @Matches(ROOT_BATCH_NO_REGEX)
  batch_no!: string;

  @IsIn(["T", "Q"])
  harvest_type!: "T" | "Q";

  @IsDateString()
  harvest_date!: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  tree_count?: number;

  @Type(() => Number)
  @IsNumber()
  @Min(0.01)
  @Max(1000000)
  weight_kg!: number;
}

export class ListBatchesQuery {
  @IsOptional()
  @IsString()
  status?: string;

  @IsOptional()
  @IsString()
  role?: string;

  @IsOptional()
  @IsString()
  q?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  offset?: number;
}
