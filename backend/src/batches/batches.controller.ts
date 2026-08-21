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
import { BatchesService } from "./batches.service";
import { CreateBatchDto, ListBatchesQuery } from "./dto";

@UseGuards(JwtAuthGuard)
@Controller("batches")
export class BatchesController {
  constructor(private readonly batches: BatchesService) {}

  @Post()
  create(@CurrentUserId() userId: string, @Body() dto: CreateBatchDto) {
    return this.batches.create(userId, dto);
  }

  @Get()
  list(@CurrentUserId() userId: string, @Query() query: ListBatchesQuery) {
    return this.batches.listMine(userId, query);
  }

  @Get("by-no/:batchNo")
  getByNo(@CurrentUserId() userId: string, @Param("batchNo") batchNo: string) {
    return this.batches.getByNo(userId, batchNo);
  }

  @Get(":id")
  get(@CurrentUserId() userId: string, @Param("id") id: string) {
    return this.batches.get(userId, id);
  }

  @Get(":id/chain")
  chain(@CurrentUserId() userId: string, @Param("id") id: string) {
    return this.batches.chain(userId, id);
  }
}
