/* ============================================================
   MaidItQuick Admin — services.js
   ============================================================ */

import { api, unwrap } from "./api.js";
import { registerModule, crudPage, activeBadge, fetchAllPages } from "./app.js";
import { escapeHtml, fmtDate, money } from "./utils.js";

async function categoryOptions() {
  try {
    const list = await fetchAllPages("/categories");
    return list.map((c) => [c.id, c.name]);
  } catch {
    return [];
  }
}

registerModule("services", (el) =>
  crudPage(el, {
    title: "Services",
    subtitle: "Manage the services offered on the platform.",
    resource: "/services",
    permission: { read: "SERVICES_READ", write: "SERVICES_WRITE" },
    emptyText: "No services yet.",
    columns: [
      {
        key: "name",
        title: "Service",
        sortable: true,
        render: (r) => `
          <div class="cell-main">
            <span class="cell-avatar">${escapeHtml((r.name || "?")[0]?.toUpperCase() || "?")}</span>
            <div>
              <div><strong>${escapeHtml(r.name)}</strong></div>
              <div class="meta">${escapeHtml(r.category?.name || "Uncategorised")}</div>
            </div>
          </div>`,
        exportValue: (r) => r.name,
        printValue: (r) => r.name,
      },
      { key: "price", title: "Price", sortable: true, render: (r) => `<strong>${money(r.price)}</strong>`, sortValue: (r) => Number(r.price) },
      {
        key: "durationMinutes",
        title: "Duration",
        sortable: true,
        render: (r) => (r.durationMinutes ? `${r.durationMinutes} min` : "—"),
        align: "right",
      },
      { key: "active", title: "Status", sortable: true, render: (r) => activeBadge(r.active) },
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
      { name: "name", label: "Service name", type: "text", required: true, max: 160, placeholder: "e.g. Deep Cleaning" },
      { name: "categoryId", label: "Category", type: "select", options: categoryOptions, required: true },
      { name: "price", label: "Price (₹)", type: "number", required: true, min: 0, step: "0.01" },
      { name: "durationMinutes", label: "Duration (minutes)", type: "number", min: 1, max: 1440 },
      { name: "description", label: "Description", type: "textarea", max: 1000, span2: true },
      { name: "active", label: "Active", type: "checkbox", help: "Available for booking", span2: true },
    ],
    toBody: (v) => ({
      name: v.name,
      description: v.description || null,
      categoryId: v.categoryId ? Number(v.categoryId) : null,
      price: Number(v.price),
      durationMinutes: v.durationMinutes ? Number(v.durationMinutes) : null,
      active: Boolean(v.active),
    }),
  })
);

// Expose for other modules that need service options
export async function serviceOptions() {
  try {
    const list = await fetchAllPages("/services");
    return list.map((s) => [s.id, s.name]);
  } catch {
    return [];
  }
}
