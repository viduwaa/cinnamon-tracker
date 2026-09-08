import { Controller, Get } from "@nestjs/common";
import { SkipThrottle } from "@nestjs/throttler";
import { DatabaseService } from "./database/database.service";

@SkipThrottle()
@Controller("health")
export class HealthController {
  constructor(private readonly db: DatabaseService) {}

  @Get()
  health() {
    return {
      status: "ok",
      service: "cinnamon-trace-backend",
      at: new Date().toISOString(),
      db: this.db.stats(),
    };
  }
}
