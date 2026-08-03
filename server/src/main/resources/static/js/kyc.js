/* ============================================================
   MaidItQuick Admin — kyc.js
   KYC Verification queue (partner KYC only).
   - Segmented queue: Pending Review / Approved / Rejected
   - Document preview + download, bank details review
   - Approve / Reject (mandatory reason) actions
   ============================================================ */

import { api, unwrap, errorMessage, API_ORIGIN } from "./api.js";
import * as auth from "./auth.js";
import {
  registerModule, pageHeader, toast, openModal, closeTopModal,
  confirmDialog, badge, setNavBadge, fetchAllPages, icon,
} from "./app.js";
import { escapeHtml, fmtDateTime } from "./utils.js";

const DOC_TYPE_LABEL = {
  AADHAAR: "Aadhaar Card",
  GOVT_ID: "Government ID",
  DRIVING_LICENSE: "Driving License",
};

const TABS = [
  { key: "PENDING", label: "Pending Review" },
  { key: "APPROVED", label: "Approved" },
  { key: "REJECTED", label: "Rejected", danger: true },
];

registerModule("kyc", (el) => {
  const canWrite = auth.hasPermission("PARTNERS_WRITE");
  const state = { status: "PENDING", query: "", page: 0, pageSize: 10, sortKey: null, sortDir: "asc" };
  let rows = [];
  let counts = { PENDING: 0, APPROVED: 0, REJECTED: 0 };

  async function load() {
    try {
      const list = await fetchAllPages("/partners", { status: state.status, query: state.query });
      rows = list;
      const all = state.status === "PENDING" ? list : await fetchAllPages("/partners", {});
      counts = {
        PENDING: all.filter((p) => p.kycStatus === "PENDING").length,
        APPROVED: all.filter((p) => p.kycStatus === "APPROVED").length,
        REJECTED: all.filter((p) => p.kycStatus === "REJECTED").length,
      };
      refreshBadge();
    } catch (err) {
      toast(errorMessage(err), "error");
      rows = [];
    }
    renderTabs();
    renderTable();
  }

  function refreshBadge() {
    setNavBadge("kyc", counts.PENDING);
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

  function docChips(p) {
    const idOk = p.identityDocPath ? `<span class="badge st-SUCCESS">${icon("i-check")} Identity</span>` : `<span class="badge st-WARNING">No identity doc</span>`;
    const addrOk = p.addressDocPath ? `<span class="badge st-SUCCESS">${icon("i-check")} Address</span>` : `<span class="badge st-WARNING">No address proof</span>`;
    return `<div style="display:flex;gap:6px;flex-wrap:wrap">${idOk}${addrOk}</div>`;
  }

  function renderTabs() {
    const host = document.getElementById("kyc-tabs");
    if (!host) return;
    host.innerHTML = `<div class="seg-tabs">
      ${TABS.map((t) => `
        <button class="${state.status === t.key ? "active" : ""} ${t.danger ? "danger" : ""}" data-status="${t.key}">
          ${escapeHtml(t.label)}
          <span class="count">${counts[t.key] ?? 0}</span>
        </button>`).join("")}
    </div>`;
    host.querySelectorAll("button").forEach((btn) => {
      btn.addEventListener("click", () => {
        state.status = btn.dataset.status;
        state.page = 0;
        load();
      });
    });
  }

  function renderTable() {
    const body = document.getElementById("kyc-table");
    if (!body) return;
    const cols = [
      { key: "name", title: "Partner" },
      { key: "phone", title: "Contact" },
      { key: "identityDocType", title: "Documents" },
      { key: "registeredAt", title: "Submitted" },
      { key: "kycStatus", title: "Status" },
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
        <div class="table-empty"><div class="icon"><svg width="22" height="22"><use href="#i-verify"/></svg></div>No partners in this queue.</div></div>`;
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
          <td>${docChips(row)}</td>
          <td>${fmtDateTime(row.registeredAt)}</td>
          <td>${badge(row.kycStatus)}
            ${row.accountStatus === "SUSPENDED" ? ` <span class="badge st-SUSPENDED">Suspended</span>` : ""}${reason}</td>
          <td class="text-right"><div class="actions">
            <button class="btn btn-primary btn-sm" data-view title="Review KYC">${icon("i-eye")} Review</button>
            ${canWrite ? `
              <button class="btn btn-ghost btn-icon-sm" data-approve title="Approve" style="color:var(--success)"><svg width="15" height="15"><use href="#i-check"/></svg></button>
              <button class="btn btn-ghost btn-icon-sm" data-reject title="Reject" style="color:var(--danger)"><svg width="15" height="15"><use href="#i-alert"/></svg></button>` : ""}
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

  /* ---------- review modal ---------- */
  function docBox(label, path, docType) {
    const img = path
      ? `<div class="doc-preview"><img src="${API_ORIGIN}${escapeHtml(path)}" alt="${escapeHtml(label)}" data-zoom></div>`
      : `<div class="doc-preview"><div class="doc-empty">No document uploaded yet</div></div>`;
    const dl = path
      ? `<a class="btn btn-ghost btn-sm" href="${API_ORIGIN}${escapeHtml(path)}" target="_blank" rel="noopener" style="margin-top:8px">${icon("i-download")} Download</a>`
      : "";
    return `<div class="doc-box">
      <div class="doc-head"><span>${escapeHtml(label)}${docType ? ` · ${escapeHtml(docType)}` : ""}</span></div>
      ${img}${dl}
    </div>`;
  }

  async function openReview(row) {
    let p = row;
    try {
      const payload = await api.get(`/partners/${row.id}`);
      p = unwrap(payload) || row;
    } catch { /* keep row */ }
    const body = `
      <div class="kv-grid" style="margin-bottom:16px">
        <div class="kv"><span>Full name</span><strong>${escapeHtml(p.name)}</strong></div>
        <div class="kv"><span>Phone</span><strong>${escapeHtml(p.phone || "—")}</strong></div>
        <div class="kv"><span>Email</span><strong>${escapeHtml(p.email || "—")}</strong></div>
        <div class="kv"><span>KYC status</span><strong>${badge(p.kycStatus)}</strong></div>
        <div class="kv"><span>Registered</span><strong>${fmtDateTime(p.registeredAt)}</strong></div>
        <div class="kv"><span>Approved at</span><strong>${p.approvedAt ? fmtDateTime(p.approvedAt) : "—"}</strong></div>
        ${p.rejectionReason ? `<div class="kv" style="grid-column:1/-1"><span>Rejection reason</span><strong style="color:var(--danger)">${escapeHtml(p.rejectionReason)}</strong></div>` : ""}
        <div class="kv" style="grid-column:1/-1"><span>Address</span><strong>${escapeHtml(p.address || "—")}</strong></div>
      </div>
      <div class="doc-grid">
        ${docBox("Identity proof", p.identityDocPath, DOC_TYPE_LABEL[p.identityDocType] || p.identityDocType)}
        ${docBox("Address proof", p.addressDocPath, null)}
      </div>
      <h4 style="margin:16px 0 10px">Bank details</h4>
      <div class="kv-grid">
        <div class="kv"><span>Account holder</span><strong>${escapeHtml(p.bankAccountHolder || "—")}</strong></div>
        <div class="kv"><span>Account number</span><strong class="mono">${escapeHtml(p.bankAccountNumber || "—")}</strong></div>
        <div class="kv"><span>IFSC code</span><strong class="mono">${escapeHtml(p.bankIfsc || "—")}</strong></div>
        <div class="kv"><span>UPI ID</span><strong class="mono">${escapeHtml(p.upiId || "—")}</strong></div>
      </div>`;
    const canAct = canWrite && p.kycStatus !== "APPROVED";
    const footer = `
      <button class="btn btn-ghost" data-close>Close</button>
      ${canAct ? `<button class="btn btn-danger" data-reject>${icon("i-alert")} Reject</button>` : ""}
      ${canAct ? `<button class="btn btn-primary" data-approve>${icon("i-check")} Approve</button>` : ""}`;
    openModal({ title: `KYC review — ${p.name}`, body, footer, size: "lg" });

    const overlay = [...document.querySelectorAll(".modal-overlay")].at(-1);
    overlay.querySelector("[data-close]").addEventListener("click", closeTopModal);
    overlay.querySelector("[data-approve]")?.addEventListener("click", () => approve(p));
    overlay.querySelector("[data-reject]")?.addEventListener("click", () => reject(p));
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

  async function approve(row) {
    const ok = await confirmDialog({
      title: `Approve ${row.name}?`,
      message: "The partner will be marked approved, notified on their app, and can start receiving bookings.",
      confirmLabel: "Approve Partner",
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
        <label class="req" for="kyc-reject-reason">Rejection reason</label>
        <textarea class="textarea" id="kyc-reject-reason" rows="3" maxlength="1000"
          placeholder="e.g. Blurry ID, Invalid IFSC code…"></textarea>
        <div class="field-error hidden" id="kyc-reject-err"></div>
      </div>
      <p class="muted" style="font-size:12px;margin-top:8px">This feedback is sent to the partner's mobile app.</p>`;
    openModal({
      title: `Reject KYC — ${row.name}`,
      body,
      footer: `<button class="btn btn-ghost" data-close>Cancel</button>
               <button class="btn btn-danger" data-submit>${icon("i-alert")} Submit Rejection</button>`,
    });
    const overlay = [...document.querySelectorAll(".modal-overlay")].at(-1);
    overlay.querySelector("[data-close]").addEventListener("click", closeTopModal);
    const submit = overlay.querySelector("[data-submit]");
    submit.addEventListener("click", async () => {
      const reason = overlay.querySelector("#kyc-reject-reason").value.trim();
      const errEl = overlay.querySelector("#kyc-reject-err");
      if (!reason) {
        errEl.textContent = "A rejection reason is required.";
        errEl.classList.remove("hidden");
        return;
      }
      submit.disabled = true;
      try {
        await api.post(`/partners/${row.id}/reject`, { reason });
        toast(`${row.name} rejected — feedback sent`, "success");
        closeTopModal();
        load();
      } catch (err) {
        submit.disabled = false;
        toast(errorMessage(err), "error");
      }
    });
  }

  /* ---------- render page ---------- */
  el.innerHTML = pageHeader(
    "KYC Verification",
    "Review partner identity and address proofs, bank details, then approve or reject. No customer KYC exists in the system.",
    ""
  );
  el.innerHTML += `
    <div class="card fade-up">
      <div style="display:flex;flex-wrap:wrap;gap:12px;align-items:center;padding:14px 16px 4px">
        <div id="kyc-tabs"></div>
        <div class="toolbar-spacer"></div>
        <div class="search-box" style="width:260px">
          <span class="icon"><svg width="16" height="16"><use href="#i-search"/></svg></span>
          <input class="input" type="search" placeholder="Search name, phone, email…" id="kyc-search">
        </div>
      </div>
      <div id="kyc-table"></div>
    </div>`;

  let t;
  document.getElementById("kyc-search").addEventListener("input", (e) => {
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
    if (e.target.closest("[data-view]")) openReview(row);
    else if (e.target.closest("[data-approve]")) approve(row);
    else if (e.target.closest("[data-reject]")) reject(row);
  });

  load();
});
