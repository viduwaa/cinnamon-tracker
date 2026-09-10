import { Module } from "@nestjs/common";
import { JwtModule } from "@nestjs/jwt";
import { ConfigService } from "@nestjs/config";
import { BatchesModule } from "../batches/batches.module";
import { AdminAuthService } from "./admin-auth.service";
import { AdminService } from "./admin.service";
import { AdminGuard } from "./admin.guard";
import { AdminAuthController, AdminDataController } from "./admin.controller";

/**
 * Admin console module — separate credential space (admin_users), its own
 * guard (kind: "admin" JWT claim), and a read-only window onto the ledger.
 * JwtModule is reused from AuthModule's registration pattern: same secret,
 * so one env var governs both token families; the `kind` claim separates them.
 */
@Module({
  imports: [
    BatchesModule,
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>("JWT_SECRET") ?? process.env.JWT_SECRET,
        signOptions: { expiresIn: process.env.JWT_EXPIRES_IN ?? "1d" },
      }),
    }),
  ],
  controllers: [AdminAuthController, AdminDataController],
  providers: [AdminService, AdminAuthService, AdminGuard],
})
export class AdminModule {}
