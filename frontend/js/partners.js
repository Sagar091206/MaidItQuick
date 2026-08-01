/* ============================================================
   MaidItQuick Admin — partners.js
   Partner KYC & onboarding verification.
   - Pending / Approved / Rejected filter tabs
   - Document verification modal (identity + address proofs,
     bank details, doc upload)
   - Approve / Reject workflow with rejection-reason capture,
     system notification + audit events
   ============================================================ */

import { api, unwrap, errorMessage, API_ORIGIN } from "./api.js";
import * as auth from "./auth.js";
import {
  registerModule, pageHeader, toast, openModal, closeTopModal,
  confirmDialog, badge, formModal, setNavBadge, fetchAllPages, icon,
} from "./app.js";
import { escapeHtml, fmtDateTime, money, qs } from "./utils.js";

const DOC_TYPES = ["AADHAAR", "GOVT_ID", "DRIVING_LICENSE"];
const DOC_TYPE_LABEL = {
  AADHAAR: "Aadhaar Card",
  GOVT_ID: "Government ID",
  DRIVING_LICENSE: "Driving License",
};

const TABS = [
  { key: "", label: "All Partners" },
  { key: "PENDING", label: "Pending Verification" },
  { key: "APPROVED", label: "Approved Partners" },
  { key: "REJECTED", label: "Rejected Partners", danger: true },
  { key: "DELETED", label: "Deleted Partners", danger: true },
];

