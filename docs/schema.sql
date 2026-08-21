-- ============================================================
-- Cinnamon Trace — PostgreSQL Schema (v0.1)
-- Conventions:
--   * UUIDv7 primary keys (time-ordered)
--   * All timestamps TIMESTAMPTZ, server default now()
--   * batch_events is the immutable append-only ledger
--   * batch_actors is a trigger-maintained denormalized
--     visibility cache used by RLS
--   * RLS policies below are READ policies for the app role.
--     Writes happen through SECURITY DEFINER service functions
--     owned by a privileged role (keeps business rules in one
--     auditable place).
-- Requires: pgcrypto (gen_random_uuid) — UUIDv7 supplied by app.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------- ENUMS ----------
CREATE TYPE role_code      AS ENUM ('FARMER','PROCESSOR_L1','COLLECTOR','PROCESSOR_L2','EXPORTER');
CREATE TYPE harvest_type   AS ENUM ('T','Q');              -- Trees | Quills
CREATE TYPE batch_status   AS ENUM
  ('HARVESTED','IN_TRANSIT','RECEIVED','PROCESSED','MERGED','EXPORTED');
CREATE TYPE event_type     AS ENUM
  ('CREATED','TRANSFERRED','PROCESSED','MERGED_IN','EXPORTED','ANCHORED');
CREATE TYPE transfer_kind  AS ENUM ('SALE','HANDOFF');
CREATE TYPE anchor_network AS ENUM ('POLYGON','VECHAIN','BITCOIN_OTS');
CREATE TYPE size_unit      AS ENUM ('ACRE','PERCH','HECTARE');

