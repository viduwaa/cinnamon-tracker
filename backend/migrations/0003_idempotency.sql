-- Idempotency keys for offline-safe retries (api-spec §Conventions).
-- The Flutter outbox sends an Idempotency-Key on every push; a replayed key
-- must return the original response instead of re-executing (a duplicate
-- client UUIDv7 id would otherwise surface as an unhandled PK violation).
CREATE TABLE idempotency_keys (
  key           TEXT        NOT NULL,
  endpoint      TEXT        NOT NULL,              -- 'METHOD /path'
  user_id       UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  request_hash  TEXT        NOT NULL,              -- sha256(canonical JSON body)
  status_code   INTEGER,                           -- NULL while in flight / failed
  response_body JSONB,
  locked_at     TIMESTAMPTZ NOT NULL DEFAULT now(), -- in-flight takeover threshold
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (key, endpoint, user_id)
);
CREATE INDEX idx_idempotency_created ON idempotency_keys (created_at);