registerModule("partners", (el) => {
  const canWrite = auth.hasPermission("PARTNERS_WRITE");
  const state = { status: "", query: "", page: 0, pageSize: 10, sortKey: null, sortDir: "asc" };
  let rows = [];
  let counts = { PENDING: 0, APPROVED: 0, REJECTED: 0 };

  async function load() {
    const deleted = state.status === "DELETED";
    try {
      rows = await fetchAllPages("/partners", {
        status: deleted ? "" : state.status,
        deleted: deleted ? "true" : "",
        query: state.query,
      });
      if (!deleted) {
        const all = state.status === "" ? rows : await fetchAllPages("/partners", {});
        counts = {
          PENDING: all.filter((p) => p.kycStatus === "PENDING").length,
          APPROVED: all.filter((p) => p.kycStatus === "APPROVED").length,
          REJECTED: all.filter((p) => p.kycStatus === "REJECTED").length,
        };
        refreshBadge();
        renderTabs();
      }
    } catch (err) {
      toast(errorMessage(err), "error");
      rows = [];
    }
    renderTable();
  }

  function refreshBadge() {
    setNavBadge("partners", counts.PENDING);
  }

  function sorted() {
    const { sortKey, sortDir } = state;
    if (!sortKey) return [...rows];
    const dir = sortDir === "desc" ? -1 : 1;
    return [...rows].sort((a, b) => {
      const av = sortKey === "name" ? (a.name || "").toLowerCase() : a[sortKey];
      const bv = sortKey === "name" ? (b.name || "").toLowerCase() : b[sortKey];
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
    const body = document.getElementById("partners-table");
    if (!body) return;
    const cols = [
      { key: "name", title: "Name" },
      { key: "phone", title: "Phone" },
      { key: "registeredAt", title: "Registration Date" },
      { key: "kycStatus", title: "KYC Status" },
    ];
    const p = paginate(sorted());
    const thead = cols
      .map((c) => {
        const arrow = state.sortKey === c.key ? (state.sortDir === "desc" ? "↓" : "↑") : "";
        return `<th class="sortable" data-sort="${c.key}">${c.title}<span class="sort-arrow">${arrow}</span></th>`;
      })
      .join("");
    if (p.items.length === 0) {
      body.innerHTML = `<div class="table-wrap"><table class="table"><thead><tr>${thead}<th class="text-right">Actions</th></tr></thead></table>
        <div class="table-empty"><div class="icon"><svg width="22" height="22"><use href="#i-box"/></svg></div>No partners in this view.</div></div>`;
      return;
    }
    const tbody = p.items
      .map((row) => {
        const reason = row.kycStatus === "REJECTED" && row.rejectionReason
          ? `<div class="meta" title="${escapeHtml(row.rejectionReason)}">${escapeHtml(row.rejectionReason.length > 42 ? row.rejectionReason.slice(0, 42) + "…" : row.rejectionReason)}</div>`
          : "";
        return `<tr data-id="${row.id}">
          <td><div class="cell-main"><span class="cell-avatar">${escapeHtml((row.name || "?")[0]?.toUpperCase() || "?")}</span>
            <div><div>${escapeHtml(row.name)}</div><div class="meta">${escapeHtml(row.email || "")}</div></div></div></td>
          <td>${escapeHtml(row.phone || "—")}</td>
          <td>${fmtDateTime(row.registeredAt)}</td>
          <td>${row.deletedAt ? `<span class="badge st-gray">Deleted</span>` : badge(row.kycStatus)}
            ${row.accountStatus === "SUSPENDED" ? ` <span class="badge st-SUSPENDED">Suspended</span>` : ""}${reason}</td>
          <td class="text-right"><div class="actions">
            <button class="btn btn-primary btn-sm" data-view title="View details">${icon("i-eye")} View Details</button>
            ${canWrite ? (row.deletedAt
              ? `<button class="btn btn-ghost btn-sm" data-restore title="Restore partner">${icon("i-restore")} Restore</button>`
              : `
              <button class="btn btn-ghost btn-sm" data-act title="Suspend / activate account">${icon(row.accountStatus === "SUSPENDED" ? "i-check" : "i-lock")} ${row.accountStatus === "SUSPENDED" ? "Activate" : "Suspend"}</button>
              <button class="btn btn-ghost btn-icon-sm" data-edit title="Edit"><svg width="15" height="15"><use href="#i-edit"/></svg></button>
              <button class="btn btn-ghost btn-icon-sm" data-del title="Delete" style="color:var(--danger)"><svg width="15" height="15"><use href="#i-trash"/></svg></button>`) : ""}
          </div></td></tr>`;
      })
      .join("");
    const pageBtns = [];
    for (let i = Math.max(0, state.page - 2); i < p.pages && i <= state.page + 2; i++) {
      pageBtns.push(`<button class="page-btn ${i === state.page ? "active" : ""}" data-gopage="${i}">${i + 1}</button>`);
    }
    const from = p.total === 0 ? 0 : state.page * state.pageSize + 1;
    const to = Math.min(p.total, (state.page + 1) * state.pageSize);
    body.innerHTML = `
      <div class="table-wrap"><table class="table">
        <thead><tr>${thead}<th class="text-right">Actions</th></tr></thead>
        <tbody>${tbody}</tbody></table></div>
      <div class="pager">
        <div class="pager-info">Showing ${from}–${to} of ${p.total} records</div>
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
    const host = document.getElementById("partners-tabs");
    if (!host) return;
    host.innerHTML = `<div class="seg-tabs">
      ${TABS.map((t) => `
        <button class="${state.status === t.key ? "active" : ""} ${t.danger ? "danger" : ""}" data-status="${t.key}">
          ${escapeHtml(t.label)}
          ${t.key ? `<span class="count">${counts[t.key] ?? 0}</span>` : ""}
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

  /* ---------- verification modal ---------- */
  function docBox(label, path, uploadName, docTypeSelect) {
    const img = path
      ? `<div class="doc-preview"><img src="${API_ORIGIN}${escapeHtml(path)}" alt="${escapeHtml(label)}" data-zoom></div>`
      : `<div class="doc-preview"><div class="doc-empty">No document uploaded yet</div></div>`;
    const upload = canWrite
      ? `<div class="doc-upload">
          <label for="${uploadName}">${icon("i-upload")} Upload</label>
          <input type="file" id="${uploadName}" accept="image/*,.pdf" data-doc="${uploadName}">
        </div>`
      : "";
    return `<div class="doc-box">
      <div class="doc-head"><span>${escapeHtml(label)}</span>${docTypeSelect || ""}</div>
      ${img}${upload}
    </div>`;
  }

  async function openDetails(row) {
    const fresh = await refreshPartner(row.id);
    const p = fresh || row;
    const body = `
      <div class="kv-grid" style="margin-bottom:16px">
        <div class="kv"><span>Full name</span><strong>${escapeHtml(p.name)}</strong></div>
        <div class="kv"><span>Phone</span><strong>${escapeHtml(p.phone || "—")}</strong></div>
        <div class="kv"><span>Email</span><strong>${escapeHtml(p.email || "—")}</strong></div>
        <div class="kv"><span>KYC status</span><strong>${badge(p.kycStatus)}</strong></div>
        <div class="kv"><span>Account</span><strong>${p.deletedAt ? `<span class="badge st-gray">Deleted</span>` : p.accountStatus === "SUSPENDED" ? `<span class="badge st-SUSPENDED">Suspended</span>` : `<span class="badge st-ACTIVE">Active</span>`}</strong></div>
        <div class="kv"><span>Registered</span><strong>${fmtDateTime(p.registeredAt)}</strong></div>
        <div class="kv"><span>Approved at</span><strong>${p.approvedAt ? fmtDateTime(p.approvedAt) : "—"}</strong></div>
        ${p.rejectionReason ? `<div class="kv" style="grid-column:1/-1"><span>Rejection reason</span><strong style="color:var(--danger)">${escapeHtml(p.rejectionReason)}</strong></div>` : ""}
        <div class="kv" style="grid-column:1/-1"><span>Address</span><strong>${escapeHtml(p.address || "—")}</strong></div>
      </div>
      <div class="doc-grid">
        ${docBox(`Identity proof — ${DOC_TYPE_LABEL[p.identityDocType] || p.identityDocType || "Document"}`, p.identityDocPath, "up-identity",
          `<select class="select" id="doc-type" style="width:auto;min-width:150px;padding:2px 26px 2px 8px;font-size:11px">
            ${DOC_TYPES.map((t) => `<option value="${t}" ${t === p.identityDocType ? "selected" : ""}>${DOC_TYPE_LABEL[t]}</option>`).join("")}
          </select>`)}
        ${docBox("Address proof", p.addressDocPath, "up-address", "")}
      </div>
      <h4 style="margin:16px 0 10px">Bank details</h4>
      <div class="kv-grid">
        <div class="kv"><span>Account holder</span><strong>${escapeHtml(p.bankAccountHolder || "—")}</strong></div>
        <div class="kv"><span>Account number</span><strong class="mono">${escapeHtml(p.bankAccountNumber || "—")}</strong></div>
        <div class="kv"><span>IFSC code</span><strong class="mono">${escapeHtml(p.bankIfsc || "—")}</strong></div>
        <div class="kv"><span>UPI ID</span><strong class="mono">${escapeHtml(p.upiId || "—")}</strong></div>
      </div>`;
    const canAct = canWrite && (p.kycStatus === "PENDING" || p.kycStatus === "REJECTED" || p.kycStatus === "APPROVED");
    const footer = `
      <button class="btn btn-ghost" data-close>Close</button>
      ${canAct && p.kycStatus !== "APPROVED" ? `<button class="btn btn-primary" data-approve>${icon("i-check")} Approve Profile</button>` : ""}
      ${canAct ? `<button class="btn btn-danger" data-reject>${icon("i-alert")} Reject Profile</button>` : ""}`;
    openModal({ title: `Verify partner — ${p.name}`, body, footer, size: "lg" });

    const overlay = [...document.querySelectorAll(".modal-overlay")].at(-1);
    overlay.querySelector("[data-close]").addEventListener("click", closeTopModal);
    overlay.querySelector("[data-approve]")?.addEventListener("click", async () => approve(p));
    overlay.querySelector("[data-reject]")?.addEventListener("click", () => reject(p));
    overlay.querySelectorAll("[data-doc]").forEach((input) => {
      input.addEventListener("change", () => uploadDoc(p, input));
    });
    overlay.querySelector("[data-zoom]")?.addEventListener("click", () => {
      const src = overlay.querySelector("[data-zoom]").src;
      openModal({
        title: "Document preview",
        body: `<img src="${src}" style="max-width:100%;border-radius:10px">`,
        footer: `<button class="btn btn-ghost" data-close>Close</button>`,
      });
      [...document.querySelectorAll(".modal-overlay")].at(-1).querySelector("[data-close]").addEventListener("click", closeTopModal);
    });
  }

  async function refreshPartner(id) {
    try {
      const payload = await api.get(`/partners/${id}`);
      return unwrap(payload);
    } catch {
      return null;
    }
  }

  async function approve(row) {
    const ok = await confirmDialog({
      title: `Approve ${row.name}?`,
      message: "Their profile status will change to <b>Approved</b>, the approval timestamp will be logged, and a system notification will be sent to their partner app so they can start receiving service requests.",
      confirmLabel: "Approve Profile",
    });
    if (!ok) return;
    try {
      await api.post(`/partners/${row.id}/approve`);
      toast(`${row.name} approved — partner app notified`, "success");
      closeTopModal();
      load();
    } catch (err) {
      toast(errorMessage(err), "error");
    }
  }

  async function reject(row) {
    const body = `
      <div class="field">
        <label class="req" for="reject-reason">Rejection reason</label>
        <textarea class="textarea" id="reject-reason" rows="3" maxlength="1000"
          placeholder="e.g. Blurry ID, Invalid IFSC code…"></textarea>
        <div class="field-error hidden" id="reject-err"></div>
      </div>
      <p class="muted" style="font-size:12px;margin-top:8px">This feedback is sent to the partner's mobile app when you submit.</p>`;
    openModal({
      title: `Reject profile — ${row.name}`,
      body,
      footer: `<button class="btn btn-ghost" data-close>Cancel</button>
               <button class="btn btn-danger" data-submit>${icon("i-alert")} Submit Rejection</button>`,
    });
    const overlay = [...document.querySelectorAll(".modal-overlay")].at(-1);
    overlay.querySelector("[data-close]").addEventListener("click", closeTopModal);
    const submit = overlay.querySelector("[data-submit]");
    submit.addEventListener("click", async () => {
      const reason = overlay.querySelector("#reject-reason").value.trim();
      const errEl = overlay.querySelector("#reject-err");
      if (!reason) {
        errEl.textContent = "A rejection reason is required — tell the partner what to fix.";
        errEl.classList.remove("hidden");
        return;
      }
      submit.disabled = true;
      try {
        await api.post(`/partners/${row.id}/reject`, { reason });
        toast(`${row.name} rejected — feedback sent to partner app`, "success");
        closeTopModal();
        closeTopModal();
        load();
      } catch (err) {
        submit.disabled = false;
        toast(errorMessage(err), "error");
      }
    });
  }

  async function uploadDoc(row, input) {
    const file = input.files[0];
    if (!file) return;
    const fd = new FormData();
    fd.append(input.dataset.doc === "up-identity" ? "identity" : "address", file);
    const typeSel = document.getElementById("doc-type");
    if (input.dataset.doc === "up-identity" && typeSel) {
      fd.append("identityDocType", typeSel.value);
    }
    try {
      toast("Uploading document…", "info");
      await api.upload(`/partners/${row.id}/documents`, fd);
      toast("Document uploaded successfully", "success");
      closeTopModal();
      openDetails(row);
      load();
    } catch (err) {
      toast(errorMessage(err), "error");
    }
  }

  /* ---------- create / edit ---------- */
  const FIELDS = [
    { name: "name", label: "Full name", type: "text", required: true, max: 160, span2: true },
    { name: "phone", label: "Phone", type: "text", required: true, max: 40 },
    { name: "email", label: "Email", type: "email", max: 255 },
    { name: "identityDocType", label: "Identity proof type", type: "select", options: DOC_TYPES.map((t) => [t, DOC_TYPE_LABEL[t]]) },
    { name: "address", label: "Address", type: "textarea", max: 500, span2: true },
    { name: "bankAccountHolder", label: "Account holder name", type: "text", max: 160, span2: true },
    { name: "bankAccountNumber", label: "Account number", type: "text", max: 40 },
    { name: "bankIfsc", label: "IFSC code", type: "text", max: 20 },
    { name: "upiId", label: "UPI ID", type: "text", max: 80 },
    { name: "latitude", label: "Latitude", type: "number", step: "0.000001" },
    { name: "longitude", label: "Longitude", type: "number", step: "0.000001" },
  ];

  function toBody(v) {
    return {
      name: v.name,
      phone: v.phone,
      email: v.email || null,
      identityDocType: v.identityDocType || "AADHAAR",
      address: v.address || null,
      bankAccountHolder: v.bankAccountHolder || null,
      bankAccountNumber: v.bankAccountNumber || null,
      bankIfsc: v.bankIfsc || null,
      upiId: v.upiId || null,
      latitude: v.latitude !== "" ? Number(v.latitude) : null,
      longitude: v.longitude !== "" ? Number(v.longitude) : null,
    };
  }

  function openCreate() {
    formModal({
      title: "Onboard new partner",
      fields: FIELDS,
      submitLabel: "Create Partner",
      onInit: async (values) => {
        await api.post("/partners", toBody(values));
        toast("Partner created — added to pending verification", "success");
        load();
      },
    });
  }

  function openEdit(row) {
    formModal({
      title: `Edit partner — ${row.name}`,
      fields: FIELDS,
      initial: row,
      submitLabel: "Save changes",
      onInit: async (values) => {
        await api.put(`/partners/${row.id}`, toBody(values));
        toast("Partner updated", "success");
        load();
      },
    });
  }

  async function remove(row) {
    const ok = await confirmDialog({
      title: `Delete partner ${row.name}?`,
      message: "The partner is soft-deleted: hidden from all views, but their past bookings stay intact. You can restore them anytime from the Deleted tab.",
      confirmLabel: "Soft delete",
      danger: true,
    });
    if (!ok) return;
    try {
      await api.delete(`/partners/${row.id}`);
      toast(`Partner deleted`, "success");
      load();
    } catch (err) {
      toast(errorMessage(err), "error");
    }
  }

  async function accountToggle(row) {
    const suspending = row.accountStatus !== "SUSPENDED";
    const ok = await confirmDialog({
      title: suspending ? `Suspend ${row.name}?` : `Activate ${row.name}?`,
      message: suspending
        ? "The partner will stop receiving new service requests until you reactivate them. Their account is notified."
        : "The partner can receive new service requests again. Their account is notified.",
      confirmLabel: suspending ? "Suspend account" : "Activate account",
      danger: suspending,
    });
    if (!ok) return;
    try {
      await api.post(`/partners/${row.id}/${suspending ? "suspend" : "activate"}`);
      toast(`${row.name} ${suspending ? "suspended" : "activated"}`, "success");
      load();
    } catch (err) {
      toast(errorMessage(err), "error");
    }
  }

  async function restore(row) {
    const ok = await confirmDialog({
      title: `Restore partner ${row.name}?`,
      message: "The partner becomes visible again in the partner lists.",
      confirmLabel: "Restore",
    });
    if (!ok) return;
    try {
      await api.post(`/partners/${row.id}/restore`);
      toast(`${row.name} restored`, "success");
      load();
    } catch (err) {
      toast(errorMessage(err), "error");
    }
  }

  /* ---------- render page ---------- */
  el.innerHTML = pageHeader(
    "Partner KYC & Onboarding",
    "Verify identity and address proofs, bank details, then approve partners to go live.",
    canWrite ? `<button class="btn btn-primary" id="add-partner">${icon("i-plus")} Onboard Partner</button>` : ""
  );
  el.innerHTML += `
    <div class="card fade-up">
      <div style="display:flex;flex-wrap:wrap;gap:12px;align-items:center;padding:14px 16px 4px">
        <div id="partners-tabs"></div>
        <div class="toolbar-spacer"></div>
        <div class="search-box" style="width:260px">
          <span class="icon"><svg width="16" height="16"><use href="#i-search"/></svg></span>
          <input class="input" type="search" placeholder="Search name, phone, email…" id="partner-search">
        </div>
      </div>
      <div id="partners-table"></div>
    </div>`;

  document.getElementById("add-partner")?.addEventListener("click", openCreate);
  let t;
  document.getElementById("partner-search").addEventListener("input", (e) => {
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
    else if (e.target.closest("[data-edit]")) openEdit(row);
    else if (e.target.closest("[data-del]")) remove(row);
    else if (e.target.closest("[data-act]")) accountToggle(row);
    else if (e.target.closest("[data-restore]")) restore(row);
  });

  renderTabs();
  load();
});
