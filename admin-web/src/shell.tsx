import { useEffect } from "react";
import { NavLink, Outlet, useNavigate } from "react-router-dom";
import { getToken, setToken } from "./api";

/** Console chrome: bark sidebar + content area. Redirects to /login when tokenless. */
export function AppLayout() {
  const navigate = useNavigate();
  useEffect(() => {
    if (!getToken()) navigate("/login", { replace: true });
  }, [navigate]);

  const nav = [
    { to: "/", label: "Overview" },
    { to: "/users", label: "Users" },
    { to: "/batches", label: "Batches" },
    { to: "/anchors", label: "Anchors" },
    { to: "/audit", label: "Audit Log" },
  ];

  return (
    <div className="flex min-h-screen">
      <aside className="w-56 shrink-0 bg-bark text-paper flex flex-col">
        <div className="px-5 py-6">
          <div className="font-display text-lg font-bold leading-tight">Cinnamon Trace</div>
          <div className="text-xs text-neutral/60 mt-1">
            Oversight Console · Dept. of Cinnamon Development
          </div>
        </div>
        <nav className="flex-1 px-3 space-y-1">
          {nav.map((n) => (
            <NavLink
              key={n.to}
              to={n.to}
              end={n.to === "/"}
              className={({ isActive }) =>
                `block rounded-sm px-3 py-2 text-sm ${
                  isActive ? "bg-primary text-paper" : "text-neutral/80 hover:bg-secondary"
                }`
              }
            >
              {n.label}
            </NavLink>
          ))}
        </nav>
        <button
          onClick={() => {
            setToken(null);
            navigate("/login", { replace: true });
          }}
          className="mx-3 mb-5 rounded-sm px-3 py-2 text-sm text-neutral/80 hover:bg-secondary text-left"
        >
          Sign out
        </button>
      </aside>
      <main className="flex-1 p-6 max-w-[1200px]">
        <Outlet />
      </main>
    </div>
  );
}
