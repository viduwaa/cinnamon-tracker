import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { createBrowserRouter, RouterProvider } from "react-router-dom";
import "./index.css";
import { AppLayout } from "./shell";
import { LoginPage } from "./pages/Login";
import { OverviewPage } from "./pages/Overview";
import { UsersPage } from "./pages/Users";
import { BatchesPage } from "./pages/Batches";
import { BatchDetailPage } from "./pages/BatchDetail";
import { AnchorsPage } from "./pages/Anchors";
import { AuditPage } from "./pages/Audit";

const router = createBrowserRouter([
  { path: "/login", element: <LoginPage /> },
  {
    element: <AppLayout />,
    children: [
      { path: "/", element: <OverviewPage /> },
      { path: "/users", element: <UsersPage /> },
      { path: "/batches", element: <BatchesPage /> },
      { path: "/batches/:id", element: <BatchDetailPage /> },
      { path: "/anchors", element: <AnchorsPage /> },
      { path: "/audit", element: <AuditPage /> },
    ],
  },
]);

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <RouterProvider router={router} />
  </StrictMode>,
);
