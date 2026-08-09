/* ============================================================
   MaidItQuick Admin — bookings.js
   ============================================================ */

import { api } from "./api.js";
import { registerModule, crudPage, badge, statusSelectOptions, fetchAllPages, confirmDialog, icon, toast } from "./app.js";
import { escapeHtml, fmtDateTime, money, timeAgo } from "./utils.js";

const STATUS = ["REQUESTED", "SEARCHING", "ASSIGNED", "ACCEPTED", "ON_THE_WAY", "ARRIVED", "IN_PROGRESS", "COMPLETED", "CANCELLED", "EXPIRED"];
const bookingAmount = (row) => Number(row.paymentAmountPaise || 0) / 100;

async function customerOptions() {
  try {
    const list = await fetchAllPages("/customers");
    return list.map((c) => [c.id, c.name]);
  } catch {
    return [];
  }
}

async function serviceOptions() {
  try {
    const list = await fetchAllPages("/services");
    return list.map((s) => [s.id, s.name]);
  } catch {
    return [];
  }
}

async function partnerOptions() {
  try {
    const list = await fetchAllPages("/partners?status=APPROVED");
    return list.map((p) => [p.id, p.name]);
  } catch {
    return [];
  }
}

registerModule("bookings", (el) =>
  crudPage(el, {
    title: "Bookings",
    subtitle: "Track and manage service bookings.",
    resource: "/bookings",
    permission: { read: "BOOKINGS_READ", write: "BOOKINGS_WRITE" },
    emptyText: "No bookings found.",
    columns: [
      {
        key: "customer",
        title: "Customer",
        sortable: true,
        render: (r) => `
          <div class="cell-main">
            <span class="cell-avatar">${escapeHtml((r.customer?.name || "?")[0]?.toUpperCase() || "?")}</span>
            <div>
              <div>${escapeHtml(r.customer?.name || "—")}</div>
              <div class="meta">Booking #${r.id}</div>
            </div>
          </div>`,
        exportValue: (r) => r.customer?.name || "",
        printValue: (r) => r.customer?.name || "",
        sortValue: (r) => r.customer?.name,
      },
      {
        key: "service",
        title: "Service",
        sortable: true,
        render: (r) => escapeHtml(r.service || "—"),
        sortValue: (r) => r.service,
      },
      {
        key: "partner",
        title: "Partner",
        sortable: true,
        render: (r) => (r.worker ? escapeHtml(r.worker.name) : '<span class="muted">Unassigned</span>'),
        sortValue: (r) => r.worker?.name,
      },
      {
        key: "scheduledAt",
        title: "Scheduled",
        sortable: true,
        render: (r) => (r.scheduledFor ? fmtDateTime(r.scheduledFor) : '<span class="muted">—</span>'),
        sortValue: (r) => r.scheduledFor,
      },
      { key: "paymentAmountPaise", title: "Amount", sortable: true, render: (r) => `<strong>${money(bookingAmount(r))}</strong>`, sortValue: bookingAmount },
      { key: "status", title: "Status", sortable: true, render: (r) => badge(r.status) },
      {
        key: "createdAt",
        title: "Created",
        sortable: true,
        align: "right",
        render: (r) => `<span class="muted">${timeAgo(r.createdAt)}</span>`,
        sortValue: (r) => r.createdAt,
      },
    ],
    fields: [
      { name: "customerId", label: "Customer", type: "select", options: customerOptions, required: true },
      { name: "serviceId", label: "Service", type: "select", options: serviceOptions, required: true },
      { name: "partnerId", label: "Partner (assigned)", type: "select", options: partnerOptions },
      { name: "scheduledAt", label: "Scheduled at", type: "datetime-local" },
      { name: "status", label: "Status", type: "select", options: statusSelectOptions(STATUS) },
      { name: "totalAmount", label: "Total amount (₹)", type: "number", required: true, min: 0, step: "0.01", span2: true },
      { name: "latitude", label: "Latitude", type: "number", step: "0.000001" },
      { name: "longitude", label: "Longitude", type: "number", step: "0.000001" },
      { name: "address", label: "Service address", type: "textarea", max: 500, span2: true },
      { name: "notes", label: "Notes", type: "textarea", max: 1000, span2: true },
    ],
    toBody: (v) => ({
      customerId: v.customerId ? Number(v.customerId) : null,
      serviceId: v.serviceId ? Number(v.serviceId) : null,
      partnerId: v.partnerId ? Number(v.partnerId) : null,
      scheduledAt: v.scheduledAt || null,
      status: v.status || undefined,
      totalAmount: Number(v.totalAmount),
      latitude: v.latitude !== "" ? Number(v.latitude) : null,
      longitude: v.longitude !== "" ? Number(v.longitude) : null,
      address: v.address || null,
      notes: v.notes || null,
    }),
    statusField: {
      key: "status",
      options: statusSelectOptions(STATUS),
      api: (row, status) => api.patch(`/bookings/${row.id}/status`, { status }),
    },
    rowActions: (row, canWrite) =>
      canWrite && row.status !== "CANCELLED"
        ? `<button class="btn btn-ghost btn-sm" data-escalate>${icon("i-alert")} Escalate</button>`
        : "",
    onRowAction: async (row, btn) => {
      if (!btn.dataset.escalate) return false;
      const ok = await confirmDialog({
        title: `Escalate booking #${row.id}?`,
        message: "An emergency support notification will be dispatched to the operations team for this booking.",
        confirmLabel: "Escalate",
        danger: true,
      });
      if (!ok) return false;
      await api.post(`/bookings/${row.id}/escalate`);
      toast("Emergency support dispatched", "success");
      return false;
    },
  })
);
