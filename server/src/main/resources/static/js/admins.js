/* ============================================================
   MaidItQuick Admin — admins.js
   Manage administrator accounts (ADMINS_MANAGE permission)
   ============================================================ */

import { api } from "./api.js";
import { registerModule, crudPage, badge, fetchAllPages } from "./app.js";
import { escapeHtml, fmtDateTime } from "./utils.js";
import * as auth from "./auth.js";

async function roleOptions() {
  try {
    const list = await fetchAllPages("/roles");
    return list.map((r) => [r.id, r.name]);
  } catch {
    return [];
  }
}

registerModule("admins", (el) =>
  crudPage(el, {
    title: "Admins",
    subtitle: "Manage administrator accounts and their roles.",
    resource: "/admins",
    permission: { read: "ADMINS_MANAGE", write: "ADMINS_MANAGE" },
    emptyText: "No administrators found.",
    columns: [
      {
        key: "displayName",
        title: "Administrator",
        sortable: true,
        render: (r) => `
          <div class="cell-main">
            <span class="cell-avatar">${escapeHtml((r.displayName || "?")[0]?.toUpperCase() || "?")}</span>
            <div>
              <div><strong>${escapeHtml(r.displayName)}</strong>${auth.getProfile()?.id === r.id ? ' <span class="badge st-INFO">You</span>' : ""}</div>
              <div class="meta">${escapeHtml(r.email)}</div>
            </div>
          </div>`,
        exportValue: (r) => r.displayName,
        printValue: (r) => r.displayName,
      },
      {
        key: "role",
        title: "Role",
        sortable: true,
        render: (r) => badge(r.role?.code, r.role?.name),
        exportValue: (r) => r.role?.code || "",
        sortValue: (r) => r.role?.code,
      },
      {
        key: "enabled",
        title: "Status",
        sortable: true,
        render: (r) =>
          r.enabled
            ? '<span class="badge st-ACTIVE"><span class="dot"></span>Enabled</span>'
            : '<span class="badge st-SUSPENDED"><span class="dot"></span>Disabled</span>',
      },
      {
        key: "lockedUntil",
        title: "Lock",
        render: (r) =>
          r.lockedUntil ? `<span class="badge st-WARNING"><span class="dot"></span>${fmtDateTime(r.lockedUntil)}</span>` : '<span class="muted">—</span>',
      },
      {
        key: "failedAttempts",
        title: "Failures",
        sortable: true,
        align: "right",
        render: (r) => `<span class="muted">${r.failedAttempts}</span>`,
      },
    ],
    fields: [
      { name: "displayName", label: "Full name", type: "text", required: true, max: 160, placeholder: "e.g. Ankit Bharati" },
      { name: "email", label: "Email address", type: "email", required: true, max: 255, placeholder: "admin@maiditquick.com" },
      { name: "roleId", label: "Role", type: "select", options: roleOptions, required: true },
      { name: "enabled", label: "Enabled", type: "checkbox", help: "Account is active", span2: true },
      { name: "password", label: "Password", type: "text", min: 12, max: 128, span2: true, placeholder: "Min. 12 characters · required on create, optional on edit" },
    ],
    toBody: (v, row) => {
      const body = { displayName: v.displayName, roleId: v.roleId ? Number(v.roleId) : null };
      if (!row) body.email = v.email;
      if (!row) body.password = v.password;
      if (row && v.password) body.password = v.password;
      if (v.enabled !== undefined) body.enabled = Boolean(v.enabled);
      return body;
    },
    statusField: {
      key: "enabled",
      current: (r) => (r.enabled ? "true" : "false"),
      options: [
        ["true", "Enabled"],
        ["false", "Disabled"],
      ],
      api: (row, status) => api.patch(`/admins/${row.id}/status`, { enabled: status === "true" }),
    },
  })
);
