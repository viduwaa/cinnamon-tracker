import { Module } from "@nestjs/common";
import { BatchesController } from "./batches.controller";
import { BatchesService } from "./batches.service";
import { ProcessingService } from "./processing.service";
import { LedgerService } from "./ledger.service";

@Module({
  controllers: [BatchesController],
  providers: [BatchesService, ProcessingService, LedgerService],
  exports: [BatchesService, ProcessingService, LedgerService],
})
export class BatchesModule {}