-- ---------- USERS & ROLES ----------
CREATE TABLE users (
  id             UUID PRIMARY KEY,
  name           TEXT        NOT NULL,
  mobile         TEXT        NOT NULL UNIQUE,              -- E.164 e.g. +94771234567
  email          TEXT,
  password_hash  TEXT,                                     -- nullable when OTP-only
  preferred_lang TEXT        NOT NULL DEFAULT 'si'
                              CHECK (preferred_lang IN ('si','ta','en')),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE user_roles (
  user_id UUID      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role    role_code NOT NULL,
  PRIMARY KEY (user_id, role)
);

-- ---------- FARMS ----------
CREATE TABLE farms (
  id            UUID PRIMARY KEY,
  owner_user_id UUID       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name          TEXT       NOT NULL,
  area_code     CHAR(2)    NOT NULL,                       -- 'GM','KN','MK'…
  farmer_code   TEXT       NOT NULL,                       -- short code used in batch no ('A','21'…)
  size_value    NUMERIC(10,2) NOT NULL CHECK (size_value > 0),
  size_unit     size_unit  NOT NULL DEFAULT 'ACRE',
  lat           NUMERIC(9,6),
  lng           NUMERIC(9,6),
  address_text  TEXT,
  plot_polygon  JSONB,                                     -- GeoJSON polygon (EUDR-grade, v2)
  location_public_level TEXT NOT NULL DEFAULT 'DISTRICT'
                  CHECK (location_public_level IN ('EXACT','DISTRICT','HIDDEN')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_farms_owner ON farms (owner_user_id);

-- ---------- BATCHES ----------
-- One row per physical batch at any stage. Root batches have
-- farm_id set; derived/merged batches reference parents.
CREATE TABLE batches (
  id               UUID PRIMARY KEY,
  batch_no         TEXT        NOT NULL UNIQUE,            -- immutable after creation
  farm_id          UUID        REFERENCES farms(id),       -- root batch only
  harvest_type     harvest_type,                           -- root batch only
  harvest_date     DATE,                                   -- root batch only
  tree_count       INTEGER     CHECK (tree_count IS NULL OR tree_count >= 0),
  weight_kg        NUMERIC(10,2) NOT NULL CHECK (weight_kg >= 0),
  status           batch_status NOT NULL DEFAULT 'HARVESTED',
  current_holder_id   UUID     REFERENCES users(id),
  current_holder_role role_code,
  root_batch_no    TEXT        NOT NULL,                   -- denormalized: farmer's original no
  stage_suffix     TEXT        NOT NULL DEFAULT '',        -- '/P1', '/P1/P2'…
  parents          JSONB,                                  -- [{batch_id, batch_no}] for merged lots
  chain_head_hash  TEXT,                                   -- latest event_hash in this chain
  created_by       UUID        NOT NULL REFERENCES users(id),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_batches_farm           ON batches (farm_id);
CREATE INDEX idx_batches_holder         ON batches (current_holder_id);
CREATE INDEX idx_batches_status         ON batches (status);
CREATE INDEX idx_batches_root_no        ON batches (root_batch_no);
CREATE INDEX idx_batches_created_by     ON batches (created_by);

-- ---------- BATCH EVENTS (immutable ledger) ----------
-- event_hash = H(parent_hash || payload || actor || role || ts)
-- computed by the service layer before insert. Rows are never
-- updated or deleted.
CREATE TABLE batch_events (
  id                UUID PRIMARY KEY,
  batch_id          UUID        NOT NULL REFERENCES batches(id),
  event_type        event_type  NOT NULL,
  actor_user_id     UUID        NOT NULL REFERENCES users(id),
  actor_role        role_code   NOT NULL,
  from_user_id      UUID        REFERENCES users(id),
  to_user_id        UUID        REFERENCES users(id),
  transfer_kind     transfer_kind,                         -- TRANSFERRED only
  payload           JSONB       NOT NULL DEFAULT '{}'::jsonb,
  parent_event_hash TEXT,                                  -- NULL for CREATED
  event_hash        TEXT        NOT NULL UNIQUE,
  anchored_at       TIMESTAMPTZ,                           -- set when included in an anchor
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_events_batch           ON batch_events (batch_id, created_at);
CREATE INDEX idx_events_actor           ON batch_events (actor_user_id);
CREATE INDEX idx_events_parent_hash     ON batch_events (parent_event_hash);

-- ---------- BATCH ACTORS (visibility cache) ----------
-- Maintained by trigger on batch_events. Powers the O(1) RLS read check.
CREATE TABLE batch_actors (
  batch_id UUID      NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
  user_id  UUID      NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
  role     role_code NOT NULL,
  PRIMARY KEY (batch_id, user_id, role)
);
CREATE INDEX idx_batch_actors_user ON batch_actors (user_id);

-- ---------- MERGE GROUPS (export lots) ----------
CREATE TABLE merge_parents (
  lot_batch_id      UUID NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
  source_batch_id   UUID NOT NULL REFERENCES batches(id),
  PRIMARY KEY (lot_batch_id, source_batch_id)
);

-- ---------- CHAIN ANCHORS ----------
CREATE TABLE chain_anchors (
  id              UUID PRIMARY KEY,
  merkle_root     TEXT         NOT NULL UNIQUE,
  chain_head_hash TEXT         NOT NULL,
  event_count     INTEGER      NOT NULL CHECK (event_count > 0),
  network         anchor_network NOT NULL DEFAULT 'POLYGON',
  tx_hash         TEXT,
  block_no        BIGINT,
  status          TEXT         NOT NULL DEFAULT 'PENDING'
                               CHECK (status IN ('PENDING','CONFIRMED','FAILED')),
  anchored_at     TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ---------- AUDIT LOG ----------
CREATE TABLE audit_log (
  id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id    UUID,
  action     TEXT        NOT NULL,
  entity     TEXT,
  entity_id  UUID,
  before     JSONB,
  after      JSONB,
  created_at TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX idx_audit_user ON audit_log (user_id, created_at);

-- ---------- OTP ----------
CREATE TABLE otp_codes (
  id         UUID PRIMARY KEY,
  mobile     TEXT        NOT NULL,
  code_hash  TEXT        NOT NULL,
  purpose    TEXT        NOT NULL DEFAULT 'LOGIN' CHECK (purpose IN ('LOGIN','REGISTER')),
  expires_at TIMESTAMPTZ NOT NULL,
  used_at    TIMESTAMPTZ,
  attempts   SMALLINT    NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_otp_mobile ON otp_codes (mobile, created_at);

-- ============================================================
-- TRIGGER: maintain batch_actors
-- ============================================================
CREATE OR REPLACE FUNCTION trg_maintain_batch_actors()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO batch_actors (batch_id, user_id, role)
  VALUES (NEW.batch_id, NEW.actor_user_id, NEW.actor_role)
  ON CONFLICT (batch_id, user_id, role) DO NOTHING;

  IF NEW.event_type = 'TRANSFERRED' AND NEW.to_user_id IS NOT NULL THEN
    INSERT INTO batch_actors (batch_id, user_id, role)
    SELECT NEW.batch_id, NEW.to_user_id, r.role
    FROM user_roles r
    WHERE r.user_id = NEW.to_user_id
    ON CONFLICT (batch_id, user_id, role) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER batch_events_maintain_actors
  AFTER INSERT ON batch_events
  FOR EACH ROW EXECUTE FUNCTION trg_maintain_batch_actors();

-- ============================================================
-- ROW-LEVEL SECURITY: upward-only visibility
-- A user sees a batch iff they appear anywhere in its event
-- chain (batch_actors). Nobody sees downstream — downstream
-- nodes belong to other users' chains, and a transferred-away
-- batch still shows the transferor their history only.
-- Farm owners additionally see all batches grown on their farms.
-- ============================================================
CREATE OR REPLACE FUNCTION can_view_batch(b_id UUID, uid UUID)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT EXISTS (SELECT 1 FROM batch_actors ba WHERE ba.batch_id = b_id AND ba.user_id = uid)
      OR EXISTS (
           SELECT 1
           FROM batches b
           JOIN farms f ON f.id = b.farm_id
           WHERE b.id = b_id AND f.owner_user_id = uid
         );
$$;

ALTER TABLE batches       ENABLE ROW LEVEL SECURITY;
ALTER TABLE batch_events  ENABLE ROW LEVEL SECURITY;
ALTER TABLE batch_actors  ENABLE ROW LEVEL SECURITY;
ALTER TABLE merge_parents ENABLE ROW LEVEL SECURITY;

CREATE POLICY batches_read ON batches
  FOR SELECT
  USING (status = 'EXPORTED' OR can_view_batch(id, auth.uid()));

CREATE POLICY events_read ON batch_events
  FOR SELECT
  USING (can_view_batch(batch_id, auth.uid()));

CREATE POLICY actors_read_self ON batch_actors
  FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY merge_parents_read ON merge_parents
  FOR SELECT
  USING (can_view_batch(lot_batch_id, auth.uid()));

-- Writes are NOT granted to the app role; the service layer
-- inserts through SECURITY DEFINER functions owned by a
-- privileged role, so RLS cannot be bypassed accidentally and
-- all business rules live in one place.

-- ============================================================
-- NOTES
-- * batch_no is generated client-side (offline-safe) and
--   enforced unique server-side. Collisions surface as 409 on
--   sync and the client regenerates with next sequence.
-- * The nightly anchor job: SELECT all batch_events with
--   anchored_at IS NULL → build Merkle tree → INSERT
--   chain_anchors (PENDING) → submit tx → UPDATE status/tx_hash
--   → backfill anchored_at on included events.
-- * auth.uid() is a placeholder for the request-scoped user id
--   (set_config('request.jwt.uid', …) pattern in PostgREST, or
--   pass explicitly from the service layer).
-- ============================================================
