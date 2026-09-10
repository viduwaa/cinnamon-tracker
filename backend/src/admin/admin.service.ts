import { Injectable } from "@nestjs/common";
import { BatchesService } from "../batches/batches.service";
import { DatabaseService } from "../database/database.service";
import { Errors } from "../common/errors";
import { verifyChain, type StoredEvent } from "../integrity/hash-chain";
import type { AdminAddRoleDto, AdminAuditQueryDto, AdminBatchQueryDto, AdminSetUserActiveDto, AdminUserQueryDto } from "./dto";

type Verdict = "AUTHENTIC" | "TAMPERED" | "PENDING";

const ROLE_CODES = ["FARMER", "PROCESSOR_L1", "COLLECTOR", "PROCESSOR_L2", "EXPORTER"] as const;

/**
 * Read model for the government console. The ledger itself is READ-ONLY here:
 * the only write paths are user suspension, role adjustment, and audit rows
 * recording who did what. Batch verdicts reuse BatchesService.verificationBlock
 * (the single owner of verdict logic) for detail views; list/overview views use
 * verdictMap — the same computation over the whole ledger, cached for 60s so a
 * dashboard refresh doesn't re-hash every event on every request.
 */
@Injectable()
export class AdminService {
  private verdictCache?: { at: number; map: Map<string, Verdict> };

  constructor(
    private readonly db: DatabaseService,
    private readonly batches: BatchesService,
  ) {}

  // ---- Overview ----------------------------------------------------------

  async overview() {
    const [userCounts, batchCounts, verdicts, anchorStatus, lastAnchor, unanchored, trend, byRole, byHolderRole, districts] =
      await Promise.all([
        this.db.queryOne<{ total: string; suspended: string; new_today: string }>(
          `SELECT count(*)::text AS total,
                  count(*) FILTER (WHERE is_active IS FALSE)::text AS suspended,
                  count(*) FILTER (WHERE created_at >= date_trunc('day', now()))::text AS new_today
           FROM users`,
        ),
        this.db.queryOne<{ total: string; today: string; weight: string }>(
          `SELECT count(*)::text AS total,
                  count(*) FILTER (WHERE created_at >= date_trunc('day', now()))::text AS today,
                  COALESCE(SUM(weight_kg), 0)::float8 AS weight
           FROM batches`,
        ),
        this.verdictCounts(),
        this.db.query<{ status: string; count: string }>(
          "SELECT status, count(*)::text AS count FROM chain_anchors GROUP BY status",
        ),
        this.db.queryOne<{ last_confirmed: string | null }>(
          "SELECT max(anchored_at)::text AS last_confirmed FROM chain_anchors WHERE status = 'CONFIRMED'",
        ),
        this.db.queryOne<{ count: string }>(
          "SELECT count(*)::text AS count FROM batch_events WHERE anchored_at IS NULL",
        ),
        this.db.query<{ day: string; batches: string }>(
          `SELECT d::date::text AS day, count(b.id)::text AS batches
           FROM generate_series(date_trunc('day', now()) - interval '13 days', date_trunc('day', now()), interval '1 day') d
           LEFT JOIN batches b ON b.created_at >= d AND b.created_at < d + interval '1 day'
           GROUP BY d ORDER BY d`,
        ),
        this.db.query<{ actor_role: string; batches: string; events: string }>(
          `SELECT actor_role, count(DISTINCT batch_id)::text AS batches, count(*)::text AS events
           FROM batch_events WHERE actor_role IS NOT NULL GROUP BY actor_role`,
        ),
        this.db.query<{ role: string; batches: string }>(
          `SELECT current_holder_role AS role, count(*)::text AS batches
           FROM batches WHERE current_holder_role IS NOT NULL GROUP BY current_holder_role`,
        ),
        this.db.query<{ area_code: string; name_en: string; batches: string; weight: string }>(
          `SELECT d.area_code, d.name_en, count(b.id)::text AS batches,
                  COALESCE(SUM(b.weight_kg), 0)::float8 AS weight
           FROM districts d
           LEFT JOIN farms f ON f.area_code = d.area_code
           LEFT JOIN batches b ON b.farm_id = f.id
           GROUP BY d.area_code, d.name_en
           HAVING count(b.id) > 0
           ORDER BY count(b.id) DESC`,
        ),
      ]);

    return {
      users: {
        total: Number(userCounts?.total ?? 0),
        suspended: Number(userCounts?.suspended ?? 0),
        new_today: Number(userCounts?.new_today ?? 0),
      },
      batches: {
        total: Number(batchCounts?.total ?? 0),
        today: Number(batchCounts?.today ?? 0),
        weight_kg: Number(batchCounts?.weight ?? 0),
      },
      verdicts,
      anchors: {
        by_status: Object.fromEntries(anchorStatus.map((a) => [a.status, Number(a.count)])),
        last_confirmed_at: lastAnchor?.last_confirmed ?? null,
        events_awaiting_anchor: Number(unanchored?.count ?? 0),
      },
      batches_per_day: trend.map((t) => ({ day: t.day, count: Number(t.batches) })),
      activity_by_role: byRole.map((r) => ({
        role: r.actor_role,
        batches_touched: Number(r.batches),
        events: Number(r.events),
      })),
      custody_by_role: byHolderRole.map((r) => ({
        role: r.role,
        batches: Number(r.batches),
      })),
      districts: districts.map((d) => ({
        area_code: d.area_code,
        name: d.name_en,
        batches: Number(d.batches),
        weight_kg: Number(d.weight),
      })),
    };
  }

