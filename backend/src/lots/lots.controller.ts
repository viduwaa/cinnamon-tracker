import { Body, Controller, Get, Param, Post, Query, UseGuards } from "@nestjs/common";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";
import { CurrentUserId } from "../common/current-user.decorator";
import { LotsService } from "./lots.service";
import { CreateLotDto, ListLotsQuery } from "./dto";

@UseGuards(JwtAuthGuard)
@Controller("lots")
export class LotsController {
  constructor(private readonly lots: LotsService) {}

  @Post("preview")
  preview(@CurrentUserId() userId: string, @Body() dto: CreateLotDto) {
    return this.lots.preview(userId, dto);
  }

  @Post()
  create(@CurrentUserId() userId: string, @Body() dto: CreateLotDto) {
    return this.lots.create(userId, dto);
  }

  @Get()
  list(@CurrentUserId() userId: string, @Query() query: ListLotsQuery) {
    return this.lots.listMine(userId, query);
  }

  @Get(":id")
  get(@CurrentUserId() userId: string, @Param("id") id: string) {
    return this.lots.get(userId, id);
  }
}
