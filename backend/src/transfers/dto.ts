import { Type } from "class-transformer";
import {
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  Length,
  MaxLength,
  Min,
} from "class-validator";

export class TransferDto {
  @IsString()
  to_user_id!: string;

  @IsOptional()
  @IsIn(["COLLECTOR", "PROCESSOR_L1", "PROCESSOR_L2", "EXPORTER"])
  to_role?: string;

  @IsIn(["SALE", "HANDOFF"])
  transfer_kind!: "SALE" | "HANDOFF";

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  price_lkr?: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  notes?: string;
}

export class RecipientsQuery {
  // Optional; empty means "list all allowed recipients". Min length enforced
  // only when a search term is actually given.
  @IsOptional()
  @IsString()
  @MaxLength(50)
  q?: string;

  // Optional; narrows results to one recipient role. The service intersects
  // this with the sender's allowed roles.
  @IsOptional()
  @IsIn(["COLLECTOR", "PROCESSOR_L1", "PROCESSOR_L2", "EXPORTER"])
  role?: string;
}
