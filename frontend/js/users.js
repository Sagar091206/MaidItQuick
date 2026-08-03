/* ============================================================
   MaidItQuick Admin — users.js
   Platform user accounts (search, create, edit, status, delete)
   ============================================================ */

import { api } from "./api.js";
import { registerModule, crudPage, badge, statusSelectOptions } from "./app.js";
import { escapeHtml, fmtDate } from "./utils.js";

const STATUS = ["ACTIVE", "SUSPENDED", "VERIFIED"];

registerModule("users", (el) =>
  crudPage(el, {
    title: "Users",
    subtitle: "Manage platform user accounts.",
    resource: "/users",
    permission: { read: "USERS_READ", write: "USERS_WRITE" },
    emptyText: "No users found. Create your first user account.",
    columns: [
      {
        key: "name",
        title: "User",
        sortable: true,
        render: (r) => `
          <div class="cell-main">
            <span class="cell-avatar">${escapeHtml((r.name || "?")[0]?.toUpperCase() || "?")}</span>
            <div>
              <div>${escapeHtml(r.name)}</div>
              <div class="meta">${escapeHtml(r.email)}</div>
            </div>
          </div>`,
        exportValue: (r) => r.name,
        printValue: (r) => r.name,
      },
      { key: "phone", title: "Phone", sortable: true, render: (r) => escapeHtml(r.phone || "—") },
      { key: "status", title: "Status", sortable: true, render: (r) => badge(r.status) },
      {
        key: "createdAt",
        title: "Created",
        sortable: true,
        align: "right",
        render: (r) => `<span class="muted">${fmtDate(r.createdAt)}</span>`,
        sortValue: (r) => r.createdAt,
      },
    ],
    fields: [
      { name: "name", label: "Full name", type: "text", required: true, max: 160, placeholder: "e.g. Priya Sharma" },
      { name: "email", label: "Email address", type: "email", required: true, max: 255, placeholder: "user@example.com" },
      { name: "phone", label: "Phone", type: "text", max: 40, placeholder: "+91 …", span2: true },
      { name: "status", label: "Status", type: "select", options: statusSelectOptions(STATUS), span2: true },
    ],
    toBody: (v) => ({ name: v.name, email: v.email, phone: v.phone || null, status: v.status || undefined }),
    statusField: {
      key: "status",
      options: statusSelectOptions(STATUS),
      api: (row, status) => api.patch(`/users/${row.id}/status`, { status, reason: "Changed from admin dashboard" }),
    },
  })
);
