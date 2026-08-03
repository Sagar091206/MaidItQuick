/* ============================================================
   MaidItQuick Admin — settlements.js
   Financial Settlements & Payout Approval.
   - Weekly payout queue auto-generated from completed bookings
   - Single / bulk payout initiation + transaction reference
   - Commission rate configurator (shared platform setting)
   ============================================================ */

import { api, unwrap, errorMessage } from "./api.js";
import {
  registerModule, pageHeader, toast, badge, icon, confirmDialog,
  formModal, exportCsvFile,
} from "./app.js";
import { escapeHtml, fmtDateTime, money } from "./utils.js";
import * as auth from "./auth.js";

const qs = (sel) => document.querySelector(sel);

registerModule("settlements", async (el) => {
  const canWrite = auth.hasPermission("SETTLEMENTS_WRITE");
  let rows = [];
  let commission = null;
  let statusFilter = "";
  let selected = new Set();

  el.innerHTML = pageHeader(
    "Financial Settlements & Payout Approval",
    "Weekly partner payout queue, commission rate and payout history.",
    `
    <button class="btn btn-ghost" id="stl-refresh">${icon("i-refresh")} Refresh</button>
    <button class="btn btn-ghost" id="stl-csv">${icon("i-download")} CSV</button>
    ${canWrite ? `<button class="btn btn-primary" id="stl-bulk" disabled>${icon("i-money")} Initiate payouts</button>` : ""}
    `
  );

  el.innerHTML += `
    <div class="card fade-up" style="margin-bottom:16px">
      <div class="chip-row" id="stl-chips"></div>
    </div>
    <div class="card fade-up" style="margin-bottom:16px">
      <div class="filter-bar" style="padding:16px">
        <div class="field" style="margin:0">
          <label for="stl-status">Payout status</label>
          <select class="select" id="stl-status">
            <option value="">All payouts</option>
            <option value="PENDING">Pending</option>
            <option value="PAID">Paid</option>
          </select>
        </div>
        <div class="filter-actions" style="margin-left:auto">
          <div class="field" style="margin:0">
            <label>Platform commission</label>
            <div style="display:flex;gap:8px;align-items:center">
              <span class="c-value" id="stl-comm" style="font-size:18px">—</span>
              <button class="btn btn-ghost btn-sm" id="stl-edit-comm" ${canWrite ? "" : "disabled"}>${icon("i-edit")} Adjust</button>
            </div>
          </div>
        </div>
      </div>
    </div>
    <div class="card fade-up">
      <div id="stl-table"></div>
    </div>`;

  async function load() {
    try {
      const payload = unwrap(await api.get(`/settlements/queue${statusFilter ? `?status=${statusFilter}` : ""}`));
      rows = payload || [];
    } catch (err) {
      toast(errorMessage(err), "error");
      rows = [];
    }
    try {
      commission = unwrap(await api.get("/settlements/commission"));
    } catch (err) {
      commission = null;
    }
    renderChips();
    renderTable();
  }

  function renderChips() {
    const host = qs("#stl-chips");
    if (!host) return;
    const pending = rows.filter((r) => r.status === "PENDING");
    const paid = rows.filter((r) => r.status === "PAID");
    const sum = (list) => list.reduce((acc, r) => acc + Number(r.amount || 0), 0);
    host.innerHTML = `
      <div class="chip"><span class="c-label">Pending payouts</span><span class="c-value">${pending.length}</span></div>
      <div class="chip"><span class="c-label">Pending amount</span><span class="c-value">${money(sum(pending))}</span></div>
      <div class="chip"><span class="c-label">Paid this week</span><span class="c-value green">${paid.length}</span></div>
      <div class="chip"><span class="c-label">Total paid</span><span class="c-value green">${money(sum(paid))}</span></div>`;
    const commEl = qs("#stl-comm");
    if (commEl) commEl.textContent = commission == null ? "—" : `${commission}%`;
  }

  function renderTable() {
    const body = qs("#stl-table");
    if (!body) return;
    selected = new Set([...selected].filter((id) => rows.some((r) => r.id === id && r.status === "PENDING")));
    const q = rows.map((r) => {
      const sel = selected.has(r.id);
      return `<tr data-id="${r.id}" ${r.status === "PAID" ? 'style="opacity:.7"' : ""}>
        <td>${canWrite && r.status === "PENDING" ? `<label class="checkbox" style="padding:0"><input type="checkbox" data-sel ${sel ? "checked" : ""}></label>` : ""}</td>
        <td><div class="cell-main"><span class="cell-avatar">${icon("i-money")}</span>
          <div><div><strong>Payout #${r.id}</strong></div><div class="meta">${escapeHtml(r.periodLabel || "")}</div></div></div></td>
        <td><div class="cell-main"><span class="cell-avatar">${escapeHtml((r.partner?.name || "?")[0]?.toUpperCase() || "?")}</span>
          <div><div>${escapeHtml(r.partner?.name || "—")}</div><div class="meta">${escapeHtml(r.partner?.phone || "")}</div></div></div></td>
        <td class="text-right"><strong>${money(r.amount)}</strong></td>
        <td>${badge(r.status)}</td>
        <td>${r.transactionRef ? `<span class="mono">${escapeHtml(r.transactionRef)}</span>` : '<span class="muted">—</span>'}</td>
        <td>${r.paidAt ? fmtDateTime(r.paidAt) : '<span class="muted">—</span>'}</td>
        <td class="text-right"><div class="actions">
          ${canWrite && r.status === "PENDING"
            ? `<button class="btn btn-primary btn-sm" data-pay>${icon("i-money")} Initiate</button>
               <button class="btn btn-ghost btn-icon-sm" data-del title="Remove from queue" style="color:var(--danger)"><svg width="15" height="15"><use href="#i-trash"/></svg></button>`
            : ""}
        </div></td>
      </tr>`;
    }).join("");
    if (rows.length === 0) {
      body.innerHTML = `<div class="table-wrap"><table class="table"><thead><tr>
        <th></th><th>Payout</th><th>Partner</th><th class="text-right">Amount</th><th>Status</th><th>Reference</th><th>Paid at</th><th></th>
      </tr></thead></table>
      <div class="table-empty"><div class="icon"><svg width="22" height="22"><use href="#i-box"/></svg></div>No payouts match the current filter.</div></div>`;
      return;
    }
    body.innerHTML = `
      <div class="table-wrap"><table class="table">
        <thead><tr>
          <th style="width:36px"></th><th>Payout</th><th>Partner</th><th class="text-right">Amount</th>
          <th>Status</th><th>Reference</th><th>Paid at</th><th class="text-right">Actions</th>
        </tr></thead>
        <tbody>${q}</tbody></table></div>`;
    syncBulk();
  }

  function syncBulk() {
    const btn = qs("#stl-bulk");
    if (!btn) return;
    btn.disabled = selected.size === 0;
    btn.innerHTML = `${icon("i-money")} Initiate ${selected.size} payout${selected.size === 1 ? "" : "s"}`;
  }

  async function payOne(rec) {
    const ok = await confirmDialog({
      title: `Initiate payout #${rec.id}?`,
      message: `A payout of <b>${money(rec.amount)}</b> will be initiated for <b>${escapeHtml(rec.partner?.name || "")}</b> (period ${escapeHtml(rec.periodLabel || "")}).`,
      confirmLabel: "Initiate payout",
    });
    if (!ok) return;
    try {
      const payload = await api.post(`/settlements/${rec.id}/pay`, {});
      toast(payload?.message || `Payout #${rec.id} initiated`, "success");
      await load();
    } catch (err) {
      toast(errorMessage(err), "error");
    }
  }

  async function removeOne(rec) {
    const ok = await confirmDialog({
      title: `Remove payout #${rec.id}?`,
      message: `This queued payout for <b>${escapeHtml(rec.partner?.name || "")}</b> will be removed. The booking history is not affected.`,
      confirmLabel: "Remove",
      danger: true,
    });
    if (!ok) return;
    try {
      await api.delete(`/settlements/${rec.id}`);
      toast(`Payout #${rec.id} removed`, "success");
      await load();
    } catch (err) {
      toast(errorMessage(err), "error");
    }
  }

  async function bulkPay() {
    const ids = [...selected];
    const ok = await confirmDialog({
      title: `Initiate ${ids.length} payouts?`,
      message: `All ${ids.length} selected pending payouts will be initiated in one batch.`,
      confirmLabel: "Initiate batch",
    });
    if (!ok) return;
    try {
      const payload = await api.post("/settlements/bulk-pay", { ids });
      toast(payload?.message || "Bulk payouts initiated", "success");
      await load();
    } catch (err) {
      toast(errorMessage(err), "error");
    }
  }

  async function editCommission() {
    const res = await formModal({
      title: "Adjust platform commission",
      fields: [
        { name: "commissionPct", label: "Commission percentage", type: "number", required: true, min: 1, max: 100, step: 0.5, placeholder: "e.g. 18" },
      ],
      initial: { commissionPct: commission },
      submitLabel: "Save rate",
      onInit: async (out) => {
        await api.put("/settlements/commission", { commissionPct: Number(out.commissionPct) });
        toast("Commission rate updated", "success");
      },
    });
    if (res) await load();
  }

  function exportCsv() {
    if (rows.length === 0) {
      toast("Nothing to export — no payouts match the current filter", "warning");
      return;
    }
    exportCsvFile("settlement-payouts", [
      { key: "id", title: "Payout ID", exportValue: (r) => r.id },
      { key: "period", title: "Period", exportValue: (r) => r.periodLabel || "" },
      { key: "partner", title: "Partner", exportValue: (r) => r.partner?.name || "" },
      { key: "partnerPhone", title: "Partner Phone", exportValue: (r) => r.partner?.phone || "" },
      { key: "amount", title: "Amount", exportValue: (r) => Number(r.amount || 0).toFixed(2) },
      { key: "status", title: "Status", exportValue: (r) => r.status },
      { key: "txRef", title: "Transaction Ref", exportValue: (r) => r.transactionRef || "" },
      { key: "paidAt", title: "Paid At", exportValue: (r) => r.paidAt || "" },
    ], rows);
    toast(`Exported ${rows.length} payouts to CSV`, "success");
  }

  qs("#stl-refresh").addEventListener("click", load);
  qs("#stl-csv").addEventListener("click", exportCsv);
  qs("#stl-bulk")?.addEventListener("click", bulkPay);
  qs("#stl-edit-comm").addEventListener("click", editCommission);
  qs("#stl-status").addEventListener("change", (e) => {
    statusFilter = e.target.value;
    selected.clear();
    load();
  });
  qs("#stl-table").addEventListener("click", (e) => {
    const tr = e.target.closest("tr[data-id]");
    if (!tr) return;
    const rec = rows.find((r) => r.id === Number(tr.dataset.id));
    if (!rec) return;
    if (e.target.closest("[data-pay]")) payOne(rec);
    else if (e.target.closest("[data-del]")) removeOne(rec);
  });
  qs("#stl-table").addEventListener("change", (e) => {
    if (!e.target.matches("[data-sel]")) return;
    const id = Number(e.target.closest("tr[data-id]").dataset.id);
    if (e.target.checked) selected.add(id);
    else selected.delete(id);
    syncBulk();
  });

  await load();
});
