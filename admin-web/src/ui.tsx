import type { ReactNode } from "react";

/** Verdict badge — THE semantic component. Colors are compliance signals, fixed by DESIGN.md. */
export function VerdictBadge({ verdict }: { verdict: string }) {
  const styles: Record<string, string> = {
    AUTHENTIC: "bg-leaf-soft text-leaf-dark",
    PENDING: "bg-quill-soft text-[#8A5A10]",
    TAMPERED: "bg-clay-soft text-clay-dark",
  };
  return (
    <span className={`inline-block rounded-sm px-2 py-0.5 text-xs font-semibold ${styles[verdict] ?? "bg-neutral text-faded"}`}>
      {verdict}
    </span>
  );
}

export function Card({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <div className={`bg-paper rounded-md border border-line p-4 ${className}`}>{children}</div>;
}

export function Kpi({ label, value, sub }: { label: string; value: ReactNode; sub?: string }) {
  return (
    <Card>
      <div className="text-xs font-semibold uppercase tracking-wide text-faded">{label}</div>
      <div className="font-display text-3xl font-bold text-ink mt-1">{value}</div>
      {sub && <div className="text-xs text-faded mt-1">{sub}</div>}
    </Card>
  );
}

export function Th({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <th className={className}>{children}</th>;
}

export function Empty({ children }: { children: ReactNode }) {
  return <div className="text-sm text-faded py-8 text-center">{children}</div>;
}

export function ErrorNote({ error }: { error: unknown }) {
  return (
    <div className="bg-clay-soft text-clay-dark rounded-sm px-3 py-2 text-sm">
      {error instanceof Error ? error.message : "Something went wrong"}
    </div>
  );
}
