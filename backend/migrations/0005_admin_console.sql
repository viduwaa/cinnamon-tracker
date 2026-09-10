-- 0005: Admin console — Department of Cinnamon Development oversight dashboard.
-- Separate credential store (admin_users) so government operators never live
-- in the farmer/processor account space; the login page lives on its own
-- domain. App users get is_active so admins can suspend accounts; the ledger
-- itself stays untouched by this console (read-only by design).

CREATE TABLE admin_users (
  id            UUID PRIMARY KEY,
  email         TEXT        NOT NULL UNIQUE,
  name          TEXT        NOT NULL,
  password_hash TEXT        NOT NULL,
  is_active     BOOLEAN     NOT NULL DEFAULT true,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Suspension flag for app users. Nullable + default NULL = no legacy rows
-- touched; treat NULL as active (IS NOT FALSE checks in the auth service).
ALTER TABLE users ADD COLUMN is_active BOOLEAN;

CREATE INDEX idx_audit_created ON audit_log (created_at);
CREATE INDEX idx_batches_created_at ON batches (created_at);
CREATE INDEX idx_chain_anchors_status ON chain_anchors (status);
