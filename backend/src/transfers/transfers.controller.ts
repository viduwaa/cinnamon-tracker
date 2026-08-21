import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  UseGuards,
} from "@nestjs/common";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";
import { CurrentUserId } from "../common/current-user.decorator";
import { RecipientsQuery, TransferDto } from "./dto";
import { TransfersService } from "./transfers.service";

@UseGuards(JwtAuthGuard)
@Controller()
export class TransfersController {
  constructor(private readonly transfers: TransfersService) {}

  @Get("transfers/recipients")
  recipients(@CurrentUserId() userId: string, @Query() query: RecipientsQuery) {
    return this.transfers.recipients(userId, query);
  }

  @Post("batches/:id/transfer")
  transfer(
    @CurrentUserId() userId: string,
    @Param("id") id: string,
    @Body() dto: TransferDto,
  ) {
    return this.transfers.transfer(userId, id, dto);
  }

  @Get("inbox")
  inbox(@CurrentUserId() userId: string) {
    return this.transfers.inbox(userId);
  }

  @Post("inbox/:batchId/accept")
  accept(@CurrentUserId() userId: string, @Param("batchId") batchId: string) {
    return this.transfers.accept(userId, batchId);
  }
}
