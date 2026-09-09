-- ============================================================
-- 0004 — Phase 2: processing stages (P1/P2), alias-preserving
-- renumbering, and exporter lots (container consolidation).
--
-- Everything here extends the pre-architected Phase-2 hooks from
-- 0001 (root_batch_no, stage_suffix, parents, merge_parents,
-- MERGED_IN / EXPORTED). No existing table is rebuilt.
-- ============================================================

-- ---------- ALIASES: old batch numbers keep resolving ----------
-- Renumbering (P2/exporter custom names, /P2 · /EX suffix appends)
-- mutates batches.batch_no in place. Any number a batch has EVER
-- had is kept resolvable here so printed QR labels survive renames.
CREATE TABLE batch_no_aliases (
  alias    TEXT NOT NULL,                -- a former batch_no
  batch_id UUID NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
  PRIMARY KEY (alias)
);
CREATE INDEX idx_batch_no_aliases_batch ON batch_no_aliases (batch_id);
ALTER TABLE batch_no_aliases ENABLE ROW LEVEL SECURITY;
CREATE POLICY batch_no_aliases_read ON batch_no_aliases
  FOR SELECT USING (
    can_view_batch(batch_id, auth.uid())
    OR EXISTS (SELECT 1 FROM batches b
               WHERE b.id = batch_no_aliases.batch_id
                 AND b.status = 'EXPORTED')
  );

-- ---------- EXPORTER IDENTITY ----------
-- Mirrors farms.farmer_code: baked into lot numbers, assigned once,
-- never recycled. Column is nullable so existing exporter rows are
-- valid until their first lot creation backfills the code.
ALTER TABLE users ADD COLUMN exporter_code TEXT;
CREATE UNIQUE INDEX idx_users_exporter_code
  ON users (exporter_code) WHERE exporter_code IS NOT NULL;

-- ---------- RENAME EVENT ----------
-- P2 / exporter custom renumbering is a first-class ledger event so the
-- chain shows who renumbered what, when.
ALTER TYPE event_type ADD VALUE IF NOT EXISTS 'RENAMED' AFTER 'PROCESSED';

-- ---------- LOT SHIPMENT FIELDS ----------
-- One-step export (Q5): the lot row is created already EXPORTED with
-- shipment details inline. Nullable: only lot rows carry them.
ALTER TABLE batches
  ADD COLUMN shipment_date         DATE,
  ADD COLUMN destination_country   CHAR(2),
  ADD COLUMN buyer_name            TEXT,
  ADD COLUMN container_no          TEXT;
