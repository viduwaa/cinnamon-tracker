import { Module } from "@nestjs/common";
import { JwtModule } from "@nestjs/jwt";
import { PassportModule } from "@nestjs/passport";
import { AuthController } from "./auth.controller";
import { AuthService } from "./auth.service";
import { JwtStrategy } from "./jwt.strategy";
import { SmsProvider, SMS_PROVIDER } from "./sms.provider";
import { MockSmsProvider } from "./mock-sms.provider";

@Module({
  imports: [
    PassportModule.register({ defaultStrategy: "jwt" }),
    JwtModule.registerAsync({
      useFactory: () => ({
        secret: process.env.JWT_SECRET ?? "change-me-in-prod",
        signOptions: { expiresIn: process.env.JWT_EXPIRES_IN ?? "1d" },
      }),
    }),
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    JwtStrategy,
    { provide: SMS_PROVIDER, useClass: MockSmsProvider },
  ],
  exports: [AuthService, JwtModule, PassportModule],
})
export class AuthModule {}
