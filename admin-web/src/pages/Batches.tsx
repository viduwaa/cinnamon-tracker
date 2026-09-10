import { useCallback, useEffect, useState } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { api, downloadBatchesCsv, type AdminBatch } from "../api";
import { Empty, ErrorNote, VerdictBadge } from "../ui";

const STATUSES = ["HARVESTED", "IN_TRANSIT", "RECEIVED", "PROCESSED", "MERGED", "EXPORTED"];
const ROLES = ["FARMER", "PROCESSOR_L1", "COLLECTOR", "PROCESSOR_L2", "EXPORTER"];

export function BatchesPage() {
  const [params, setParams] = useSearchParams();
  const [batches, setBatches] = useState<AdminBatch[]>([]);
  const [error, setError] = useState<unknown>(null);
  const [loading, setLoading] = useState(true);

  // Filters live in the URL — shareable links for govt reporting.
  const q = params.get("q") ?? "";
  const verdict = params.get("verdict") ?? "";
  const status = params.get("status") ?? "";
  const role = params.get("role") ?? "";
  const sort = params.get("sort") ?? "newest";

  const set = (key: string, value: string) => {
    const next = new URLSearchParams(params);
    if (value) next.set(key, value);
    else next.delete(key);
    setParams(next, { replace: true });
  };

  const queryString = params.toString();

  useEffect(() => {
    const t = setTimeout(async () => {
      setLoading(true);
      try {
        const res = await api<{ batches: AdminBatch[] }>(`/v1/admin/batches?${queryString}`);
        setBatches(res.batches);
        setError(null);
      } catch (err) {
        setError(err);
      } finally {
        setLoading(false);
      }
    }, 250);
    return () => clearTimeout(t);
  }, [queryString]);

  const exportCsv = useCallback(async () => {
    try {
      await downloadBatchesCsv(queryString);
    } catch (err) {
      setError(err);
    }
  }, [queryString]);

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Batches</h1>
        <button onClick={exportCsv} className="rounded-sm bg-quill-soft hover:bg-tertiary hover:text-paper text-bark font-semibold text-sm px-3 py-2">
          Export CSV
        </button>
      </div>

      <div className="flex flex-wrap gap-2 items-center">
        <input
          className="ct w-60"
          placeholder="Batch no / holder…"
          value={q}
          onChange={(e) => set("q", e.target.value)}
          aria-label="Search batches"
        />
        <select className="ct" value={verdict} onChange={(e) => set("verdict", e.target.value)} aria-label="Filter by verdict">
          <option value="">All verdicts</option>
          <option value="AUTHENTIC">Authentic</option>
          <option value="PENDING">Pending</option>
          <option value="TAMPERED">Tampered</option>
        </select>
        <select className="ct" value={status} onChange={(e) => set("status", e.target.value)} aria-label="Filter by status">
          <option value="">All statuses</option>
          {STATUSES.map((s) => (
            <option key={s} value={s}>
              {s.replace("_", " ")}
            </option>
          ))}
        </select>
        <select className="ct" value={role} onChange={(e) => set("role", e.target.value)} aria-label="Filter by holder role">
          <option value="">All holder roles</option>
          {ROLES.map((r) => (
            <option key={r} value={r}>
              {r.replace("_", " ")}
            </option>
          ))}
        </select>
        <select className="ct" value={sort} onChange={(e) => set("sort", e.target.value)} aria-label="Sort">
          <option value="newest">Newest first</option>
          <option value="oldest">Oldest first</option>
          <option value="weight">Heaviest first</option>
        </select>
        <span className="text-xs text-faded ml-auto">{loading ? "loading…" : `${batches.length} batches`}</span>
      </div>

      {error ? <ErrorNote error={error} /> : null}

      <div className="bg-paper rounded-md border border-line overflow-x-auto">
        <table className="ct w-full">
          <thead>
            <tr>
              <th>Batch no</th>
              <th>Verdict</th>
              <th>Status</th>
              <th className="text-right">Weight</th>
              <th>District</th>
              <th>Holder</th>
              <th>Created</th>
            </tr>
          </thead>
          <tbody>
            {batches.map((b) => (
              <tr key={b.id}>
                <td>
                  <Link to={`/batches/${b.batch_no}`} className="font-semibold text-primary hover:underline font-mono text-xs">
                    {b.batch_no}
                  </Link>
                </td>
                <td>
                  <VerdictBadge verdict={b.verdict} />
                </td>
                <td>{b.status.replace("_", " ")}</td>
                <td className="text-right">{b.weight_kg.toLocaleString()} kg</td>
                <td>{b.district ?? "—"}</td>
                <td>
                  {b.holder_name ?? "—"}
                  {b.current_holder_role && <span className="text-xs text-faded"> · {b.current_holder_role.replace("_", " ")}</span>}
                </td>
                <td className="text-xs text-faded">{new Date(b.created_at).toLocaleDateString()}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {batches.length === 0 && !loading && !error && <Empty>No batches match these filters.</Empty>}
      </div>
    </div>
  );
}