  // ---- Users ---------------------------------------------------------------

  async listUsers(q: AdminUserQueryDto) {
    const rows = await this.db.query(
      `SELECT u.id, u.name, u.mobile, u.email, u.is_active, u.created_at::text AS created_at,
              COALESCE(json_agg(DISTINCT ur.role) FILTER (WHERE ur.role IS NOT NULL), '[]') AS roles,
              bc.batch_count, fc.farm_count
       FROM users u
       LEFT JOIN user_roles ur ON ur.user_id = u.id
       LEFT JOIN LATERAL (SELECT count(*)::int AS batch_count FROM batches b WHERE b.created_by = u.id) bc ON true
       LEFT JOIN LATERAL (SELECT count(*)::int AS farm_count FROM farms f WHERE f.owner_user_id = u.id) fc ON true
       WHERE ($1::text IS NULL OR u.name ILIKE $1 OR u.mobile ILIKE $1 OR COALESCE(u.email, '') ILIKE $1)
         AND ($2::text IS NULL OR EXISTS (
              SELECT 1 FROM user_roles ur2 WHERE ur2.user_id = u.id AND ur2.role::text = $2))
         AND ($3::text = 'all' OR ($3::text = 'suspended' AND u.is_active IS FALSE)
              OR ($3::text = 'active' AND u.is_active IS NOT FALSE) OR $3::text IS NULL)
       GROUP BY u.id, bc.batch_count, fc.farm_count
       ORDER BY
         CASE WHEN $4::text = 'name' THEN u.name END ASC NULLS LAST,
         CASE WHEN $4::text = 'created' THEN u.created_at END DESC NULLS LAST,
         CASE WHEN $4::text = 'batches' THEN bc.batch_count END DESC NULLS LAST,
         u.created_at DESC
       LIMIT 500`,
      [q.q ?? null, q.role ?? null, q.status ?? "all", q.sort ?? "created"],
    );
    return {
      total: rows.length,
      users: rows.map((r) => ({
        id: r.id,
        name: r.name,
        mobile: r.mobile,
        email: r.email,
        is_active: r.is_active !== false,
        created_at: r.created_at,
        roles: r.roles,
        batches: r.batch_count,
        farms: r.farm_count,
      })),
    };
  }

