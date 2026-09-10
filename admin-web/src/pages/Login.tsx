import { FormEvent, useState } from "react";
import { useNavigate } from "react-router-dom";
import { api, setToken } from "../api";

export function LoginPage() {
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const res = await api<{ token: string }>("/v1/admin/auth/login", {
        method: "POST",
        body: JSON.stringify({ email, password }),
      });
      setToken(res.token);
      navigate("/", { replace: true });
    } catch (err) {
      setError(err instanceof Error ? err.message : "Login failed");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center p-6">
      <form onSubmit={submit} className="w-full max-w-sm bg-paper rounded-lg border border-line p-8">
        <div className="font-display text-2xl font-bold text-bark">Cinnamon Trace</div>
        <div className="text-sm text-faded mt-1 mb-6">Oversight Console — staff sign-in</div>

        <label className="block text-sm font-semibold mb-1" htmlFor="email">
          Email
        </label>
        <input
          id="email"
          type="email"
          required
          autoComplete="username"
          className="ct w-full mb-4"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
        />

        <label className="block text-sm font-semibold mb-1" htmlFor="password">
          Password
        </label>
        <input
          id="password"
          type="password"
          required
          autoComplete="current-password"
          className="ct w-full mb-5"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />

        {error && <div className="bg-clay-soft text-clay-dark rounded-sm px-3 py-2 text-sm mb-4">{error}</div>}

        <button
          type="submit"
          disabled={busy}
          className="w-full rounded-sm bg-primary hover:bg-secondary text-paper font-semibold py-2.5 disabled:opacity-50"
        >
          {busy ? "Signing in…" : "Sign in"}
        </button>
      </form>
    </div>
  );
}
