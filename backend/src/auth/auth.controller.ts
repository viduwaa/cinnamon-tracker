import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
  UseGuards,
} from "@nestjs/common";
import { CurrentUserId } from "../common/current-user.decorator";
import { AuthService } from "./auth.service";
import {
  AddRoleDto,
  OtpRequestDto,
  OtpVerifyDto,
  RegisterDto,
  RoleCode,
  UpdateMeDto,
} from "./dto";
import { JwtAuthGuard } from "./jwt-auth.guard";

@Controller("auth")
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post("register")
  register(@Body() dto: RegisterDto) {
    return this.auth.register(dto);
  }

  @Post("otp/request")
  requestOtp(@Body() dto: OtpRequestDto) {
    return this.auth.requestOtp(dto);
  }

  @Post("otp/verify")
  verifyOtp(@Body() dto: OtpVerifyDto) {
    return this.auth.verifyOtp(dto);
  }

  @UseGuards(JwtAuthGuard)
  @Get("me")
  me(@CurrentUserId() userId: string) {
    return this.auth.getMe(userId);
  }

  @UseGuards(JwtAuthGuard)
  @Put("me")
  updateMe(@CurrentUserId() userId: string, @Body() dto: UpdateMeDto) {
    return this.auth.updateMe(userId, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Post("me/roles")
  addRole(@CurrentUserId() userId: string, @Body() dto: AddRoleDto) {
    return this.auth.addRole(userId, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Delete("me/roles/:role")
  removeRole(@CurrentUserId() userId: string, @Param("role") role: RoleCode) {
    return this.auth.removeRole(userId, role);
  }
}
