/** Admin API client — bearer-token fetch with typed helpers. */

const TOKEN_KEY = "ct_admin_token";

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string | null) {
  if (token) localStorage.setItem(TOKEN_KEY, token);
  else localStorage.removeItem(TOKEN_KEY);
}

export class ApiError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
  ) {
    super(message);
  }
}

export async function api<T>(path: string, opts: RequestInit = {}): Promise<T> {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...((opts.headers as Record<string, string>) ?? {}),
  };
  const token = getToken();
  if (token) headers.Authorization = `Bearer ${token}`;

  const res = await fetch(path, { ...opts, headers });
  if (res.status === 401) {
    setToken(null);
    window.location.href = "/login";
    throw new ApiError(401, "SESSION_EXPIRED", "Session expired");
  }
  let body: unknown = null;
  try {
    body = await res.json();
  } catch {
    body = null;
  }
  if (!res.ok) {
    const err = (body as { error?: { code?: string; message?: string } })?.error;
    throw new ApiError(res.status, err?.code ?? "ERROR", err?.message ?? res.statusText);
  }
  return body as T;
}

/** CSV download for a filtered batch view (Authorization via fetch blob). */
export async function downloadBatchesCsv(query: string) {
  const res = await fetch(`/v1/admin/batches?${query}&format=csv`, {
    headers: { Authorization: `Bearer ${getToken() ?? ""}` },
  });
  if (!res.ok) throw new ApiError(res.status, "CSV_FAILED", "Export failed");
  const blob = await res.blob();
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = "batches.csv";
  a.click();
  URL.revokeObjectURL(url);
}

// ---- Types (mirror of backend payloads) -------------------------------------

export type Verdict = "AUTHENTIC" | "TAMPERED" | "PENDING";

export interface Overview {
  users: { total: number; suspended: number; new_today: number };
  batches: { total: number; today: number; weight_kg: number };
  verdicts: Record<Verdict, number>;
  anchors: {
    by_status: Record<string, number>;
    last_confirmed_at: string | null;
    events_awaiting_anchor: number;
  };
  batches_per_day: Array<{ day: string; count: number }>;
  activity_by_role: Array<{ role: string; batches_touched: number; events: number }>;
  custody_by_role: Array<{ role: string; batches: number }>;
  districts: Array<{ area_code: string; name: string; batches: number; weight_kg: number }>;
}

export interface AdminUser {
  id: string;
  name: string;
  mobile: string;
  email: string | null;
  is_active: boolean;
  created_at: string;
  roles: string[];
  batches: number;
  farms: number;
}

export interface AdminBatch {
  id: string;
  batch_no: string;
  status: string;
  verdict: Verdict;
  weight_kg: number;
  district: string | null;
  current_holder_role: string | null;
  holder_name: string | null;
  created_at: string;
}

export interface BatchDetail {
  batch: Record<string, unknown> & { batch_no: string; status: string };
  verification: {
    verdict: Verdict;
    event_count: number;
    anchored_count: number;
    anchors: Array<{
      network: string;
      merkle_root: string;
      tx_hash: string | null;
      anchored_at: string;
      status: string;
    }>;
  };
  chain: { origin: Record<string, unknown> | null; events: Array<Record<string, unknown>> };
}

export interface AnchorRow {
  id: string;
  merkle_root: string;
  event_count: number;
  network: string;
  tx_hash: string | null;
  block_no: number | null;
  status: string;
  anchored_at: string;
}

export interface AuditRow {
  id: number;
  action: string;
  entity: string | null;
  entity_id: string | null;
  after: Record<string, unknown> | null;
  created_at: string;
  user_name: string | null;
  admin_email: string | null;
}
