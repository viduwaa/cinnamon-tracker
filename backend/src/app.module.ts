import { Module, type MiddlewareConsumer, type NestModule } from "@nestjs/common";
import { ConfigModule, ConfigService } from "@nestjs/config";
import { APP_FILTER, APP_GUARD, APP_INTERCEPTOR, APP_PIPE } from "@nestjs/core";
import { ValidationPipe } from "@nestjs/common";
import { ThrottlerGuard, ThrottlerModule } from "@nestjs/throttler";
import type { ValidationError as CvError } from "class-validator";
import { ScheduleModule } from "@nestjs/schedule";
import { AnchorModule } from "./anchor/anchor.module";
import { AuthModule } from "./auth/auth.module";
import { BatchesModule } from "./batches/batches.module";
import { AllExceptionsFilter } from "./common/filters/all-exceptions.filter";
import { IdempotencyInterceptor } from "./common/idempotency/idempotency.interceptor";
import { IdempotencyModule } from "./common/idempotency/idempotency.module";
import { RequestIdMiddleware } from "./common/request-id.middleware";
import { ValidationError } from "./common/errors";
import { DatabaseModule } from "./database/database.module";
import { FarmsModule } from "./farms/farms.module";
import { HealthController } from "./health.controller";
import { TransfersModule } from "./transfers/transfers.module";
import { VerifyModule } from "./verify/verify.module";

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ScheduleModule.forRoot(),
    ThrottlerModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        throttlers: [
          {
            name: "default",
            ttl: 60_000,
            limit: Number(config.get("RATE_LIMIT_PER_MINUTE") ?? 120),
          },
        ],
      }),
    }),
    DatabaseModule,
    IdempotencyModule,
    AuthModule,
    FarmsModule,
    BatchesModule,
    TransfersModule,
    VerifyModule,
    AnchorModule,
  ],
  controllers: [HealthController],
  providers: [
    // Order matters: guards → interceptors → pipes run in registration order.
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_FILTER, useClass: AllExceptionsFilter },
    { provide: APP_INTERCEPTOR, useClass: IdempotencyInterceptor },
    {
      provide: APP_PIPE,
      useFactory: () =>
        new ValidationPipe({
          whitelist: true,
          transform: true,
          forbidNonWhitelisted: true,
          // Field-level details[] per api-spec §11; DomainError-shaped so the
          // global filter passes the envelope through untouched.
          exceptionFactory: (errors: CvError[]) =>
            new ValidationError(
              errors.map((e) => ({
                field: e.property,
                constraints: Object.values(e.constraints ?? {}),
              })),
            ),
        }),
    },
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(RequestIdMiddleware).forRoutes("*");
  }
}
