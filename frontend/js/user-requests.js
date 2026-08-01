/* ============================================================
   MaidItQuick Admin — user-requests.js
   User (customer) support requests workflow.
   - Open / In Progress / Resolved / Closed tabs
   - Create a request (admin-initiated)
   - Status transitions with reply capture
   - Priority badges, search, pagination
   ============================================================ */

import { api, errorMessage } from "./api.js";
import * as auth from "./auth.js";
import {
  registerModule, pageHeader, toast, openModal, closeTopModal,
  confirmDialog, badge, formModal, icon, fetchAllPages,
} from "./app.js";
import { escapeHtml, fmtDateTime, qs } from "./utils.js";

const TABS = [
  { key: "", label: "All Requests" },
  { key: "OPEN", label: "Open" },
  { key: "IN_PROGRESS", label: "In Progress" },
  { key: "RESOLVED", label: "Resolved" },
  { key: "CLOSED", label: "Closed" },
];

const CATEGORIES = {
  SUPPORT: ["Support Ticket", "st-INFO"],
  BOOKING: ["Booking Issue", "st-WARNING"],
  PAYMENT: ["Payment Issue", "st-ERROR"],
  PARTNER: ["Partner Issue", "st-SUSPENDED"],
  ACCOUNT: ["Account Issue", "st-PENDING"],
  FEATURE: ["Feature Request", "st-SUCCESS"],
};

function categoryBadge(cat) {
  const [label, cls] = CATEGORIES[cat] || [cat || "Support Ticket", "st-INFO"];
  return `<span class="badge ${cls}">${escapeHtml(label)}</span>`;
}

