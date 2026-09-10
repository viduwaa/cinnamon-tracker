import { useCallback, useEffect, useState } from "react";
import { api, type AuditRow } from "../api";
import { Empty, ErrorNote } from "../ui";

/** Who did what — admin actions and app-level audit events in one stream. */
export function AuditPage() {
  const [entries, setEntries] = useState<AuditRow[]>([]);
  const [error, setError] = useState<unknown>(null);
  const [q, setQ] = useState("");
  const [action, setAction] = useState("");
  const [sort, setSort] = useState("newest");

  const qs = new URLSearchParams();
  if (q) qs.set("q", q);
  if (action) qs.set("action", action);
  qs.set("sort", sort);
  const queryString = qs.toString();

  const load = useCallback(async () => {
    try {
      const res = await api<{ entries: AuditRow[] }>(`/v1/admin/analytics/audit?${queryString}`);
      setEntries(res.entries);
      setError(null);
    } catch (err) {
      setError(err);
    }
  }, [queryString]);

  useEffect(() => {
    const t = setTimeout(load, 250);
    return () => clearTimeout(t);
  }, [load]);

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold">Audit log</h1>

      <div className="flex flex-wrap gap-2 items-center">
        <input
          className="ct w-64"
          placeholder="Search action, entity, user…"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          aria-label="Search audit log"
        />
        <input
          className="ct w-48"
          placeholder="Exact action (e.g. USER_SUSPENDED)"
          value={action}
          onChange={(e) => setAction(e.target.value)}
          aria-label="Filter by action"
        />
        <select className="ct" value={sort} onChange={(e) => setSort(e.target.value)} aria-label="Sort">
          <option value="newest">Newest first</option>
          <option value="oldest">Oldest first</option>
        </select>
        <span className="text-xs text-faded ml-auto">{entries.length} entries</span>
      </div>

      {error ? <ErrorNote error={error} /> : null}

      <div className="bg-paper rounded-md border border-line overflow-x-auto">
        <table className="ct w-full">
          <thead>
            <tr>
              <th>When</th>
              <th>Action</th>
              <th>Entity</th>
              <th>Actor</th>
              <th>Detail</th>
            </tr>
          </thead>
          <tbody>
            {entries.map((e) => (
              <tr key={e.id}>
                <td className="text-xs whitespace-nowrap">{new Date(e.created_at).toLocaleString()}</td>
                <td>
                  <span
                    className={`rounded-sm px-1.5 py-0.5 text-[11px] font-semibold font-mono ${
                      e.action.startsWith("USER_S") || e.action.includes("SUSPEND")
                        ? "bg-clay-soft text-clay-dark"
                        : e.action.startsWith("ADMIN")
                          ? "bg-quill-soft text-bark"
                          : "bg-neutral text-bark"
                    }`}
                  >
                    {e.action}
                  </span>
                </td>
                <td className="text-xs">
                  {e.entity ?? "—"}
                  {e.entity_id && <div className="font-mono text-faded">{e.entity_id.slice(0, 13)}…</div>}
                </td>
                <td className="text-sm">{e.admin_email ?? e.user_name ?? "system"}</td>
                <td className="text-xs text-faded max-w-[280px] truncate">
                  {e.after ? JSON.stringify(e.after) : e.action}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {entries.length === 0 && !error && <Empty>No audit entries match.</Empty>}
      </div>
    </div>
  );
}
