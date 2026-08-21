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
    // farmer_code: short per-owner code used inside batch numbers.
    // Derived from the owner's farm count so it is stable and short (A, B, …, then AA…).
    const countRow = await this.db.queryOne<{ n: string }>(
      "SELECT count(*)::text AS n FROM farms WHERE owner_user_id = $1",
      [userId],
    );
    const farmerCode = this.encodeFarmerCode(Number(countRow?.n ?? 0) + 1);

    await this.db.query(
      `INSERT INTO farms
         (id, owner_user_id, name, area_code, farmer_code, size_value, size_unit,
          lat, lng, address_text, location_public_level)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
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

    return this.get(userId, dto.id);
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
}
