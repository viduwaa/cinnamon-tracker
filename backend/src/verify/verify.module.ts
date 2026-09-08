import { Module } from "@nestjs/common";
import { BatchesModule } from "../batches/batches.module";
import { VerifyController } from "./verify.controller";
import { VerifyService } from "./verify.service";
import { VerifyV1Controller } from "./verify-v1.controller";

@Module({
  imports: [BatchesModule],
  controllers: [VerifyController, VerifyV1Controller],
  providers: [VerifyService],
  exports: [VerifyService],
})
export class VerifyModule {}
