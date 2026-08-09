/* ============================================================
   MaidItQuick Admin — payments.js
   ============================================================ */

import { api } from "./api.js";
import { registerModule, crudPage, badge, statusSelectOptions, fetchAllPages } from "./app.js";
import { escapeHtml, fmtDateTime, money, timeAgo } from "./utils.js";

const STATUS = ["PENDING", "PAID", "REFUNDED", "FAILED"];
const METHODS = ["CASH", "CARD", "ONLINE", "UPI", "WALLET", "BANK_TRANSFER"];

// Customer payments use paise/reference/completedAt. Older records can have
// a zero amount, so the linked booking is a safe fallback.
const paymentAmount = (row) =>
  Number(row.amountPaise || row.booking?.paymentAmountPaise || 0) / 100;

async function bookingOptions() {
  try {
    const list = await fetchAllPages("/bookings");
    return list.map((b) => [b.id, `#${b.id} · ${b.customer?.name || "—"} · ${b.service || "—"}`]);
  } catch {
    return [];
  }
}

registerModule("payments", (el) =>
  crudPage(el, {
    title: "Payments",
    subtitle: "Track payments across bookings.",
    resource: "/payments",
    permission: { read: "PAYMENTS_READ", write: "PAYMENTS_WRITE" },
    emptyText: "No payments recorded yet.",
    filters: [{ key: "status", label: "All statuses", options: statusSelectOptions(STATUS) }],
    serverParams: (state) => (state.status ? { status: state.status } : {}),
    columns: [
      {
        key: "booking",
        title: "Booking",
        render: (r) => `
          <div class="cell-main">
            <span class="cell-avatar mono" style="font-size:12px">#${r.booking?.id || "?"}</span>
            <div>
              <div>${escapeHtml(r.booking?.customer?.name || "—")}</div>
              <div class="meta">${escapeHtml(r.booking?.service || "—")}</div>
            </div>
          </div>`,
        exportValue: (r) => (r.booking ? `#${r.booking.id}` : ""),
        printValue: (r) => (r.booking ? `#${r.booking.id}` : ""),
      },
      { key: "amount", title: "Amount", sortable: true, render: (r) => `<strong>${money(paymentAmount(r))}</strong>`, sortValue: paymentAmount },
      { key: "method", title: "Method", sortable: true, render: (r) => badge(r.method) },
      { key: "status", title: "Status", sortable: true, render: (r) => badge(r.status) },
      {
        key: "transactionId",
        title: "Transaction ID",
        render: (r) => `<span class="mono muted ellipsis" style="display:inline-block;max-width:150px">${escapeHtml(r.reference || r.transactionId || "—")}</span>`,
      },
      {
        key: "paidAt",
        title: "Paid at",
        sortable: true,
        align: "right",
        render: (r) => (r.completedAt || r.paidAt || r.booking?.paidAt ? fmtDateTime(r.completedAt || r.paidAt || r.booking?.paidAt) : `<span class="muted">—</span>`),
        sortValue: (r) => r.completedAt || r.paidAt || r.booking?.paidAt,
      },
    ],
    fields: [
      { name: "bookingId", label: "Booking", type: "select", options: bookingOptions, required: true },
      { name: "amount", label: "Amount (₹)", type: "number", required: true, min: 0.01, step: "0.01" },
      { name: "method", label: "Method", type: "select", options: statusSelectOptions(METHODS) },
      { name: "status", label: "Status", type: "select", options: statusSelectOptions(STATUS) },
      { name: "transactionId", label: "Transaction ID", type: "text", max: 128, span2: true },
    ],
    toBody: (v) => ({
      bookingId: v.bookingId ? Number(v.bookingId) : null,
      amount: Number(v.amount),
      method: v.method || undefined,
      status: v.status || undefined,
      transactionId: v.transactionId || null,
    }),
    statusField: {
      key: "status",
      options: statusSelectOptions(STATUS),
      api: (row, status) => api.patch(`/payments/${row.id}/status`, { status }),
    },
  })
);
