/* ============================================================
   MaidItQuick Admin — categories.js
   ============================================================ */

import { api } from "./api.js";
import { registerModule, crudPage, activeBadge } from "./app.js";
import { escapeHtml, fmtDate } from "./utils.js";

registerModule("categories", (el) =>
  crudPage(el, {
    title: "Categories",
    subtitle: "Organise services into categories.",
    resource: "/categories",
    permission: { read: "CATEGORIES_READ", write: "CATEGORIES_WRITE" },
    emptyText: "No categories yet.",
    columns: [
      { key: "name", title: "Name", sortable: true, render: (r) => `<strong>${escapeHtml(r.name)}</strong>` },
      { key: "slug", title: "Slug", render: (r) => `<span class="mono muted">${escapeHtml(r.slug)}</span>` },
      {
        key: "description",
        title: "Description",
        render: (r) => `<span class="ellipsis muted" style="display:inline-block;max-width:220px">${escapeHtml(r.description || "—")}</span>`,
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
      { name: "name", label: "Name", type: "text", required: true, max: 120, placeholder: "e.g. Home Cleaning" },
      { name: "description", label: "Description", type: "textarea", max: 500, span2: true },
      { name: "active", label: "Active", type: "checkbox", help: "Visible and bookable", span2: true },
    ],
    toBody: (v) => ({ name: v.name, description: v.description || null, active: v.active }),
  })
);
