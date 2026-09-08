import { Module } from "@nestjs/common";
import { AdminGuard } from "../auth/admin.guard";
import { AnchorController } from "./anchor.controller";
import { AnchorService } from "./anchor.service";

@Module({
  controllers: [AnchorController],
  providers: [AnchorService, AdminGuard],
  exports: [AnchorService],
})
export class AnchorModule {}
