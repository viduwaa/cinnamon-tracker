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
import { ProcessingService } from "./processing.service";
import { CreateBatchDto, ListBatchesQuery, ProcessBatchDto, RenameBatchDto } from "./dto";

@UseGuards(JwtAuthGuard)
@Controller("batches")
export class BatchesController {
  constructor(
    private readonly batches: BatchesService,
    private readonly processing: ProcessingService,
  ) {}

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

  @Get(":id/process/suggest")
  suggestProcessing(@CurrentUserId() userId: string, @Param("id") id: string) {
    return this.processing.suggest(userId, id);
  }

  @Post(":id/process")
  process(
    @CurrentUserId() userId: string,
    @Param("id") id: string,
    @Body() dto: ProcessBatchDto,
  ) {
    return this.processing.process(userId, id, dto);
  }

  @Post(":id/rename")
  rename(
    @CurrentUserId() userId: string,
    @Param("id") id: string,
    @Body() dto: RenameBatchDto,
  ) {
    return this.processing.rename(userId, id, dto);
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
