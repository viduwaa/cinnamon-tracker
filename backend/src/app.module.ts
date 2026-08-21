import { Module } from "@nestjs/common";
import { ConfigModule } from "@nestjs/config";
import { ScheduleModule } from "@nestjs/schedule";
import { AnchorModule } from "./anchor/anchor.module";
import { AuthModule } from "./auth/auth.module";
import { BatchesModule } from "./batches/batches.module";
import { DatabaseModule } from "./database/database.module";
import { FarmsModule } from "./farms/farms.module";
import { HealthController } from "./health.controller";
import { TransfersModule } from "./transfers/transfers.module";
import { VerifyModule } from "./verify/verify.module";

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ScheduleModule.forRoot(),
    DatabaseModule,
    AuthModule,
    FarmsModule,
    BatchesModule,
    TransfersModule,
    VerifyModule,
    AnchorModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}
