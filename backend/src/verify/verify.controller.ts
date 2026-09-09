import {
  Controller,
  Get,
  Header,
  Param,
  Req,
  Res,
} from "@nestjs/common";
import { SkipThrottle } from "@nestjs/throttler";
import type { Request, Response } from "express";
import { Errors } from "../common/errors";
import { VerifyService } from "./verify.service";
import { renderVerifyPage } from "./verify-page";

/**
 * Public verification portal. Served outside the /v1 prefix so QR codes can
 * point at a clean URL: https://verify.<domain>/<batchNo>
 *
 * Content negotiation: browsers get a server-rendered HTML page (no SPA, no
 * extra deploy unit — the truth and its presentation ship in one binary);
 * API clients (Accept: application/json) get JSON.
 */
// Public trust surface: a viral QR campaign must never 429 behind shared
// carrier NAT IPs, so the portal is exempt from rate limiting.
@SkipThrottle()
@Controller("verify")
export class VerifyController {
  constructor(private readonly verifyService: VerifyService) {}

  @Get(":batchNo")
  @Header("Cache-Control", "no-store")
  async verifyBatch(
    @Param("batchNo") batchNo: string,
    @Req() req: Request,
    @Res() res: Response,
  ) {
    const result = await this.verifyService.verify(batchNo);
    if (!result) {
      throw Errors.notFound("BATCH_NOT_FOUND", "Batch not found");
    }

    const wantsHtml = (req.headers.accept ?? "")
      .split(",")
      .some((a) => a.trim().startsWith("text/html"));
    if (!wantsHtml) {
      return res.json(result);
    }
    return res.status(200).send(renderVerifyPage(result));
  }
}