  async userDetail(id: string) {
    const user = await this.db.queryOne(
      `SELECT u.id, u.name, u.mobile, u.email, u.is_active, u.created_at::text AS created_at,
              COALESCE(json_agg(DISTINCT ur.role) FILTER (WHERE ur.role IS NOT NULL), '[]') AS roles
       FROM users u LEFT JOIN user_roles ur ON ur.user_id = u.id
       WHERE u.id = $1 GROUP BY u.id`,
      [id],
    );
    if (!user) throw Errors.notFound("USER_NOT_FOUND", "User not found");
    const [farms, recentBatches] = await Promise.all([
      this.db.query(
        `SELECT id, name, area_code, size_value::float8 AS size_value, size_unit, created_at::text AS created_at
         FROM farms WHERE owner_user_id = $1 ORDER BY created_at DESC`,
        [id],
      ),
      this.db.query(
        `SELECT id, batch_no, status, weight_kg::float8 AS weight_kg, created_at::text AS created_at
         FROM batches WHERE created_by = $1 OR current_holder_id = $1
         ORDER BY created_at DESC LIMIT 20`,
        [id],
      ),
    ]);
    return { ...user, farms, recent_batches: recentBatches };
  }

  /** Suspend / reactivate an app user. The only user write path in the console. */
  async setUserActive(id: string, dto: AdminSetUserActiveDto, admin: { id: string; email: string }) {
    const row = await this.db.queryOne<{ id: string; name: string; is_active: boolean | null }>(
      "UPDATE users SET is_active = $2 WHERE id = $1 RETURNING id, name, is_active",
      [id, dto.is_active],
    );
    if (!row) throw Errors.notFound("USER_NOT_FOUND", "User not found");
    await this.db.query(
      "INSERT INTO audit_log (user_id, action, entity, entity_id, after) VALUES ($1, $2, $3, $4, $5)",
      [
        admin.id,
        dto.is_active ? "USER_REACTIVATED" : "USER_SUSPENDED",
        "user",
        id,
        JSON.stringify({ by: admin.email, is_active: dto.is_active }),
      ],
    );
    return { id: row.id, name: row.name, is_active: row.is_active !== false };
  }

  /** Adjust a user's roles. At least one role must remain (mirrors app rule). */
  async addRole(id: string, dto: AdminAddRoleDto, admin: { id: string; email: string }) {
    const user = await this.db.queryOne<{ id: string }>("SELECT id FROM users WHERE id = $1", [id]);
    if (!user) throw Errors.notFound("USER_NOT_FOUND", "User not found");
    const roles = await this.db.query<{ role: string }>(
      "SELECT role::text AS role FROM user_roles WHERE user_id = $1",
      [id],
    );
    await this.db.query(
      "INSERT INTO user_roles (user_id, role) VALUES ($1, $2::role_code) ON CONFLICT DO NOTHING",
      [id, dto.role],
    );
    await this.db.query(
      "INSERT INTO audit_log (user_id, action, entity, entity_id, after) VALUES ($1, $2, $3, $4, $5)",
      [admin.id, "USER_ROLE_ADDED", "user", id, JSON.stringify({ by: admin.email, role: dto.role })],
    );
    return { id, roles: [...new Set([...roles.map((r) => r.role), dto.role])] };
  }

  async removeRole(id: string, role: string, admin: { id: string; email: string }) {
    if (!ROLE_CODES.includes(role as (typeof ROLE_CODES)[number])) {
      throw Errors.badRequest("ROLE_INVALID", "Unknown role");
    }
    const roles = await this.db.query<{ role: string }>(
      "SELECT role::text AS role FROM user_roles WHERE user_id = $1",
      [id],
    );
    if (roles.length <= 1) {
      throw Errors.badRequest("LAST_ROLE", "User must keep at least one role");
    }
    await this.db.query("DELETE FROM user_roles WHERE user_id = $1 AND role::text = $2", [id, role]);
    await this.db.query(
      "INSERT INTO audit_log (user_id, action, entity, entity_id, after) VALUES ($1, $2, $3, $4, $5)",
      [admin.id, "USER_ROLE_REMOVED", "user", id, JSON.stringify({ by: admin.email, role })],
    );
    return { id, roles: roles.map((r) => r.role).filter((r) => r !== role) };
  }

