import { useEffect, useState } from "react";
import { api, type AnchorRow } from "../api";
import { Card, Empty, ErrorNote } from "../ui";

/** Chain-anchor monitor: the nightly OpenTimestamps → Bitcoin witness run. */
export function AnchorsPage() {
  const [data, setData] = useState<{
    events_awaiting_anchor: number;
    last_confirmed_at: string | null;
    anchors: AnchorRow[];
  } | null>(null);
  const [error, setError] = useState<unknown>(null);

  useEffect(() => {
    api<{
      events_awaiting_anchor: number;
      last_confirmed_at: string | null;
      anchors: AnchorRow[];
    }>("/v1/admin/analytics/anchors")
      .then(setData)
      .catch(setError);
  }, []);

  if (error) return <ErrorNote error={error} />;
  if (!data) return <div className="text-faded text-sm">Loading…</div>;

  return (
    <div className="space-y-5">
      <h1 className="text-2xl font-bold">Blockchain anchors</h1>

      <div className="grid md:grid-cols-3 gap-4">
        <Card>
          <div className="text-xs font-semibold uppercase tracking-wide text-faded">Events awaiting anchor</div>
          <div className="font-display text-3xl font-bold mt-1">{data.events_awaiting_anchor}</div>
          <div className="text-xs text-faded mt-1">included in tonight's Merkle root</div>
        </Card>
        <Card>
          <div className="text-xs font-semibold uppercase tracking-wide text-faded">Last confirmed anchor</div>
          <div className="font-display text-lg font-bold mt-2">
            {data.last_confirmed_at ? new Date(data.last_confirmed_at).toLocaleString() : "—"}
          </div>
          <div className="text-xs text-faded mt-1">Bitcoin (OpenTimestamps) witness</div>
        </Card>
        <Card>
          <div className="text-xs font-semibold uppercase tracking-wide text-faded">Anchor runs (last 100)</div>
          <div className="font-display text-3xl font-bold mt-1">{data.anchors.length}</div>
          <div className="text-xs text-faded mt-1">
            {data.anchors.filter((a) => a.status === "FAILED").length} failed ·{" "}
            {data.anchors.filter((a) => a.status === "PENDING").length} pending
          </div>
        </Card>
      </div>

      <div className="bg-paper rounded-md border border-line overflow-x-auto">
        <table className="ct w-full">
          <thead>
            <tr>
              <th>Anchored at</th>
              <th>Network</th>
              <th>Status</th>
              <th className="text-right">Events</th>
              <th>Merkle root</th>
              <th>Tx</th>
            </tr>
          </thead>
          <tbody>
            {data.anchors.map((a) => (
              <tr key={a.id}>
                <td className="text-xs">{new Date(a.anchored_at).toLocaleString()}</td>
                <td>{a.network.replace("_", " ")}</td>
                <td>
                  <span
                    className={`inline-block rounded-sm px-2 py-0.5 text-xs font-semibold ${
                      a.status === "CONFIRMED"
                        ? "bg-leaf-soft text-leaf-dark"
                        : a.status === "FAILED"
                          ? "bg-clay-soft text-clay-dark"
                          : "bg-quill-soft text-[#8A5A10]"
                    }`}
                  >
                    {a.status}
                  </span>
                </td>
                <td className="text-right">{a.event_count}</td>
                <td className="font-mono text-xs">{a.merkle_root.slice(0, 18)}…</td>
                <td className="font-mono text-xs">{a.tx_hash ? `${a.tx_hash.slice(0, 14)}…` : "—"}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {data.anchors.length === 0 && <Empty>No anchor runs recorded yet — the nightly job anchors at midnight.</Empty>}
      </div>
    </div>
  );
}
