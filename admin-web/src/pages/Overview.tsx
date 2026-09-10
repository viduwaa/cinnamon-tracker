import { useEffect, useState } from "react";
import { api, type Overview } from "../api";
import { Card, ErrorNote, Kpi, VerdictBadge } from "../ui";

const ROLES = ["FARMER", "COLLECTOR", "PROCESSOR_L1", "PROCESSOR_L2", "EXPORTER"];

export function OverviewPage() {
  const [data, setData] = useState<Overview | null>(null);
  const [error, setError] = useState<unknown>(null);

  useEffect(() => {
    api<Overview>("/v1/admin/overview").then(setData).catch(setError);
  }, []);

  if (error) return <ErrorNote error={error} />;
  if (!data) return <div className="text-faded text-sm">Loading…</div>;

  const maxDay = Math.max(1, ...data.batches_per_day.map((d) => d.count));
  const maxRole = Math.max(1, ...data.activity_by_role.map((r) => r.batches_touched));

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">Overview</h1>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Kpi label="Registered users" value={data.users.total} sub={`${data.users.new_today} new today`} />
        <Kpi label="Batches" value={data.batches.total} sub={`${data.batches.today} created today`} />
        <Kpi label="Volume" value={`${data.batches.weight_kg.toLocaleString()} kg`} sub="cumulative harvest weight" />
        <Kpi
          label="Events awaiting anchor"
          value={data.anchors.events_awaiting_anchor}
          sub={
            data.anchors.last_confirmed_at
              ? `last Bitcoin witness ${new Date(data.anchors.last_confirmed_at).toLocaleDateString()}`
              : "no confirmed anchor yet"
          }
        />
      </div>

      <Card>
        <div className="flex items-center justify-between mb-3">
          <h2 className="font-bold">Ledger integrity</h2>
          <span className="text-xs text-faded">tamper-evidence across all batches</span>
        </div>
        <div className="flex flex-wrap gap-3">
          {(["AUTHENTIC", "PENDING", "TAMPERED"] as const).map((v) => (
            <div key={v} className="flex items-center gap-2 rounded-sm border border-line px-3 py-2">
              <VerdictBadge verdict={v} />
              <span className="font-display text-2xl font-bold">{data.verdicts[v]}</span>
              <span className="text-xs text-faded">batches</span>
            </div>
          ))}
        </div>
      </Card>

      <div className="grid md:grid-cols-2 gap-4">
        <Card>
          <h2 className="font-bold mb-3">Batches created — last 14 days</h2>
          <div className="flex items-end gap-1.5 h-32">
            {data.batches_per_day.map((d) => (
              <div key={d.day} className="flex-1 flex flex-col items-center gap-1" title={`${d.day}: ${d.count}`}>
                <div
                  className="w-full rounded-t-sm bg-primary"
                  style={{ height: `${Math.max(4, (d.count / maxDay) * 100)}%` }}
                />
                <span className="text-[10px] text-faded">{d.day.slice(8)}</span>
              </div>
            ))}
          </div>
        </Card>

        <Card>
          <h2 className="font-bold mb-3">Batches processed per role</h2>
          <div className="space-y-2">
            {ROLES.map((role) => {
              const row = data.activity_by_role.find((r) => r.role === role);
              const touched = row?.batches_touched ?? 0;
              return (
                <div key={role} className="flex items-center gap-3">
                  <span className="w-28 text-xs font-semibold text-bark">{role.replace("_", " ")}</span>
                  <div className="flex-1 h-4 bg-neutral rounded-sm overflow-hidden">
                    <div
                      className="h-full bg-quill"
                      style={{ width: `${(touched / maxRole) * 100}%` }}
                    />
                  </div>
                  <span className="w-20 text-right text-xs text-faded">
                    {touched} · {row?.events ?? 0} ev
                  </span>
                </div>
              );
            })}
          </div>
        </Card>
      </div>

      <Card>
        <h2 className="font-bold mb-3">District volumes</h2>
        {data.districts.length === 0 ? (
          <div className="text-sm text-faded">No farm districts with batches yet.</div>
        ) : (
          <table className="ct w-full">
            <thead>
              <tr>
                <th>District</th>
                <th>Code</th>
                <th className="text-right">Batches</th>
                <th className="text-right">Weight (kg)</th>
              </tr>
            </thead>
            <tbody>
              {data.districts.map((d) => (
                <tr key={d.area_code}>
                  <td>{d.name}</td>
                  <td className="text-faded">{d.area_code}</td>
                  <td className="text-right">{d.batches}</td>
                  <td className="text-right">{d.weight_kg.toLocaleString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>
    </div>
  );
}