  // ---- Batches -------------------------------------------------------------

  async listBatches(q: AdminBatchQueryDto) {
    type BatchListRow = {
      id: string;
      batch_no: string;
      status: string;
      weight_kg: number;
      harvest_date: string | null;
      created_at: string;
      current_holder_role: string | null;
      root_batch_no: string;
      area_code: string | null;
      district: string | null;
      holder_name: string | null;
    };
    const rows = await this.db.query<BatchListRow>(
      `SELECT b.id, b.batch_no, b.status::text AS status, b.weight_kg::float8 AS weight_kg,
              b.harvest_date::text AS harvest_date, b.created_at::text AS created_at,
              b.current_holder_role::text AS current_holder_role, b.root_batch_no,
              f.area_code, d.name_en AS district, u.name AS holder_name
       FROM batches b
       LEFT JOIN farms f ON f.id = b.farm_id
       LEFT JOIN districts d ON d.area_code = f.area_code
       LEFT JOIN users u ON u.id = b.current_holder_id
       WHERE ($1::text IS NULL OR b.batch_no ILIKE $1 OR b.root_batch_no ILIKE $1 OR u.name ILIKE $1)
         AND ($2::text IS NULL OR b.status::text = $2)
         AND ($3::text IS NULL OR b.current_holder_role::text = $3)
         AND ($4::char IS NULL OR f.area_code = $4)
       ORDER BY
         CASE WHEN $5::text = 'oldest' THEN b.created_at END ASC NULLS LAST,
         CASE WHEN $5::text = 'weight' THEN b.weight_kg END DESC NULLS LAST,
         b.created_at DESC
       LIMIT 500`,
      [q.q ? `%${q.q}%` : null, q.status ?? null, q.role ?? null, q.district ?? null, q.sort ?? "newest"],
    );

    const verdicts = await this.verdictMap();
    let out = rows.map((r) => ({ ...r, verdict: verdicts.get(r.id) ?? "PENDING" as Verdict }));
    if (q.verdict) out = out.filter((r) => r.verdict === (q.verdict as Verdict));

    return { total: out.length, batches: out };
  }

  async batchDetail(id: string) {
    // Accept either the UUID or the human batch number. Branch on shape —
    // Postgres evaluates `$1::uuid` eagerly, so a single OR query would throw
    // "invalid input syntax for type uuid" whenever a batch_no is passed.
    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id);
    const row = await this.db.queryOne<{ id: string }>(
      isUuid ? "SELECT id FROM batches WHERE id = $1" : "SELECT id FROM batches WHERE batch_no = $1 LIMIT 1",
      [id],
    );
    if (!row) throw Errors.notFound("BATCH_NOT_FOUND", "Batch not found");

    const [base, verification, chain] = await Promise.all([
      this.db.queryOne(
        `SELECT b.id, b.batch_no, b.status::text AS status, b.weight_kg::float8 AS weight_kg,
                b.harvest_type::text AS harvest_type, b.harvest_date::text AS harvest_date,
                b.tree_count, b.created_at::text AS created_at, b.root_batch_no, b.stage_suffix,
                b.current_holder_role::text AS current_holder_role,
                f.name AS farm_name, f.area_code, d.name_en AS district,
                f.lat::float8 AS lat, f.lng::float8 AS lng,
                u.name AS holder_name
         FROM batches b
         LEFT JOIN farms f ON f.id = b.farm_id
         LEFT JOIN districts d ON d.area_code = f.area_code
         LEFT JOIN users u ON u.id = b.current_holder_id
         WHERE b.id = $1`,
        [row.id],
      ),
      this.batches.verificationBlock(row.id),
      this.batches.publicChain(
        (await this.db.queryOne<{ batch_no: string }>("SELECT batch_no FROM batches WHERE id = $1", [row.id]))!
          .batch_no,
      ),
    ]);

