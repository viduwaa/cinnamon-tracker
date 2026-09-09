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
  ValidateIf,
} from "class-validator";
import { EX_CUSTOM_NO_REGEX, P2_CUSTOM_NO_REGEX } from "./numbering";

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

/**
 * P2 custom renumbering: `AA-JJJ-SS-YYYY-P2-CODE`. P1 never sends batch_no
 * (the service rejects it; the DTO cannot express "P1 only").
 */
export class ProcessBatchDto {
  @Type(() => Number)
  @IsNumber()
  @Min(0.01)
  @Max(1000000)
  output_weight_kg!: number;

  @IsOptional()
  @IsString()
  @Matches(P2_CUSTOM_NO_REGEX)
  batch_no?: string;
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

/**
 * Exporter renumbering (grill Q3): empty/null batch_no → append "/EX";
 * otherwise a custom `AA-JJJ-SS-YYYY-EX-CODE` number.
 */
export class RenameBatchDto {
  @IsOptional()
  @ValidateIf((o) => o.batch_no !== null && o.batch_no !== "")
  @IsString()
  @Matches(EX_CUSTOM_NO_REGEX)
  batch_no?: string | null;
}
