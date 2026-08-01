/* ============================================================
   MaidItQuick Admin — returns.js
   Returns & refund-request workflow.
   - Requested / Approved / Rejected / Refunded tabs
   - Create a return (admin-initiated)
   - Approve / Reject with admin note; mark Refunded
   - Search, sort, pagination
   ============================================================ */

import { api, unwrap, errorMessage } from "./api.js";
import * as auth from "./auth.js";
import {
  registerModule, pageHeader, toast, openModal, closeTopModal,
  confirmDialog, badge, formModal, icon, fetchAllPages,
} from "./app.js";
import { escapeHtml, fmtDateTime, money, qs } from "./utils.js";

const TABS = [
  { key: "", label: "All Returns" },
  { key: "REQUESTED", label: "Requested" },
  { key: "APPROVED", label: "Approved" },
  { key: "REJECTED", label: "Rejected" },
  { key: "REFUNDED", label: "Refunded" },
];

registerModule("returns", (el) => {
  const canWrite = auth.hasPermission("PAYMENTS_WRITE");
  const state = { status: "", query: "", page: 0, pageSize: 10, sortKey: null, sortDir: "asc" };
  let rows = [];

  async function load() {
    try {
      rows = await fetchAllPages("/returns", { status: state.status, query: state.query });
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
      const av = sortKey === "customerName" ? (a.customerName || "").toLowerCase() : a[sortKey];
      const bv = sortKey === "customerName" ? (b.customerName || "").toLowerCase() : b[sortKey];
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

  function renderTable() {
    const body = document.getElementById("returns-table");
    if (!body) return;
    const p = paginate(sorted());
    const thead = `
      <th class="sortable" data-sort="id">ID</th>
      <th class="sortable" data-sort="customerName">Customer</th>
      <th class="sortable" data-sort="serviceName">Service</th>
      <th class="sortable" data-sort="requestedAmount">Amount</th>
      <th>Reason</th>
      <th class="sortable" data-sort="status">Status</th>
      <th class="sortable" data-sort="createdAt">Requested</th>
      <th class="text-right">Actions</th>`;
    if (p.items.length === 0) {
      body.innerHTML = `<div class="table-wrap"><table class="table"><thead><tr>${thead}</tr></thead></table>
        <div class="table-empty"><div class="icon"><svg width="22" height="22"><use href="#i-returns"/></svg></div>No returns in this view.</div></div>`;
      return;
    }
    const tbody = p.items.map((r) => `
      <tr data-id="${r.id}">
        <td class="mono">#${r.id}</td>
        <td><div class="cell-main"><span class="cell-avatar">${escapeHtml((r.customerName || "?")[0]?.toUpperCase() || "?")}</span>
          <div><div>${escapeHtml(r.customerName || "—")}</div><div class="meta">Booking #${r.bookingId}</div></div></div></td>
        <td>${escapeHtml(r.serviceName || "—")}</td>
        <td><strong>${money(r.requestedAmount)}</strong></td>
        <td class="muted ellipsis" style="max-width:220px" title="${escapeHtml(r.reason || "")}">${escapeHtml(r.reason || "—")}</td>
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
    const host = document.getElementById("returns-tabs");
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
      ${canWrite && p.status === "REQUESTED" ? `
        <button class="btn btn-danger" data-reject>${icon("i-alert")} Reject</button>
        <button class="btn btn-success" data-approve>${icon("i-check")} Approve</button>` : ""}
      ${canWrite && p.status === "APPROVED" ? `<button class="btn btn-primary" data-refund>${icon("i-returns")} Mark Refunded</button>` : ""}`;
    openModal({
      title: `Return #${p.id} — ${p.customerName || "Unknown"}`,
      body: `
        <div class="kv-grid" style="margin-bottom:14px">
          <div class="kv"><span>Booking</span><strong class="mono">#${p.bookingId}</strong></div>
          <div class="kv"><span>Service</span><strong>${escapeHtml(p.serviceName || "—")}</strong></div>
          <div class="kv"><span>Requested amount</span><strong>${money(p.requestedAmount)}</strong></div>
          <div class="kv"><span>Status</span><strong>${badge(p.status)}</strong></div>
          <div class="kv" style="grid-column:1/-1"><span>Reason</span><strong>${escapeHtml(p.reason || "—")}</strong></div>
          ${p.adminNote ? `<div class="kv" style="grid-column:1/-1"><span>Admin note</span><strong>${escapeHtml(p.adminNote)}</strong></div>` : ""}
          <div class="kv"><span>Requested at</span><strong>${fmtDateTime(p.createdAt)}</strong></div>
          <div class="kv"><span>Decided at</span><strong>${p.decidedAt ? fmtDateTime(p.decidedAt) : "—"}</strong></div>
        </div>`,
      footer,
      size: "lg",
    });
    const overlay = [...document.querySelectorAll(".modal-overlay")].at(-1);
    overlay.querySelector("[data-close]").addEventListener("click", closeTopModal);
    overlay.querySelector("[data-approve]")?.addEventListener("click", () => decide(p, "APPROVED"));
    overlay.querySelector("[data-reject]")?.addEventListener("click", () => decide(p, "REJECTED"));
    overlay.querySelector("[data-refund]")?.addEventListener("click", () => decide(p, "REFUNDED"));
  }

  async function decide(row, status) {
    let note = "";
    if (status !== "REFUNDED") {
      const body = `
        <div class="field">
          <label class="${status === "REJECTED" ? "req" : ""}" for="rt-note">${status === "REJECTED" ? "Rejection reason" : "Admin note"}</label>
          <textarea class="textarea" id="rt-note" rows="3" maxlength="1000" placeholder="${status === "REJECTED" ? "e.g. No evidence of defect provided" : "Optional note"}""></textarea>
          <div class="field-error hidden" id="rt-err"></div>
        </div>`;
      const approved = await new Promise((resolve) => {
        openModal({
          title: `${status === "REJECTED" ? "Reject" : "Approve"} return #${row.id}?`,
          body,
          footer: `<button class="btn btn-ghost" data-close>Cancel</button>
                   <button class="btn ${status === "REJECTED" ? "btn-danger" : "btn-success"}" data-submit>${status === "REJECTED" ? "Reject" : "Approve"}</button>`,
        });
        const ov = [...document.querySelectorAll(".modal-overlay")].at(-1);
        ov.querySelector("[data-close]").addEventListener("click", closeTopModal);
        ov.querySelector("[data-submit]").addEventListener("click", () => {
          const val = ov.querySelector("#rt-note").value.trim();
          if (status === "REJECTED" && !val) {
            ov.querySelector("#rt-err").textContent = "A rejection reason is required.";
            ov.querySelector("#rt-err").classList.remove("hidden");
            return;
          }
          note = val;
          closeTopModal();
          resolve(true);
        });
      });
      if (!approved) return;
    }
    try {
      await api.patch(`/returns/${row.id}/status`, { status, note: note || null });
      toast(`Return #${row.id} ${status.toLowerCase()}`, "success");
      closeTopModal();
      load();
    } catch (err) {
      toast(errorMessage(err), "error");
    }
  }

  async function remove(row) {
    const ok = await confirmDialog({
      title: `Delete return #${row.id}?`,
      message: "This permanently removes the return record.",
      confirmLabel: "Delete",
      danger: true,
    });
    if (!ok) return;
    try {
      await api.delete(`/returns/${row.id}`);
      toast("Return deleted", "success");
      load();
    } catch (err) {
      toast(errorMessage(err), "error");
    }
  }

  function openCreate() {
    formModal({
      title: "Raise a return",
      fields: [
        { name: "bookingId", label: "Booking ID", type: "number", required: true, min: 1 },
        { name: "requestedAmount", label: "Requested refund (₹)", type: "number", required: true, min: 0.01, step: "0.01" },
        { name: "reason", label: "Reason", type: "textarea", required: true, max: 1000, span2: true },
      ],
      submitLabel: "Raise Return",
      onInit: async (values) => {
        await api.post("/returns", {
          bookingId: Number(values.bookingId),
          requestedAmount: Number(values.requestedAmount),
          reason: values.reason,
        });
        toast("Return raised", "success");
        load();
      },
    });
  }

  el.innerHTML = pageHeader(
    "Returns & Refunds",
    "Customer return and refund-request workflow.",
    canWrite ? `<button class="btn btn-primary" id="add-return">${icon("i-plus")} Raise Return</button>` : ""
  );
  el.innerHTML += `
    <div class="card fade-up">
      <div style="display:flex;flex-wrap:wrap;gap:12px;align-items:center;padding:14px 16px 4px">
        <div id="returns-tabs"></div>
        <div class="toolbar-spacer"></div>
        <div class="search-box" style="width:260px">
          <span class="icon"><svg width="16" height="16"><use href="#i-search"/></svg></span>
          <input class="input" type="search" placeholder="Search reason or booking #…" id="returns-search">
        </div>
      </div>
      <div id="returns-table"></div>
    </div>`;

  document.getElementById("add-return")?.addEventListener("click", openCreate);
  let t;
  document.getElementById("returns-search").addEventListener("input", (e) => {
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
