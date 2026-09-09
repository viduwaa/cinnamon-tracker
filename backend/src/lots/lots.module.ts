import { Module } from "@nestjs/common";
import { BatchesModule } from "../batches/batches.module";
import { LotsController } from "./lots.controller";
import { LotsService } from "./lots.service";

@Module({
  imports: [BatchesModule],
  controllers: [LotsController],
  providers: [LotsService],
  exports: [LotsService],
})
export class LotsModule {}
