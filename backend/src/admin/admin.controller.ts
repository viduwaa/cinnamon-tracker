import { Body, Controller, Delete, Get, Param, Patch, Post, Query, Res, UseGuards } from "@nestjs/common";
import type { Response } from "express";
import { AdminService } from "./admin.service";
import { AdminAuthService } from "./admin-auth.service";
import { AdminGuard } from "./admin.guard";
import { CurrentAdmin } from "./current-admin.decorator";
import {
  AdminAddRoleDto,
  AdminAuditQueryDto,
  AdminBatchQueryDto,
  AdminLoginDto,
  AdminSetUserActiveDto,
  AdminUserQueryDto,
} from "./dto";
import type { AdminPrincipal } from "./admin-auth.service";

/**
 * Government oversight console API. Every route requires the admin JWT
 * (kind: "admin"); the ledger-facing routes are strictly read-only — the
 * console must never be able to mutate batch data or the event chain.
 */
@Controller("admin")
export class AdminAuthController {
  constructor(private readonly adminAuth: AdminAuthService) {}

  /** Only unauthenticated admin endpoint. Public ThrottlerGuard still applies. */
  @Post("auth/login")
  login(@Body() dto: AdminLoginDto) {
    return this.adminAuth.login(dto.email, dto.password);
  }
}

@Controller("admin")
@UseGuards(AdminGuard)
export class AdminDataController {
  constructor(private readonly admin: AdminService) {}

  @Get("overview")
  overview() {
    return this.admin.overview();
  }

  @Get("users")
  users(@Query() q: AdminUserQueryDto) {
    return this.admin.listUsers(q);
  }

  @Get("users/:id")
  userDetail(@Param("id") id: string) {
    return this.admin.userDetail(id);
  }

  @Patch("users/:id/status")
  setUserActive(
    @Param("id") id: string,
    @Body() dto: AdminSetUserActiveDto,
    @CurrentAdmin() admin: AdminPrincipal,
  ) {
    return this.admin.setUserActive(id, dto, admin);
  }

  @Post("users/:id/roles")
  addRole(
    @Param("id") id: string,
    @Body() dto: AdminAddRoleDto,
    @CurrentAdmin() admin: AdminPrincipal,
  ) {
    return this.admin.addRole(id, dto, admin);
  }

  @Delete("users/:id/roles/:role")
  removeRole(
    @Param("id") id: string,
    @Param("role") role: string,
    @CurrentAdmin() admin: AdminPrincipal,
  ) {
    return this.admin.removeRole(id, role, admin);
  }

  @Get("batches")
  async batches(@Query() q: AdminBatchQueryDto, @Res({ passthrough: true }) res: Response) {
    if (q.format === "csv") {
      const rows = await this.admin.listBatches({ ...q, format: undefined });
      const header = "batch_no,status,verdict,weight_kg,district,holder_role,holder_name,created_at";
      const esc = (v: unknown) => `"${String(v ?? "").replace(/"/g, '""')}"`;
      const csv = [header, ...rows.batches.map((b) => [b.batch_no, b.status, b.verdict, b.weight_kg, b.district ?? "", b.current_holder_role ?? "", b.holder_name ?? "", b.created_at].map(esc).join(","))].join("\r\n");
      res.setHeader("Content-Type", "text/csv; charset=utf-8");
      res.setHeader("Content-Disposition", 'attachment; filename="batches.csv"');
      res.send(csv);
      return;
    }
    return this.admin.listBatches(q);
  }

  @Get("batches/:id")
  batchDetail(@Param("id") id: string) {
    return this.admin.batchDetail(id);
  }

  @Get("analytics/anchors")
  anchors() {
    return this.admin.anchors();
  }

  @Get("analytics/audit")
  audit(@Query() q: AdminAuditQueryDto) {
    return this.admin.audit(q);
  }
}
