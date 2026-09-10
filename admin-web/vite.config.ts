import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  plugins: [react(), tailwindcss()],
  // Dev convenience only: in production nginx serves this app on its own
  // domain and reverse-proxies /v1 to the API, so the SPA stays same-origin.
  // API_TARGET lets dev point at a non-default API instance.
  server: {
    proxy: { "/v1": process.env.API_TARGET ?? "http://localhost:3100" },
  },
});