    return { batch: base, verification, chain };
  }

  // ---- Anchors / audit -----------------------------------------------------

  async anchors() {
    const [list, unanchored] = await Promise.all([
      this.db.query(
        `SELECT id, merkle_root, event_count, network::text AS network, tx_hash, block_no,
                status, anchored_at::text AS anchored_at
         FROM chain_anchors ORDER BY anchored_at DESC LIMIT 100`,
      ),
      this.db.queryOne<{ count: string }>(
        "SELECT count(*)::text AS count FROM batch_events WHERE anchored_at IS NULL",
      ),
    ]);
    return {
      events_awaiting_anchor: Number(unanchored?.count ?? 0),
      last_confirmed_at: list.find((a) => a.status === "CONFIRMED")?.anchored_at ?? null,
      anchors: list,
    };
  }

  async audit(q: AdminAuditQueryDto) {
    const rows = await this.db.query(
      `SELECT a.id, a.action, a.entity, a.entity_id, a.before, a.after,
              a.created_at::text AS created_at,
              u.name AS user_name, au.email AS admin_email
       FROM audit_log a
       LEFT JOIN users u ON u.id = a.user_id
       LEFT JOIN admin_users au ON au.id = a.user_id
       WHERE ($1::text IS NULL OR a.action ILIKE $1 OR a.entity ILIKE $1 OR COALESCE(u.name, '') ILIKE $1)
         AND ($2::text IS NULL OR a.action = $2)
         AND ($3::text IS NULL OR a.entity = $3)
       ORDER BY CASE WHEN $4::text = 'oldest' THEN a.created_at END ASC NULLS LAST, a.created_at DESC
       LIMIT 300`,
      [q.q ? `%${q.q}%` : null, q.action ?? null, q.entity ?? null, q.sort ?? "newest"],
    );
    return { total: rows.length, entries: rows };
  }

  // ---- Verdict engine (shared by overview + lists) ---------------------------

  /** batch_id → verdict for every batch, cached 60s. */
  private async verdictMap(): Promise<Map<string, Verdict>> {
    if (this.verdictCache && Date.now() - this.verdictCache.at < 60_000) {
      return this.verdictCache.map;
    }
    const [events, coverage] = await Promise.all([
      this.db.query<Record<string, unknown>>(
        `SELECT batch_id, event_type, actor_user_id, actor_role, payload,
                parent_event_hash, event_hash, created_at
         FROM batch_events ORDER BY batch_id, created_at, id`,
      ),
      this.db.query<{ batch_id: string; total: string; anchored: string }>(
        `SELECT batch_id, count(*)::text AS total, count(anchored_at)::text AS anchored
         FROM batch_events GROUP BY batch_id`,
      ),
    ]);

    const byBatch = new Map<string, StoredEvent[]>();
    for (const e of events) {
      const list = byBatch.get(e.batch_id as string) ?? [];
      list.push({
        batchId: e.batch_id as string,
        eventType: e.event_type as string,
        actorUserId: e.actor_user_id as string,
        actorRole: e.actor_role as string,
        payload: e.payload as Record<string, unknown>,
        parentEventHash: (e.parent_event_hash as string | null) ?? null,
        occurredAt: new Date(e.created_at as string).toISOString(),
        eventHash: e.event_hash as string,
      });
      byBatch.set(e.batch_id as string, list);
    }

    const map = new Map<string, Verdict>();
    for (const c of coverage) {
      const chain = byBatch.get(c.batch_id) ?? [];
      const chainValid = verifyChain(chain).valid;
      const anchored = Number(c.anchored);
      const total = Number(c.total);
      map.set(c.batch_id, !chainValid ? "TAMPERED" : total > 0 && anchored === total ? "AUTHENTIC" : "PENDING");
    }
    this.verdictCache = { at: Date.now(), map };
    return map;
  }

  private async verdictCounts() {
    const map = await this.verdictMap();
    const counts = { AUTHENTIC: 0, PENDING: 0, TAMPERED: 0 };
    for (const v of map.values()) counts[v] += 1;
    return counts;
  }
}
