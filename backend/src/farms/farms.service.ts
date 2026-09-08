import { Injectable } from "@nestjs/common";
import { Errors } from "../common/errors";
import { DatabaseService } from "../database/database.service";
import { CreateFarmDto, UpdateFarmDto } from "./dto";

interface FarmRow {
  id: string;
  owner_user_id: string;
  name: string;
  area_code: string;
  farmer_code: string;
  size_value: string;
  size_unit: string;
  lat: string | null;
  lng: string | null;
  address_text: string | null;
  location_public_level: string;
  created_at: string;
}

@Injectable()
export class FarmsService {
  constructor(private readonly db: DatabaseService) {}

  async create(userId: string, dto: CreateFarmDto) {
    try {
      return await this.db.transaction((client) =>
        this.insertWithCodeAllocation(client, userId, dto),
      );
    } catch (err) {
      // Recovery happens on the pool, NOT inside the aborted transaction —
      // Postgres rejects any statement after a failed one (25P02).
      if ((err as { code?: string }).code === "23505") {
        const row = await this.db.queryOne<FarmRow>(
          "SELECT * FROM farms WHERE id = $1",
          [dto.id],
        );
        if (row && row.owner_user_id === userId) return this.toPublic(row);
        throw Errors.conflict("ID_TAKEN", "A farm with this id already exists");
      }
      throw err;
    }
  }

  private async insertWithCodeAllocation(
    client: import("pg").PoolClient,
    userId: string,
    dto: CreateFarmDto,
  ) {
    // Natural idempotency pre-check: a replayed create (lost response, key
    // header missing) returns the already-created farm instead of a PK hit.
    const existing = await client.query<FarmRow>(
      "SELECT * FROM farms WHERE id = $1",
      [dto.id],
    );
    if ((existing.rowCount ?? 0) > 0) {
      const row = existing.rows[0]!;
      if (row.owner_user_id === userId) return this.toPublic(row);
      throw Errors.conflict("ID_TAKEN", "A farm with this id already exists");
    }

    // farmer_code is baked into immutable batch numbers (PLAN §4), so
    // allocation must be serialized per owner and must never recycle after
    // deletions: next = max(count, max existing decoded code) + 1.
    await client.query("SELECT pg_advisory_xact_lock(hashtext($1))", [
      `farmer_code:${userId}`,
    ]);
    const ownerFarms = await client.query<{ farmer_code: string }>(
      "SELECT farmer_code FROM farms WHERE owner_user_id = $1",
      [userId],
    );
    const maxDecoded = ownerFarms.rows.reduce(
      (max, r) => Math.max(max, this.decodeFarmerCode(r.farmer_code)),
      0,
    );
    const farmerCode = this.encodeFarmerCode(maxDecoded + 1);

    const inserted = await client.query<FarmRow>(
      `INSERT INTO farms
         (id, owner_user_id, name, area_code, farmer_code, size_value, size_unit,
          lat, lng, address_text, location_public_level)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
       RETURNING *`,
      [
        dto.id,
        userId,
        dto.name,
        dto.area_code,
        farmerCode,
        dto.size_value,
        dto.size_unit ?? "ACRE",
        dto.lat ?? null,
        dto.lng ?? null,
        dto.address_text ?? null,
        dto.location_public_level ?? "DISTRICT",
      ],
    );

    await this.audit(client, userId, "FARM_CREATED", "farm", dto.id, {
      name: dto.name,
      area_code: dto.area_code,
      farmer_code: farmerCode,
    });

    return this.toPublic(inserted.rows[0]!);
  }

  private audit(
    client: import("pg").PoolClient,
    userId: string,
    action: string,
    entity: string,
    entityId: string,
    after: Record<string, unknown>,
  ) {
    return client.query(
      `INSERT INTO audit_log (user_id, action, entity, entity_id, after)
       VALUES ($1, $2, $3, $4, $5::jsonb)`,
      [userId, action, entity, entityId, JSON.stringify(after)],
    );
  }

  async listMine(userId: string) {
    const rows = await this.db.query<FarmRow>(
      "SELECT * FROM farms WHERE owner_user_id = $1 ORDER BY created_at",
      [userId],
    );
    return rows.map((r) => this.toPublic(r));
  }

  async get(userId: string, farmId: string) {
    const row = await this.db.queryOne<FarmRow>(
      "SELECT * FROM farms WHERE id = $1 AND owner_user_id = $2",
      [farmId, userId],
    );
    if (!row) throw Errors.notFound("FARM_NOT_FOUND", "Farm not found");
    return this.toPublic(row);
  }

  async update(userId: string, farmId: string, dto: UpdateFarmDto) {
    await this.get(userId, farmId); // ownership check
    const sets: string[] = [];
    const params: unknown[] = [];
    let i = 1;
    const fields: Array<[keyof UpdateFarmDto, string]> = [
      ["name", "name"],
      ["size_value", "size_value"],
      ["size_unit", "size_unit"],
      ["lat", "lat"],
      ["lng", "lng"],
      ["address_text", "address_text"],
      ["location_public_level", "location_public_level"],
    ];
    for (const [key, column] of fields) {
      const value = dto[key];
      if (value !== undefined) {
        sets.push(`${column} = $${i++}`);
        params.push(value);
      }
    }
    if (sets.length > 0) {
      params.push(farmId, userId);
      await this.db.query(
        `UPDATE farms SET ${sets.join(", ")} WHERE id = $${i} AND owner_user_id = $${i + 1}`,
        params,
      );
    }
    return this.get(userId, farmId);
  }

  private toPublic(row: FarmRow) {
    return {
      id: row.id,
      name: row.name,
      area_code: row.area_code,
      farmer_code: row.farmer_code,
      size_value: Number(row.size_value),
      size_unit: row.size_unit,
      lat: row.lat === null ? null : Number(row.lat),
      lng: row.lng === null ? null : Number(row.lng),
      address_text: row.address_text,
      location_public_level: row.location_public_level,
      created_at: row.created_at,
    };
  }

  /** 1→A, 2→B … 26→Z, 27→AA … keeps batch numbers short. */
  private encodeFarmerCode(n: number): string {
    let code = "";
    let value = n;
    while (value > 0) {
      const rem = (value - 1) % 26;
      code = String.fromCharCode(65 + rem) + code;
      value = Math.floor((value - 1) / 26);
    }
    return code;
  }

  /** Inverse of encodeFarmerCode; unknown shapes decode to 0 (ignored). */
  private decodeFarmerCode(code: string): number {
    if (!/^[A-Z]+$/.test(code)) return 0;
    let value = 0;
    for (const ch of code) value = value * 26 + (ch.charCodeAt(0) - 64);
    return value;
  }
}
