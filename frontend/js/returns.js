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
    const hasRecommendation = Boolean(p.recommendedResolution || p.faultType);
    const recAmount = p.recommendedRefundAmountPaise != null ? (p.recommendedRefundAmountPaise / 100) : p.requestedAmount;
    const footer = `
      <button class="btn btn-ghost" data-close>Close</button>
      ${canWrite && p.status === "REQUESTED" ? `
        <button class="btn btn-danger" data-reject>${icon("i-alert")} Reject</button>
        <button class="btn btn-ghost" data-modify style="border:1px solid var(--border)">${icon("i-edit")} Modify Amount</button>
        <button class="btn btn-success" data-approve>${icon("i-check")} Approve</button>` : ""}
      ${canWrite && p.status === "APPROVED" ? `<button class="btn btn-primary" data-refund>${icon("i-returns")} Mark Refunded</button>` : ""}`;
    openModal({
      title: `Return #${p.id} — ${p.customerName || "Unknown"}`,
      body: `
        <div class="kv-grid" style="margin-bottom:14px">
          <div class="kv"><span>Booking</span><strong class="mono">#${p.bookingId}</strong></div>
          <div class="kv"><span>Customer</span><strong>${escapeHtml(p.customerName || "—")}</strong></div>
          <div class="kv"><span>Partner</span><strong>${escapeHtml(p.partnerName || "Unassigned")}</strong></div>
          <div class="kv"><span>Service</span><strong>${escapeHtml(p.serviceName || "—")}</strong></div>
          <div class="kv"><span>Amount Paid / Requested</span><strong>${money(p.requestedAmount)}</strong></div>
          <div class="kv"><span>Status</span><strong>${badge(p.status)}</strong></div>
          ${p.cancellationStage ? `<div class="kv"><span>Cancellation Stage</span><strong class="mono" style="color:var(--primary)">${escapeHtml(p.cancellationStage)}</strong></div>` : ""}
          ${p.cancellationReason ? `<div class="kv"><span>Cancellation Reason</span><strong>${escapeHtml(p.cancellationReason)}</strong></div>` : ""}
          <div class="kv" style="grid-column:1/-1"><span>Reason</span><strong>${escapeHtml(p.reason || "—")}</strong></div>
          ${p.adminNote ? `<div class="kv" style="grid-column:1/-1"><span>Admin note</span><strong>${escapeHtml(p.adminNote)}</strong></div>` : ""}
          <div class="kv"><span>Requested at</span><strong>${fmtDateTime(p.createdAt)}</strong></div>
          <div class="kv"><span>Decided at</span><strong>${p.decidedAt ? fmtDateTime(p.decidedAt) : "—"}</strong></div>
          ${p.approvedAmount != null ? `<div class="kv"><span>Approved Refund Amount</span><strong style="color:var(--success)">${money(p.approvedAmount)}</strong></div>` : ""}
          ${p.decidedBy ? `<div class="kv"><span>Decided by</span><strong>${escapeHtml(p.decidedBy)}</strong></div>` : ""}
        </div>
        ${hasRecommendation ? `
          <div style="margin-top:14px;padding:12px;background:var(--card,#fff);border:1px solid var(--border,#e2e8f0);border-radius:8px">
            <div style="font-weight:600;font-size:12px;text-transform:uppercase;letter-spacing:0.5px;color:var(--primary);margin-bottom:10px;display:flex;align-items:center;gap:6px">
              ${icon("i-info")} System Recommendation (Advisory)
            </div>
            <div class="kv-grid" style="grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:8px">
              <div class="kv"><span>Fault Type</span><strong style="color:var(--text)">${escapeHtml(p.faultType || "Unclassified")}</strong></div>
              <div class="kv"><span>Severity</span><strong style="text-transform:capitalize">${escapeHtml(p.severity || "—")}</strong></div>
              <div class="kv"><span>Service Delivered</span><strong>${p.serviceDeliveredPercent != null ? p.serviceDeliveredPercent + "%" : "0%"}</strong></div>
              <div class="kv"><span>Recommended Resolution</span><strong style="color:var(--primary)">${escapeHtml(p.recommendedResolution || "—")}</strong></div>
              <div class="kv"><span>Recommended Refund %</span><strong>${p.recommendedRefundPercentage != null ? p.recommendedRefundPercentage + "%" : "—"}</strong></div>
              <div class="kv"><span>Recommended Amount</span><strong>${p.recommendedRefundAmountPaise != null ? money(p.recommendedRefundAmountPaise / 100) : "—"}</strong></div>
              <div class="kv"><span>Evidence Review</span><strong style="color:${p.evidenceRequired ? 'var(--warning,#d97706)' : 'inherit'}">${p.evidenceRequired ? 'Required' : 'Not Required'}</strong></div>
              <div class="kv" style="grid-column:1/-1"><span>Recommendation Reason</span><strong style="font-weight:normal;color:var(--text-muted)">${escapeHtml(p.recommendationReason || "—")}</strong></div>
            </div>
          </div>` : ""}`,
      footer,
      size: "lg",
    });
    const overlay = [...document.querySelectorAll(".modal-overlay")].at(-1);
    overlay.querySelector("[data-close]").addEventListener("click", closeTopModal);
    overlay.querySelector("[data-approve]")?.addEventListener("click", () => decide(p, "APPROVED", recAmount));
    overlay.querySelector("[data-modify]")?.addEventListener("click", () => modifyAndApprove(p));
    overlay.querySelector("[data-reject]")?.addEventListener("click", () => decide(p, "REJECTED"));
    overlay.querySelector("[data-refund]")?.addEventListener("click", () => decide(p, "REFUNDED"));
  }

  async function modifyAndApprove(row) {
    const defaultAmount = row.recommendedRefundAmountPaise != null
        ? (row.recommendedRefundAmountPaise / 100).toFixed(2)
        : Number(row.requestedAmount || 0).toFixed(2);
    const body = `
      <div class="field">
        <label class="req" for="rt-amount">Modified Refund Amount (₹)</label>
        <input class="input" id="rt-amount" type="number" step="0.01" min="0.01" max="${row.requestedAmount}" value="${defaultAmount}" />
        <div class="field-error hidden" id="rt-amount-err"></div>
      </div>
      <div class="field">
        <label class="req" for="rt-modify-note">Admin Override Reason / Note</label>
        <textarea class="textarea" id="rt-modify-note" rows="3" maxlength="1000" placeholder="State reason for overriding the recommendation..."></textarea>
        <div class="field-error hidden" id="rt-note-err"></div>
      </div>`;
    const result = await new Promise((resolve) => {
      openModal({
        title: `Modify & Approve Return #${row.id}`,
        body,
        footer: `<button class="btn btn-ghost" data-close>Cancel</button>
                 <button class="btn btn-success" data-submit>${icon("i-check")} Approve Modified</button>`,
      });
      const ov = [...document.querySelectorAll(".modal-overlay")].at(-1);
      ov.querySelector("[data-close]").addEventListener("click", closeTopModal);
      ov.querySelector("[data-submit]").addEventListener("click", () => {
        const amt = parseFloat(ov.querySelector("#rt-amount").value);
        const note = ov.querySelector("#rt-modify-note").value.trim();
        let valid = true;
        if (isNaN(amt) || amt <= 0) {
          ov.querySelector("#rt-amount-err").textContent = "Enter a valid positive amount.";
          ov.querySelector("#rt-amount-err").classList.remove("hidden");
          valid = false;
        } else {
          ov.querySelector("#rt-amount-err").classList.add("hidden");
        }
        if (!note) {
          ov.querySelector("#rt-note-err").textContent = "An admin override reason is required.";
          ov.querySelector("#rt-note-err").classList.remove("hidden");
          valid = false;
        } else {
          ov.querySelector("#rt-note-err").classList.add("hidden");
        }
        if (!valid) return;
        closeTopModal();
        resolve({ amount: amt, note });
      });
    });
    if (!result) return;
    try {
      await api.patch(`/returns/${row.id}/status`, {
        status: "APPROVED",
        note: result.note,
        approvedAmount: result.amount
      });
      toast(`Return #${row.id} approved with modified amount ₹${result.amount}`, "success");
      closeTopModal();
      load();
    } catch (err) {
      toast(errorMessage(err), "error");
    }
  }

  async function decide(row, status, defaultAmount) {
    let note = "";
    if (status !== "REFUNDED") {
      const recAmtText = defaultAmount != null ? ` for ${money(defaultAmount)}` : "";
      const body = `
        <div class="field">
          <label class="${status === "REJECTED" ? "req" : ""}" for="rt-note">${status === "REJECTED" ? "Rejection reason" : "Admin note (optional)"}</label>
          <textarea class="textarea" id="rt-note" rows="3" maxlength="1000" placeholder="${status === "REJECTED" ? "e.g. No evidence of defect provided" : "Optional note"}"></textarea>
          <div class="field-error hidden" id="rt-err"></div>
        </div>`;
      const approved = await new Promise((resolve) => {
        openModal({
          title: `${status === "REJECTED" ? "Reject" : "Approve"} return #${row.id}${status === "APPROVED" ? recAmtText : ""}?`,
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
      const payload = { status, note: note || null };
      if (status === "APPROVED" && defaultAmount != null) {
        payload.approvedAmount = defaultAmount;
      }
      await api.patch(`/returns/${row.id}/status`, payload);
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
