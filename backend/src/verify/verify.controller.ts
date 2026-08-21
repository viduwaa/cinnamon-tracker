import { Controller, Get, Header, Param } from "@nestjs/common";
import { VerifyService } from "./verify.service";

/**
 * Public verification portal. Served outside the /v1 prefix so QR codes can
 * point at a clean URL: https://verify.<domain>/<batchNo>
 *
 * Content negotiation: browsers get a simple HTML page; API clients
 * (Accept: application/json) get JSON.
 */
@Controller("verify")
export class VerifyController {
  constructor(private readonly verifyService: VerifyService) {}

  @Get(":batchNo")
  @Header("Cache-Control", "no-store")
  async verifyBatch(@Param("batchNo") batchNo: string) {
    const result = await this.verifyService.verify(batchNo);
    if (!result) {
      return { error: { code: "NOT_FOUND", message: "Batch not found" } };
    }
    return result;
  }
}
