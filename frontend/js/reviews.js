/* ============================================================
   MaidItQuick Admin — reviews.js
   ============================================================ */

import { api } from "./api.js";
import { registerModule, crudPage, badge, statusSelectOptions, fetchAllPages } from "./app.js";
import { escapeHtml, fmtDateTime, stars, timeAgo } from "./utils.js";

const STATUS = ["PENDING", "APPROVED", "REJECTED"];

async function customerOptions() {
  try {
    const list = await fetchAllPages("/customers");
    return list.map((c) => [c.id, c.name]);
  } catch {
    return [];
  }
}

async function bookingOptions() {
  try {
    const list = await fetchAllPages("/bookings");
    return list.map((b) => [b.id, `#${b.id}`]);
  } catch {
    return [];
  }
}

registerModule("reviews", (el) =>
  crudPage(el, {
    title: "Reviews",
    subtitle: "Moderate customer reviews and ratings.",
    resource: "/reviews",
    permission: { read: "REVIEWS_READ", write: "REVIEWS_WRITE" },
    emptyText: "No reviews yet.",
    filters: [{ key: "status", label: "All statuses", options: statusSelectOptions(STATUS) }],
    serverParams: (state) => (state.status ? { status: state.status } : {}),
    columns: [
      {
        key: "customer",
        title: "Customer",
        sortable: true,
        render: (r) => escapeHtml(r.customer?.name || "—"),
        exportValue: (r) => r.customer?.name || "",
        sortValue: (r) => r.customer?.name,
      },
      {
        key: "booking",
        title: "Booking",
        render: (r) => `<span class="mono muted">#${r.booking?.id || "—"}</span>`,
        exportValue: (r) => (r.booking ? `#${r.booking.id}` : ""),
      },
      { key: "rating", title: "Rating", sortable: true, render: (r) => stars(r.rating), sortValue: (r) => Number(r.rating) },
      {
        key: "comment",
        title: "Comment",
        render: (r) => `<span class="ellipsis muted" style="display:inline-block;max-width:240px">${escapeHtml(r.comment || "—")}</span>`,
      },
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
      { name: "bookingId", label: "Booking", type: "select", options: bookingOptions },
      { name: "rating", label: "Rating (1–5)", type: "number", required: true, min: 1, max: 5 },
      { name: "status", label: "Status", type: "select", options: statusSelectOptions(STATUS) },
      { name: "comment", label: "Comment", type: "textarea", max: 1000, span2: true },
    ],
    toBody: (v) => ({
      customerId: v.customerId ? Number(v.customerId) : null,
      bookingId: v.bookingId ? Number(v.bookingId) : null,
      rating: Number(v.rating),
      comment: v.comment || null,
      status: v.status || undefined,
    }),
    statusField: {
      key: "status",
      options: statusSelectOptions(STATUS),
      api: (row, status) => api.patch(`/reviews/${row.id}/status`, { status }),
    },
  })
);
