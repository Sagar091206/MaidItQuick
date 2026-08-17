/* ============================================================
   MaidItQuick Admin — escalations.js
   Escalation & Manual Booking Override.
   - Support disputes: queue, log uploads, resolution
   - Manual override: cancel / reassign / refund active bookings
     with nearby-partner picker for reassignment
   ============================================================ */

import { api, unwrap, errorMessage, pageOf } from "./api.js";
import {
  registerModule, pageHeader, toast, badge, icon, confirmDialog,
  formModal, openModal, closeTopModal,
} from "./app.js";
import { escapeHtml, fmtDateTime, money } from "./utils.js";
import * as auth from "./auth.js";

const qs = (sel) => document.querySelector(sel);

registerModule("escalations", async (el) => {
  const canOverride = auth.hasPermission("OVERRIDES_WRITE");
  const canDisputeWrite = auth.hasPermission("DISPUTES_WRITE");
  let disputes = [];
  let statusFilter = "";

  el.innerHTML = pageHeader(
    "Escalation & Manual Booking Override",
    "Support dispute queue and manual interventions on live bookings.",
    `<button class="btn btn-ghost" id="esc-refresh">${icon("i-refresh")} Refresh</button>`
  );

  el.innerHTML += `
    <div class="seg-tabs" id="esc-tabs" style="margin-bottom:16px">
      <button class="active" data-tab="disputes">${icon("i-alert")} Support Disputes</button>
      <button data-tab="override">${icon("i-edit")} Manual Override</button>
    </div>
    <div class="tab-panel" data-panel="disputes">
      <div class="card fade-up" style="margin-bottom:16px">
        <div class="filter-bar" style="padding:16px">
          <div class="field" style="margin:0">
            <label for="esc-status">Dispute status</label>
            <select class="select" id="esc-status">
              <option value="">All disputes</option>
              <option value="OPEN">Open</option>
              <option value="RESOLVED">Resolved</option>
            </select>
          </div>
          <div class="filter-actions" style="margin-left:auto">
            ${canDisputeWrite ? `<button class="btn btn-primary" id="esc-new">${icon("i-plus")} Record dispute</button>` : ""}
          </div>
        </div>
      </div>
      <div class="card fade-up">
        <div id="esc-disputes"></div>
      </div>
    </div>
    <div class="tab-panel hidden" data-panel="override">
      <div class="card fade-up" style="margin-bottom:16px">
        <div class="filter-bar" style="padding:16px">
          <div class="field" style="margin:0">
            <label for="esc-bid">Booking ID</label>
            <input class="input" id="esc-bid" type="number" min="1" placeholder="e.g. 42" style="max-width:180px">
          </div>
          <div class="filter-actions" style="margin-left:auto">
            <button class="btn btn-primary" id="esc-lookup">${icon("i-search")} Load booking</button>
          </div>
        </div>
      </div>
      <div class="card fade-up">
        <div id="esc-booking"><div class="table-empty"><div class="icon"><svg width="22" height="22"><use href="#i-box"/></svg></div>Enter a booking ID to inspect it and apply manual interventions.</div></div>
      </div>
    </div>`;

  /* ---------------- disputes ---------------- */

  async function loadDisputes() {
    try {
      const payload = pageOf(unwrap(await api.get(`/overrides/disputes?page=0&size=100${statusFilter ? `&status=${statusFilter}` : ""}`)));
      disputes = payload.items;
    } catch (err) {
      toast(errorMessage(err), "error");
      disputes = [];
    }
    renderDisputes();
  }

  function renderDisputes() {
    const body = qs("#esc-disputes");
    if (!body) return;
    if (disputes.length === 0) {
      body.innerHTML = `<div class="table-wrap"><table class="table"><thead><tr>
        <th>ID</th><th>Booking</th><th>Reporter</th><th>Subject</th><th>Status</th><th>Created</th><th>Log</th><th class="text-right">Actions</th>
      </tr></thead></table>
      <div class="table-empty"><div class="icon"><svg width="22" height="22"><use href="#i-box"/></svg></div>No disputes match the current filter.</div></div>`;
      return;
    }
    body.innerHTML = `
      <div class="table-wrap"><table class="table">
        <thead><tr>
          <th>ID</th><th>Booking</th><th>Reporter</th><th>Subject</th><th>Status</th><th>Created</th><th>Log</th><th class="text-right">Actions</th>
        </tr></thead>
        <tbody>${disputes.map((d) => `
          <tr data-id="${d.id}">
            <td><span class="mono">#${d.id}</span></td>
            <td>${d.booking ? `<strong>#${d.booking.id}</strong><div class="meta">${escapeHtml(d.booking.customer?.name || "")}</div>` : '<span class="muted">—</span>'}</td>
            <td>${badge(d.reporterType)}</td>
            <td><div><strong>${escapeHtml(d.subject || "")}</strong></div>
              <div class="meta">${escapeHtml((d.description || "").slice(0, 90))}${(d.description || "").length > 90 ? "…" : ""}</div></td>
            <td>${badge(d.status)}</td>
            <td>${fmtDateTime(d.createdAt)}</td>
            <td>${d.logPath ? `<a href="${escapeHtml(d.logPath)}" target="_blank" download>view</a>` : '<span class="muted">—</span>'}</td>
            <td class="text-right"><div class="actions">
              <button class="btn btn-ghost btn-icon-sm" data-view title="View details"><svg width="15" height="15"><use href="#i-eye"/></svg></button>
              ${canDisputeWrite ? `
                <label class="btn btn-ghost btn-icon-sm" title="Upload call log" style="cursor:pointer">
                  <svg width="15" height="15"><use href="#i-upload"/></svg><input type="file" data-log hidden>
                </label>` : ""}
              ${canDisputeWrite && d.status !== "RESOLVED" ? `<button class="btn btn-primary btn-sm" data-resolve>${icon("i-check")} Resolve</button>` : ""}
            </div></td>
          </tr>`).join("")}
        </tbody></table></div>`;
  }

  function viewDispute(d) {
    openModal({
      title: `Dispute #${d.id}`,
      size: "lg",
      body: `
        <div class="grid-2" style="display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-bottom:12px">
          <div><label class="muted" style="font-size:12px">Status</label><div>${badge(d.status)}</div></div>
          <div><label class="muted" style="font-size:12px">Reporter</label><div>${badge(d.reporterType)}</div></div>
        </div>
        <p><strong>${escapeHtml(d.subject || "")}</strong></p>
        <p class="muted">${escapeHtml(d.description || "")}</p>
        ${d.booking ? `<div class="muted" style="margin-top:8px">Booking #${d.booking.id} — ${escapeHtml(d.booking.address || "")} — ${money(d.booking.totalAmount)}</div>` : ""}
        ${d.logPath ? `<div style="margin-top:10px"><a href="${escapeHtml(d.logPath)}" target="_blank" download>Download call log</a></div>` : ""}
        ${d.resolution ? `<div class="state-box" style="margin-top:12px;padding:12px"><strong>Resolution:</strong> ${escapeHtml(d.resolution)}</div>` : ""}`,
      footer: `<button class="btn btn-ghost" data-close>Close</button>`,
    });
    const overlay = [...document.querySelectorAll(".modal-overlay")].at(-1);
    overlay.querySelector("[data-close]").addEventListener("click", closeTopModal);
  }

  async function uploadLog(d, file) {
    try {
      const fd = new FormData();
      fd.append("log", file);
      const payload = await api.upload(`/overrides/disputes/${d.id}/logs`, fd);
      toast(payload?.message || "Call log uploaded", "success");
      await loadDisputes();
    } catch (err) {
      toast(errorMessage(err), "error");
    }
  }

  async function resolveDispute(d) {
    const res = await formModal({
      title: `Resolve dispute #${d.id}`,
      fields: [
        { name: "resolution", label: "Resolution", type: "textarea", required: true, max: 2000, placeholder: "What action was taken (refund, payout released, etc.)" },
      ],
      submitLabel: "Mark resolved",
      onInit: async (out) => {
        await api.post(`/overrides/disputes/${d.id}/resolve`, { resolution: out.resolution });
        toast("Dispute resolved", "success");
      },
    });
    if (res) await loadDisputes();
  }

  async function newDispute() {
    const res = await formModal({
      title: "Record support dispute",
      fields: [
        { name: "bookingId", label: "Booking ID (optional)", type: "number", min: 1, placeholder: "e.g. 42" },
        { name: "reporterType", label: "Reporter", type: "select", required: true, options: [["CUSTOMER", "Customer"], ["PARTNER", "Partner"]] },
        { name: "subject", label: "Subject", type: "text", required: true, max: 160 },
        { name: "description", label: "Description", type: "textarea", max: 2000 },
      ],
      submitLabel: "Record dispute",
      onInit: async (out) => {
        await api.post("/overrides/disputes", {
          bookingId: out.bookingId ? Number(out.bookingId) : null,
          reporterType: out.reporterType,
          subject: out.subject,
          description: out.description,
        });
        toast("Dispute recorded", "success");
      },
    });
    if (res) await loadDisputes();
  }

  /* ---------------- manual override ---------------- */

  let currentBooking = null;

  async function lookupBooking() {
    const id = Number(qs("#esc-bid").value);
    if (!id || id < 1) {
      toast("Enter a valid booking ID", "warning");
      return;
    }
    try {
      currentBooking = unwrap(await api.get(`/bookings/${id}`));
      renderBooking();
    } catch (err) {
      currentBooking = null;
      qs("#esc-booking").innerHTML = `<div class="table-empty"><div class="icon"><svg width="22" height="22"><use href="#i-error"/></svg></div>${escapeHtml(errorMessage(err))}</div>`;
    }
  }

  function renderBooking() {
    const b = currentBooking;
    const host = qs("#esc-booking");
    if (!b) return;
    const cancellable = !["COMPLETED", "CANCELLED", "REFUNDED"].includes(b.status);
    host.innerHTML = `
      <div class="table-wrap"><table class="table">
        <tbody>
          <tr><th style="width:180px">Booking</th><td><strong>#${b.id}</strong> ${badge(b.status)}</td></tr>
          <tr><th>Customer</th><td>${escapeHtml(b.customer?.name || "—")} <span class="meta">${escapeHtml(b.customer?.phone || "")}</span></td></tr>
          <tr><th>Service</th><td>${escapeHtml(b.service?.name || "—")}</td></tr>
          <tr><th>Partner</th><td>${b.partner ? `${escapeHtml(b.partner.name)} <span class="meta">${escapeHtml(b.partner.phone || "")}</span>` : '<span class="muted">Not assigned</span>'}</td></tr>
          <tr><th>Amount</th><td><strong>${money(b.totalAmount)}</strong></td></tr>
          <tr><th>Address</th><td>${escapeHtml(b.address || "—")}</td></tr>
          <tr><th>Created</th><td>${fmtDateTime(b.createdAt)}</td></tr>
        </tbody></table></div>
      <div style="display:flex;gap:8px;padding:14px 16px;flex-wrap:wrap">
        ${canOverride ? `
          ${cancellable ? `<button class="btn btn-danger" id="esc-cancel">${icon("i-trash")} Cancel booking</button>` : ""}
          ${cancellable ? `<button class="btn btn-primary" id="esc-reassign">${icon("i-refresh")} Reassign partner</button>` : ""}
          ${b.status !== "REFUNDED" ? `<button class="btn btn-ghost" id="esc-refund">${icon("i-money")} Refund to wallet</button>` : ""}
        ` : '<span class="muted">Read-only — your role cannot apply manual overrides.</span>'}
      </div>`;
    if (canOverride) {
      qs("#esc-cancel")?.addEventListener("click", cancelBooking);
      qs("#esc-reassign")?.addEventListener("click", reassignBooking);
      qs("#esc-refund")?.addEventListener("click", refundBooking);
    }
  }

  async function cancelBooking() {
    const b = currentBooking;
    const res = await formModal({
      title: `Cancel booking #${b.id}?`,
      fields: [
        { name: "reason", label: "Reason (required for audit)", type: "textarea", required: true, max: 500, placeholder: "e.g. Customer not reachable, double booking…" },
      ],
      submitLabel: "Cancel booking",
      onInit: async (out) => {
        const payload = await api.post(`/overrides/bookings/${b.id}/cancel`, { reason: out.reason });
        toast(payload?.message || "Booking cancelled", "success");
      },
    });
    if (res) await lookupBooking();
  }

  async function reassignBooking() {
    const b = currentBooking;
    const lat = b.latitude ?? 19.076;
    const lng = b.longitude ?? 72.8777;
    const res = await formModal({
      title: `Reassign booking #${b.id}`,
      fields: [
        { name: "newPartnerId", label: "Nearby approved partner", type: "select", required: true, options: async () => {
          const data = unwrap(await api.get(`/overrides/workers/nearby?lat=${lat}&lng=${lng}&excludeId=${b.worker?.id || 0}&limit=10`));
          return (data || []).map((p) => [p.id, `${p.name} (${p.distanceKm.toFixed(1)} km)`]);
        } },
        { name: "reason", label: "Reason (required for audit)", type: "textarea", required: true, max: 500, placeholder: "e.g. Partner unavailable, customer moved area…" },
      ],
      submitLabel: "Reassign booking",
      onInit: async (out) => {
        const payload = await api.post(`/overrides/bookings/${b.id}/reassign`, { newWorkerId: Number(out.newPartnerId), reason: out.reason });
        toast(payload?.message || "Booking reassigned", "success");
      },
    });
    if (res) await lookupBooking();
  }

  async function refundBooking() {
    const b = currentBooking;
    const res = await formModal({
      title: `Refund booking #${b.id}`,
      fields: [
        { name: "amount", label: `Refund amount (max ${money(b.totalAmount)})`, type: "number", required: true, min: 0.01, max: Number(b.totalAmount), step: 0.01 },
        { name: "reason", label: "Reason (required for audit)", type: "textarea", required: true, max: 500, placeholder: "e.g. Partial refund after dispute…" },
      ],
      submitLabel: "Issue refund",
      onInit: async (out) => {
        const payload = await api.post(`/overrides/bookings/${b.id}/refund`, { amount: Number(out.amount), reason: out.reason });
        toast(payload?.message || "Refund issued", "success");
      },
    });
    if (res) await lookupBooking();
  }

  /* ---------------- wiring ---------------- */

  qs("#esc-refresh").addEventListener("click", () => Promise.all([loadDisputes(), currentBooking && lookupBooking()]));
  qs("#esc-status").addEventListener("change", (e) => { statusFilter = e.target.value; loadDisputes(); });
  qs("#esc-new")?.addEventListener("click", newDispute);
  qs("#esc-lookup").addEventListener("click", lookupBooking);
  qs("#esc-bid").addEventListener("keydown", (e) => { if (e.key === "Enter") lookupBooking(); });

  qs("#esc-tabs").addEventListener("click", (e) => {
    const btn = e.target.closest("button[data-tab]");
    if (!btn) return;
    qs("#esc-tabs").querySelectorAll("button").forEach((b) => b.classList.toggle("active", b === btn));
    document.querySelectorAll("[data-panel]").forEach((p) => p.classList.toggle("hidden", p.dataset.panel !== btn.dataset.tab));
  });

  qs("#esc-disputes").addEventListener("click", (e) => {
    const tr = e.target.closest("tr[data-id]");
    if (!tr) return;
    const d = disputes.find((x) => x.id === Number(tr.dataset.id));
    if (!d) return;
    if (e.target.closest("[data-view]")) viewDispute(d);
    else if (e.target.closest("[data-resolve]")) resolveDispute(d);
  });
  qs("#esc-disputes").addEventListener("change", (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const tr = e.target.closest("tr[data-id]");
    const d = disputes.find((x) => x.id === Number(tr.dataset.id));
    if (d) uploadLog(d, file);
    e.target.value = "";
  });

  await loadDisputes();
});
