import { Controller, Get, Header, Param } from "@nestjs/common";
import { SkipThrottle } from "@nestjs/throttler";
import { Errors } from "../common/errors";
import { VerifyService } from "./verify.service";

/**
 * Versioned mirror of the public verification endpoint so api-spec §8's
 * `GET /v1/verify/{batchNo}` is literally true. Excluded from the global
 * prefix in main.ts (the controller path already contains it).
 */
@SkipThrottle()
@Controller("v1/verify")
export class VerifyV1Controller {
  constructor(private readonly verifyService: VerifyService) {}

  @Get(":batchNo")
  @Header("Cache-Control", "no-store")
  async verifyBatch(@Param("batchNo") batchNo: string) {
    const result = await this.verifyService.verify(batchNo);
    if (!result) {
      throw Errors.notFound("BATCH_NOT_FOUND", "Batch not found");
    }
    return result;
  }
}
