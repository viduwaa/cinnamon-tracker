import { Controller, Get } from "@nestjs/common";

@Controller("health")
export class HealthController {
  @Get()
  health() {
    return { status: "ok", service: "cinnamon-trace-backend", at: new Date().toISOString() };
  }
}
