/* ============================================================
   MaidItQuick Admin — customers.js
   Customer lifecycle management:
   - CRUD (create / edit)
   - Suspend / activate via status dropdown
   - Soft delete + restore (deleted view)
   - Search, status filter, CSV + print export
   ============================================================ */

import { api, errorMessage } from "./api.js";
import { registerModule, crudPage, badge, statusSelectOptions, toast, confirmDialog } from "./app.js";
import { escapeHtml, fmtDate } from "./utils.js";

const STATUS = ["ACTIVE", "SUSPENDED"];

registerModule("customers", (el) =>
  crudPage(el, {
    title: "Customers",
    subtitle: "Manage customers of the MaidItQuick app.",
    resource: "/customers",
    permission: { read: "CUSTOMERS_READ", write: "CUSTOMERS_WRITE" },
    emptyText: "No customers found.",
    serverParams: (s) => ({ deleted: s.deleted || "" }),
    clientFilter: (r, s) => (!s.status || r.status === s.status),
    filters: [
      {
        key: "status",
        label: "All statuses",
        options: STATUS.map((v) => ({ value: v, label: v })),
      },
      {
        key: "deleted",
        label: "Active customers",
        options: [{ value: "true", label: "Deleted customers" }],
      },
    ],
    columns: [
      {
        key: "name",
        title: "Customer",
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
      {
        key: "address",
        title: "Address",
        render: (r) => `<span class="ellipsis muted" style="display:inline-block;max-width:180px">${escapeHtml(r.address || "—")}</span>`,
      },
      {
        key: "status",
        title: "Status",
        sortable: true,
        render: (r) =>
          r.deletedAt
            ? `<span class="badge st-SOFT_DELETED">Deleted</span>`
            : badge(r.status),
      },
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
      { name: "name", label: "Full name", type: "text", required: true, max: 160, placeholder: "e.g. Rohan Verma" },
      { name: "email", label: "Email address", type: "email", required: true, max: 255, placeholder: "customer@example.com" },
      { name: "phone", label: "Phone", type: "text", max: 40, placeholder: "+91 …" },
      { name: "address", label: "Address", type: "textarea", max: 500, placeholder: "Full address", span2: true },
      { name: "status", label: "Status", type: "select", options: statusSelectOptions(STATUS), span2: true },
    ],
    toBody: (v) => ({
      name: v.name,
      email: v.email,
      phone: v.phone || null,
      address: v.address || null,
      status: v.status || undefined,
    }),
    statusField: {
      key: "status",
      options: statusSelectOptions(STATUS),
      api: (row, status) => api.patch(`/customers/${row.id}/status`, { status }),
    },
    deleteTitle: (row) => `Delete customer ${row.name}?`,
    deleteMessage: "The customer will be hidden from the main list (soft delete). Their bookings and history stay intact. You can restore them anytime from the deleted view.",
    deleteConfirmLabel: "Soft delete",
    rowActions: (row, canWrite) => {
      if (!canWrite || !row.deletedAt) return "";
      return `<button class="btn btn-ghost btn-icon-sm" data-restore title="Restore customer"><svg width="15" height="15"><use href="#i-restore"/></svg></button>`;
    },
    onRowAction: (row, btn) => {
      if (!btn?.closest("[data-restore]")) return false;
      return confirmDialog({
        title: `Restore customer ${row.name}?`,
        message: "The customer will become visible and active again in the main list.",
        confirmLabel: "Restore",
      }).then(async (ok) => {
        if (!ok) return false;
        try {
          await api.post(`/customers/${row.id}/restore`);
          toast(`Customer ${row.name} restored`, "success");
          return true;
        } catch (err) {
          toast(errorMessage(err), "error");
          return false;
        }
      });
    },
  })
);
