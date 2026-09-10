import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { api, type BatchDetail } from "../api";
import { Card, ErrorNote, VerdictBadge } from "../ui";

/** Single batch: verdict, Bitcoin anchors, and the full event chain. */
export function BatchDetailPage() {
  const { id } = useParams();
  const [data, setData] = useState<BatchDetail | null>(null);
  const [error, setError] = useState<unknown>(null);

  useEffect(() => {
    api<BatchDetail>(`/v1/admin/batches/${id}`).then(setData).catch(setError);
  }, [id]);

  if (error) return <ErrorNote error={error} />;
  if (!data) return <div className="text-faded text-sm">Loading…</div>;

  const b = data.batch;
  const origin = data.chain.origin as { farm_name?: string; district?: string; farmer_name?: string } | null;

  return (
    <div className="space-y-5">
      <div className="flex items-center gap-3">
        <Link to="/batches" className="text-sm text-primary hover:underline">
          ← All batches
        </Link>
      </div>
      <div className="flex flex-wrap items-center gap-3">
        <h1 className="text-2xl font-bold font-mono">{b.batch_no}</h1>
        <VerdictBadge verdict={data.verification.verdict} />
        <span className="rounded-sm bg-neutral px-2 py-0.5 text-xs font-semibold text-bark">
          {String(b.status).replace("_", " ")}
        </span>
      </div>

      <div className="grid md:grid-cols-3 gap-4">
        <Card>
          <h2 className="font-bold text-sm mb-2">Batch</h2>
          <dl className="text-sm space-y-1">
            <Row k="Weight" v={`${Number(b.weight_kg).toLocaleString()} kg`} />
            <Row k="Harvest type" v={b.harvest_type ? String(b.harvest_type) : "—"} />
            <Row k="Harvest date" v={b.harvest_date ? String(b.harvest_date) : "—"} />
            <Row k="Root batch" v={String(b.root_batch_no ?? "—")} />
            <Row k="Created" v={new Date(String(b.created_at)).toLocaleString()} />
          </dl>
        </Card>
        <Card>
          <h2 className="font-bold text-sm mb-2">Origin</h2>
          <dl className="text-sm space-y-1">
            <Row k="Farm" v={origin?.farm_name ?? String(b.farm_name ?? "—")} />
            <Row k="District" v={String(b.district ?? "—")} />
            <Row k="Holder" v={`${b.holder_name ?? "—"}${b.current_holder_role ? ` (${String(b.current_holder_role).replace("_", " ")})` : ""}`} />
            <Row k="Coordinates" v={b.lat != null ? `${b.lat}, ${b.lng}` : "—"} />
          </dl>
        </Card>
        <Card>
          <h2 className="font-bold text-sm mb-2">Anchoring</h2>
          <dl className="text-sm space-y-1">
            <Row k="Events" v={`${data.verification.anchored_count} / ${data.verification.event_count} anchored`} />
            {data.verification.anchors.slice(0, 2).map((a, i) => (
              <Row key={i} k={a.network} v={`${a.status}${a.tx_hash ? ` · ${a.tx_hash.slice(0, 10)}…` : ""}`} />
            ))}
          </dl>
        </Card>
      </div>

      <Card>
        <h2 className="font-bold mb-3">Event chain (immutable ledger)</h2>
        <ol className="space-y-0">
          {(data.chain.events ?? []).map((e, i) => {
            const hash = String(e.event_hash ?? "");
            return (
              <li key={i} className="flex gap-3 text-sm">
                <div className="flex flex-col items-center">
                  <div className={`w-2.5 h-2.5 rounded-full ${e.verified ? "bg-leaf" : "bg-clay"} mt-1.5`} />
                  {i < (data.chain.events?.length ?? 0) - 1 && <div className="w-px flex-1 bg-line" />}
                </div>
                <div className="pb-4">
                  <div className="font-semibold">
                    {String(e.event_type).replace("_", " ")}
                    <span className="font-normal text-faded"> · {String(e.actor_role).replace("_", " ")} · {String(e.actor_name ?? "")}</span>
                  </div>
                  <div>{String(e.summary ?? "")}</div>
                  <div className="text-xs text-faded mt-0.5">
                    {new Date(String(e.at)).toLocaleString()} · <span className="font-mono">{hash.slice(0, 16)}…</span>
                  </div>
                </div>
              </li>
            );
          })}
        </ol>
      </Card>
    </div>
  );
}

function Row({ k, v }: { k: string; v: string }) {
  return (
    <div className="flex justify-between gap-4">
      <dt className="text-faded">{k}</dt>
      <dd className="text-right font-medium">{v}</dd>
    </div>
  );
}
