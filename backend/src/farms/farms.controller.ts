import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from "@nestjs/common";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";
import { CurrentUserId } from "../common/current-user.decorator";
import { CreateFarmDto, UpdateFarmDto } from "./dto";
import { FarmsService } from "./farms.service";

@UseGuards(JwtAuthGuard)
@Controller("farms")
export class FarmsController {
  constructor(private readonly farms: FarmsService) {}

  @Post()
  create(@CurrentUserId() userId: string, @Body() dto: CreateFarmDto) {
    return this.farms.create(userId, dto);
  }

  @Get()
  list(@CurrentUserId() userId: string) {
    return this.farms.listMine(userId);
  }

  @Get(":id")
  get(@CurrentUserId() userId: string, @Param("id") id: string) {
    return this.farms.get(userId, id);
  }

  @Patch(":id")
  update(
    @CurrentUserId() userId: string,
    @Param("id") id: string,
    @Body() dto: UpdateFarmDto,
  ) {
    return this.farms.update(userId, id, dto);
  }
}
