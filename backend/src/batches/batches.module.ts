import { Module } from "@nestjs/common";
import { BatchesController } from "./batches.controller";
import { BatchesService } from "./batches.service";
import { LedgerService } from "./ledger.service";

@Module({
  controllers: [BatchesController],
  providers: [BatchesService, LedgerService],
  exports: [BatchesService, LedgerService],
})
export class BatchesModule {}