registerModule("user-requests", (el) => {
  const canWrite = auth.hasPermission("DISPUTES_WRITE");
  const state = { status: "", category: "", query: "", page: 0, pageSize: 10, sortKey: null, sortDir: "asc" };
  let rows = [];

  async function load() {
    try {
      rows = await fetchAllPages("/support-requests", {
        status: state.status, category: state.category, query: state.query,
      });
    } catch (err) {
      toast(errorMessage(err), "error");
      rows = [];
    }
    renderTable();
  }

  function sorted() {
    const { sortKey, sortDir } = state;
    if (!sortKey) return [...rows];
    const dir = sortDir === "desc" ? -1 : 1;
    return [...rows].sort((a, b) => {
      const av = sortKey === "subject" ? (a.subject || "").toLowerCase() : a[sortKey];
      const bv = sortKey === "subject" ? (b.subject || "").toLowerCase() : b[sortKey];
      const cmp = av === null || av === undefined ? 1 : bv === null || bv === undefined ? -1 : av < bv ? -1 : av > bv ? 1 : 0;
      return cmp * dir;
    });
  }

  function paginate(list) {
    const total = list.length;
    const pages = Math.max(1, Math.ceil(total / state.pageSize));
    if (state.page >= pages) state.page = 0;
    return { items: list.slice(state.page * state.pageSize, (state.page + 1) * state.pageSize), total, pages };
  }

  function priorityBadge(p) {
    const cls = p === "HIGH" ? "st-SUSPENDED" : p === "LOW" ? "st-INFO" : "st-PENDING";
    return `<span class="badge ${cls}">${escapeHtml(p || "MEDIUM")}</span>`;
  }

  function renderTable() {
    const body = document.getElementById("ur-table");
    if (!body) return;
    const p = paginate(sorted());
    const thead = `
      <th class="sortable" data-sort="id">ID</th>
      <th class="sortable" data-sort="subject">Subject</th>
      <th>Customer</th>
      <th>Type</th>
      <th class="sortable" data-sort="priority">Priority</th>
      <th class="sortable" data-sort="status">Status</th>
      <th class="sortable" data-sort="createdAt">Created</th>
      <th class="text-right">Actions</th>`;
    if (p.items.length === 0) {
      body.innerHTML = `<div class="table-wrap"><table class="table"><thead><tr>${thead}</tr></thead></table>
        <div class="table-empty"><div class="icon"><svg width="22" height="22"><use href="#i-request"/></svg></div>No support requests in this view.</div></div>`;
      return;
    }
    const tbody = p.items.map((r) => `
      <tr data-id="${r.id}">
        <td class="mono">#${r.id}</td>
        <td><div class="cell-main"><div><div>${escapeHtml(r.subject)}</div><div class="meta ellipsis" style="max-width:260px">${escapeHtml(r.message || "")}</div></div></div></td>
        <td>${escapeHtml(r.customerName || "—")}</td>
        <td>${categoryBadge(r.category)}</td>
        <td>${priorityBadge(r.priority)}</td>
        <td>${badge(r.status)}</td>
        <td class="muted" style="white-space:nowrap">${fmtDateTime(r.createdAt)}</td>
        <td class="text-right"><div class="actions">
          <button class="btn btn-primary btn-sm" data-view>${icon("i-eye")} View</button>
          ${canWrite ? `<button class="btn btn-ghost btn-icon-sm" data-del title="Delete" style="color:var(--danger)"><svg width="15" height="15"><use href="#i-trash"/></svg></button>` : ""}
        </div></td></tr>`).join("");
    const pageBtns = [];
    for (let i = Math.max(0, state.page - 2); i < p.pages && i <= state.page + 2; i++) {
      pageBtns.push(`<button class="page-btn ${i === state.page ? "active" : ""}" data-gopage="${i}">${i + 1}</button>`);
    }
    body.innerHTML = `
      <div class="table-wrap"><table class="table">
        <thead><tr>${thead}</tr></thead>
        <tbody>${tbody}</tbody></table></div>
      <div class="pager">
        <div class="pager-info">Showing ${p.total === 0 ? 0 : state.page * state.pageSize + 1}–${Math.min(p.total, (state.page + 1) * state.pageSize)} of ${p.total} records</div>
        <div class="pager-pages">
          <button class="page-btn" data-gopage="${state.page - 1}" ${state.page === 0 ? "disabled" : ""}>‹</button>
          ${pageBtns.join("")}
          <button class="page-btn" data-gopage="${state.page + 1}" ${state.page >= p.pages - 1 ? "disabled" : ""}>›</button>
        </div>
        <div class="page-size"><span>Rows</span>
          <select class="select" data-pagesize>
            ${[10, 20, 50, 100].map((s) => `<option value="${s}" ${s === state.pageSize ? "selected" : ""}>${s}</option>`).join("")}
          </select></div>
      </div>`;
  }

  function renderTabs() {
    const host = document.getElementById("ur-tabs");
    if (!host) return;
    host.innerHTML = `<div class="seg-tabs">
      ${TABS.map((t) => `
        <button class="${state.status === t.key ? "active" : ""}" data-status="${t.key}">
          ${escapeHtml(t.label)}
        </button>`).join("")}
    </div>`;
    host.querySelectorAll("button").forEach((btn) => {
      btn.addEventListener("click", () => {
        state.status = btn.dataset.status;
        state.page = 0;
        renderTabs();
        load();
      });
    });
  }

  function openDetails(row) {
    const p = row;
    const footer = `
      <button class="btn btn-ghost" data-close>Close</button>
      ${canWrite && (p.status === "RESOLVED" || p.status === "CLOSED") ? `<button class="btn btn-ghost" data-reopen>Reopen</button>` : ""}
      ${canWrite && p.status === "OPEN" ? `<button class="btn btn-primary" data-next="IN_PROGRESS">Mark in progress</button>` : ""}
      ${canWrite && (p.status === "OPEN" || p.status === "IN_PROGRESS") ? `<button class="btn btn-success" data-next="RESOLVED">Resolve</button>` : ""}
      ${canWrite && p.status === "IN_PROGRESS" ? `<button class="btn btn-ghost" data-next="CLOSED">Close</button>` : ""}`;
    openModal({
      title: `Request #${p.id} — ${p.subject}`,
      body: `
        <div class="kv-grid" style="margin-bottom:14px">
          <div class="kv"><span>Customer</span><strong>${escapeHtml(p.customerName || "—")}</strong></div>
          <div class="kv"><span>Type</span><strong>${categoryBadge(p.category)}</strong></div>
          <div class="kv"><span>Priority</span><strong>${priorityBadge(p.priority)}</strong></div>
          <div class="kv"><span>Status</span><strong>${badge(p.status)}</strong></div>
          <div class="kv"><span>Created</span><strong>${fmtDateTime(p.createdAt)}</strong></div>
          <div class="kv" style="grid-column:1/-1"><span>Message</span><strong>${escapeHtml(p.message || "—")}</strong></div>
          ${p.adminReply ? `<div class="kv" style="grid-column:1/-1"><span>Admin reply</span><strong>${escapeHtml(p.adminReply)}</strong></div>` : ""}
        </div>`,
      footer,
      size: "lg",
    });
    const overlay = [...document.querySelectorAll(".modal-overlay")].at(-1);
    overlay.querySelector("[data-close]").addEventListener("click", closeTopModal);
    overlay.querySelectorAll("[data-next]").forEach((btn) => {
      btn.addEventListener("click", () => transition(p, btn.dataset.next));
    });
    overlay.querySelector("[data-reopen]")?.addEventListener("click", () => transition(p, "OPEN"));
  }

  async function transition(row, status) {
    if (status === "REOPEN") status = "OPEN";
    let reply = null;
    if (status === "RESOLVED" || status === "CLOSED") {
      const body = `
        <div class="field">
          <label for="ur-reply">Reply to customer (optional)</label>
          <textarea class="textarea" id="ur-reply" rows="3" maxlength="2000" placeholder="What was the outcome?"></textarea>
        </div>`;
      const ok = await new Promise((resolve) => {
        openModal({
          title: `${status === "RESOLVED" ? "Resolve" : "Close"} request #${row.id}?`,
          body,
          footer: `<button class="btn btn-ghost" data-close>Cancel</button>
                   <button class="btn btn-primary" data-submit>${status === "RESOLVED" ? "Resolve" : "Close"}</button>`,
        });
        const ov = [...document.querySelectorAll(".modal-overlay")].at(-1);
        ov.querySelector("[data-close]").addEventListener("click", closeTopModal);
        ov.querySelector("[data-submit]").addEventListener("click", () => {
          reply = ov.querySelector("#ur-reply").value.trim() || null;
          closeTopModal();
          resolve(true);
        });
      });
      if (!ok) return;
    }
    try {
      await api.patch(`/support-requests/${row.id}/status`, { status, reply });
      toast(`Request #${row.id} → ${status.replaceAll("_", " ")}`, "success");
      closeTopModal();
      load();
    } catch (err) {
      toast(errorMessage(err), "error");
    }
  }

  async function remove(row) {
    const ok = await confirmDialog({
      title: `Delete request #${row.id}?`,
      message: "This permanently removes the support request.",
      confirmLabel: "Delete",
      danger: true,
    });
    if (!ok) return;
    try {
      await api.delete(`/support-requests/${row.id}`);
      toast("Request deleted", "success");
      load();
    } catch (err) {
      toast(errorMessage(err), "error");
    }
  }

  function openCreate() {
    formModal({
      title: "Log a user request",
      fields: [
        { name: "customerName", label: "Customer name", type: "text", max: 160 },
        { name: "subject", label: "Subject", type: "text", required: true, max: 200 },
        { name: "message", label: "Message", type: "textarea", required: true, max: 2000, span2: true },
        { name: "priority", label: "Priority", type: "select", options: [["LOW", "Low"], ["MEDIUM", "Medium"], ["HIGH", "High"]], span2: true },
        { name: "category", label: "Issue type", type: "select", options: [["SUPPORT", "Support Ticket"], ["BOOKING", "Booking Issue"], ["PAYMENT", "Payment Issue"], ["PARTNER", "Partner Issue"], ["ACCOUNT", "Account Issue"], ["FEATURE", "Feature Request"]], span2: true },
      ],
      submitLabel: "Log Request",
      onInit: async (values) => {
        await api.post("/support-requests", {
          customerName: values.customerName || null,
          subject: values.subject,
          message: values.message,
          priority: values.priority || "MEDIUM",
          category: values.category || "SUPPORT",
        });
        toast("Support request logged", "success");
        load();
      },
    });
  }

  el.innerHTML = pageHeader(
    "User Requests",
    "Support requests raised by customers on the app.",
    canWrite ? `<button class="btn btn-primary" id="add-ur">${icon("i-plus")} Log Request</button>` : ""
  );
  el.innerHTML += `
    <div class="card fade-up">
      <div style="display:flex;flex-wrap:wrap;gap:12px;align-items:center;padding:14px 16px 4px">
        <div id="ur-tabs"></div>
        <div class="toolbar-spacer"></div>
        <select class="select" id="ur-category" style="width:190px">
          <option value="">All types</option>
          ${Object.entries(CATEGORIES).map(([k, [label]]) => `<option value="${k}">${escapeHtml(label)}</option>`).join("")}
        </select>
        <div class="search-box" style="width:260px">
          <span class="icon"><svg width="16" height="16"><use href="#i-search"/></svg></span>
          <input class="input" type="search" placeholder="Search subject, message, customer…" id="ur-search">
        </div>
      </div>
      <div id="ur-table"></div>
    </div>`;

  document.getElementById("add-ur")?.addEventListener("click", openCreate);
  document.getElementById("ur-category").addEventListener("change", (e) => {
    state.category = e.target.value;
    state.page = 0;
    load();
  });
  let t;
  document.getElementById("ur-search").addEventListener("input", (e) => {
    clearTimeout(t);
    t = setTimeout(() => {
      state.query = e.target.value.trim();
      state.page = 0;
      load();
    }, 280);
  });
  const card = el.querySelector(".card");
  card.addEventListener("click", (e) => {
    if (e.target.closest("th[data-sort]")) {
      const key = e.target.closest("th").dataset.sort;
      if (state.sortKey === key) state.sortDir = state.sortDir === "asc" ? "desc" : "asc";
      else { state.sortKey = key; state.sortDir = "asc"; }
      state.page = 0;
      renderTable();
      return;
    }
    if (e.target.closest("[data-gopage]")) {
      const p = Number(e.target.closest("[data-gopage]").dataset.gopage);
      const max = paginate(sorted()).pages - 1;
      if (p >= 0 && p <= max) { state.page = p; renderTable(); }
      return;
    }
    if (e.target.closest("[data-pagesize]")) {
      state.pageSize = Number(e.target.closest("[data-pagesize]").value);
      state.page = 0;
      renderTable();
      return;
    }
    const tr = e.target.closest("tr[data-id]");
    if (!tr) return;
    const row = rows.find((r) => r.id === Number(tr.dataset.id));
    if (!row) return;
    if (e.target.closest("[data-view]")) openDetails(row);
    else if (e.target.closest("[data-del]")) remove(row);
  });

  renderTabs();
  load();
});
