import { useCallback, useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api, type AdminUser } from "../api";
import { Empty, ErrorNote } from "../ui";

const ROLES = ["FARMER", "PROCESSOR_L1", "COLLECTOR", "PROCESSOR_L2", "EXPORTER"];

export function UsersPage() {
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [error, setError] = useState<unknown>(null);
  const [q, setQ] = useState("");
  const [role, setRole] = useState("");
  const [status, setStatus] = useState("");
  const [sort, setSort] = useState("created");
  const [busyId, setBusyId] = useState<string | null>(null);

  const load = useCallback(async () => {
    const params = new URLSearchParams();
    if (q) params.set("q", q);
    if (role) params.set("role", role);
    if (status) params.set("status", status);
    if (sort) params.set("sort", sort);
    try {
      const res = await api<{ users: AdminUser[] }>(`/v1/admin/users?${params}`);
      setUsers(res.users);
      setError(null);
    } catch (err) {
      setError(err);
    }
  }, [q, role, status, sort]);

  useEffect(() => {
    const t = setTimeout(load, 250); // debounce typing
    return () => clearTimeout(t);
  }, [load]);

  async function setSuspended(u: AdminUser, suspended: boolean) {
    if (!window.confirm(suspended ? `Suspend ${u.name}? They will not be able to sign in.` : `Reactivate ${u.name}?`))
      return;
    setBusyId(u.id);
    try {
      await api(`/v1/admin/users/${u.id}/status`, {
        method: "PATCH",
        body: JSON.stringify({ is_active: !suspended }),
      });
      await load();
    } catch (err) {
      setError(err);
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold">Users</h1>

      <div className="flex flex-wrap gap-2 items-center">
        <input
          className="ct w-64"
          placeholder="Search name, mobile, email…"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          aria-label="Search users"
        />
        <select className="ct" value={role} onChange={(e) => setRole(e.target.value)} aria-label="Filter by role">
          <option value="">All roles</option>
          {ROLES.map((r) => (
            <option key={r} value={r}>
              {r.replace("_", " ")}
            </option>
          ))}
        </select>
        <select className="ct" value={status} onChange={(e) => setStatus(e.target.value)} aria-label="Filter by status">
          <option value="">Active + suspended</option>
          <option value="active">Active only</option>
          <option value="suspended">Suspended only</option>
        </select>
        <select className="ct" value={sort} onChange={(e) => setSort(e.target.value)} aria-label="Sort">
          <option value="created">Newest first</option>
          <option value="name">Name A–Z</option>
          <option value="batches">Most batches</option>
        </select>
        <span className="text-xs text-faded ml-auto">{users.length} users</span>
      </div>

      {error ? <ErrorNote error={error} /> : null}

      <div className="bg-paper rounded-md border border-line overflow-x-auto">
        <table className="ct w-full">
          <thead>
            <tr>
              <th>Name</th>
              <th>Mobile</th>
              <th>Roles</th>
              <th className="text-right">Batches</th>
              <th className="text-right">Farms</th>
              <th>Status</th>
              <th>Registered</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {users.map((u) => (
              <tr key={u.id}>
                <td>
                  <Link to={`/batches?user=${u.id}`} className="font-semibold text-primary hover:underline">
                    {u.name}
                  </Link>
                </td>
                <td className="font-mono text-xs">{u.mobile}</td>
                <td>
                  <div className="flex flex-wrap gap-1">
                    {u.roles.map((r) => (
                      <span key={r} className="bg-quill-soft text-bark rounded-sm px-1.5 py-0.5 text-[11px] font-semibold">
                        {r.replace("_", " ")}
                      </span>
                    ))}
                  </div>
                </td>
                <td className="text-right">{u.batches}</td>
                <td className="text-right">{u.farms}</td>
                <td>
                  <span className={`text-xs font-semibold ${u.is_active ? "text-leaf-dark" : "text-clay-dark"}`}>
                    {u.is_active ? "● Active" : "● Suspended"}
                  </span>
                </td>
                <td className="text-xs text-faded">{new Date(u.created_at).toLocaleDateString()}</td>
                <td>
                  <button
                    onClick={() => setSuspended(u, u.is_active)}
                    disabled={busyId === u.id}
                    className={`rounded-sm px-2.5 py-1 text-xs font-semibold ${
                      u.is_active ? "bg-clay-soft text-clay-dark hover:bg-clay hover:text-paper" : "bg-leaf-soft text-leaf-dark hover:bg-leaf hover:text-paper"
                    } disabled:opacity-50`}
                  >
                    {busyId === u.id ? "…" : u.is_active ? "Suspend" : "Reactivate"}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {users.length === 0 && !error && <Empty>No users match these filters.</Empty>}
      </div>
    </div>
  );
}
