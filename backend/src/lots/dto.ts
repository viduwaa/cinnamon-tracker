import { Type } from "class-transformer";
import {
  ArrayMinSize,
  IsArray,
  IsDateString,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  Min,
} from "class-validator";
import { LOT_NO_REGEX, CONTAINER_NO_REGEX } from "../batches/numbering";

/** Lot number: EX-SSS-YYYY-EXP-CODE (client-generated, offline-safe). */
export class CreateLotDto {
  @IsArray()
  @ArrayMinSize(1)
  @IsString({ each: true })
  batch_ids!: string[];

  @IsString()
  @Matches(LOT_NO_REGEX)
  lot_no!: string;

  @IsDateString()
  shipment_date!: string;

  /** ISO 6346 container code, 4 letters + 7 digits. */
  @IsOptional()
  @IsString()
  @Matches(CONTAINER_NO_REGEX)
  container_no?: string;

  @IsOptional()
  @IsString()
  buyer_name?: string;

  /** ISO 3166-1 alpha-2 destination. */
  @IsOptional()
  @IsString()
  @Matches(/^[A-Z]{2}$/)
  destination_country?: string;
}

export class ListLotsQuery {
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
