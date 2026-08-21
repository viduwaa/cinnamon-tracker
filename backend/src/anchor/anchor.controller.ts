import { Controller, Get, Post, UseGuards } from "@nestjs/common";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";
import { DatabaseService } from "../database/database.service";
import { AnchorService } from "./anchor.service";

@Controller("admin/anchors")
export class AnchorController {
  constructor(
    private readonly anchor: AnchorService,
    private readonly db: DatabaseService,
  ) {}

  // TODO: replace with an admin-scope guard once admin roles exist.
  @UseGuards(JwtAuthGuard)
  @Post("run")
  run() {
    return this.anchor.runAnchor();
  }

  @UseGuards(JwtAuthGuard)
  @Get()
  async list() {
    return this.db.query(
      "SELECT id, merkle_root, event_count, network, status, anchored_at FROM chain_anchors ORDER BY anchored_at DESC LIMIT 50",
    );
  }
}
