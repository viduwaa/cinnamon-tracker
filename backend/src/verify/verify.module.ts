import { Module } from "@nestjs/common";
import { BatchesModule } from "../batches/batches.module";
import { VerifyController } from "./verify.controller";
import { VerifyService } from "./verify.service";

@Module({
  imports: [BatchesModule],
  controllers: [VerifyController],
  providers: [VerifyService],
  exports: [VerifyService],
})
export class VerifyModule {}
