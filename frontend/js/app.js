/* ============================================================
   MaidItQuick Admin — app.js
   Shell bootstrap: session guard, sticky top nav, topbar,
   router, shared UI primitives (toast, modal, confirm, spinner, table)
   ============================================================ */

import { api, unwrap, errorMessage, pageOf } from "./api.js";
import * as auth from "./auth.js";
import { escapeHtml, initials } from "./utils.js";
import { qs } from "./utils.js";

const viewEl = document.getElementById("view");

/* ================= Routes / modules =================
   Primary navigation mirrors the Operations Portal spec:
   Dashboard | Customers | Partners | KYC Verification | Bookings |
   Payments | Returns | User Requests | Audits | Settings |
   Admin Profile | Logout
   Secondary modules (reports, live ops, ledger, users, admins,
   roles, services, categories, reviews, notifications,
   settlements, escalations) live under the "More" menu and keep
   their permission gates intact.
*/
export const MODULES = [
  { path: "dashboard", label: "Dashboard", group: "Primary", permission: "DASHBOARD_VIEW", icon: "i-dashboard" },
  { path: "customers", label: "Customers", group: "Primary", permission: "CUSTOMERS_READ", icon: "i-customers" },
  { path: "partners", label: "Partners", group: "Primary", permission: "PARTNERS_READ", icon: "i-partner" },
  { path: "kyc", label: "KYC Verification", group: "Primary", permission: "PARTNERS_READ", icon: "i-verify" },
  { path: "bookings", label: "Bookings", group: "Primary", permission: "BOOKINGS_READ", icon: "i-bookings" },
  { path: "payments", label: "Payments", group: "Primary", permission: "PAYMENTS_READ", icon: "i-payments" },
  { path: "returns", label: "Returns", group: "Primary", permission: "PAYMENTS_READ", icon: "i-returns" },
  { path: "user-requests", label: "User Requests", group: "Primary", permission: "DISPUTES_READ", icon: "i-request" },
  { path: "audit", label: "Audits", group: "Primary", permission: "AUDIT_READ", icon: "i-audit" },
  { path: "settings", label: "Settings", group: "Primary", permission: "SETTINGS_READ", icon: "i-settings" },
  { path: "admin-profile", label: "Admin Profile", group: "Primary", permission: "AUTH_PROFILE", icon: "i-profile" },
  { path: "reports", label: "Reports", group: "More", permission: "REPORTS_VIEW", icon: "i-reports" },
  { path: "live-ops", label: "Live Operations", group: "More", permission: "BOOKINGS_READ", icon: "i-live" },
  { path: "ledger", label: "Bookings Ledger", group: "More", permission: "BOOKINGS_READ", icon: "i-money" },
  { path: "settlements", label: "Settlements & Payouts", group: "More", permission: "SETTLEMENTS_READ", icon: "i-bank" },
  { path: "escalations", label: "Support & Overrides", group: "More", permission: "DISPUTES_READ", icon: "i-support" },
  { path: "users", label: "Users", group: "More", permission: "USERS_READ", icon: "i-users" },
  { path: "admins", label: "Admins", group: "More", permission: "ADMINS_MANAGE", icon: "i-admin" },
  { path: "roles", label: "Roles", group: "More", permission: "ROLES_READ", icon: "i-roles" },
  { path: "services", label: "Services", group: "More", permission: "SERVICES_READ", icon: "i-services" },
  { path: "categories", label: "Categories", group: "More", permission: "CATEGORIES_READ", icon: "i-categories" },
  { path: "reviews", label: "Reviews", group: "More", permission: "REVIEWS_READ", icon: "i-reviews" },
  { path: "notifications", label: "Notifications", group: "More", permission: "NOTIFICATIONS_READ", icon: "i-notifications" },
];

const loaders = new Map();
export function registerModule(path, loader) {
  loaders.set(path, loader);
}

export function moduleFor(path) {
  return MODULES.find((m) => m.path === path);
}

/* ================= Toast ================= */
export function toast(message, type = "info", title = null) {
  const wrap = document.getElementById("toast-wrap");
  const icons = {
    success: "✓",
    error: "✕",
    warning: "!",
    info: "i",
  };
  const labels = { success: "Success", error: "Error", warning: "Warning", info: "Info" };
  const el = document.createElement("div");
  el.className = `toast ${type}`;
  el.innerHTML = `
    <div class="t-icon">${icons[type] || "i"}</div>
    <div class="t-body">
      <div class="t-title">${escapeHtml(title || labels[type] || "Notice")}</div>
      <div class="t-msg">${escapeHtml(message)}</div>
    </div>
    <button class="t-close" aria-label="Close">✕</button>`;
  el.querySelector(".t-close").addEventListener("click", () => dismiss());
  wrap.appendChild(el);
  const dismiss = () => {
    el.classList.add("leaving");
    setTimeout(() => el.remove(), 240);
  };
  setTimeout(dismiss, 4500);
  return el;
}

/* ================= Spinner ================= */
let spinnerCount = 0;
export function showSpinner() {
  spinnerCount++;
  let host = document.getElementById("spinner-host");
  if (!document.querySelector(".spinner-overlay")) {
    const overlay = document.createElement("div");
    overlay.className = "spinner-overlay";
    overlay.innerHTML = '<div class="spinner"></div>';
    host.appendChild(overlay);
  }
}
export function hideSpinner() {
  spinnerCount = Math.max(0, spinnerCount - 1);
  if (spinnerCount === 0) {
    document.querySelectorAll(".spinner-overlay").forEach((el) => el.remove());
  }
}

/* ================= Modal ================= */
export function openModal({ title, body, footer, size = "" }) {
  return new Promise((resolve) => {
    const host = document.getElementById("modal-host");
    const overlay = document.createElement("div");
    overlay.className = "modal-overlay";
    overlay.innerHTML = `
      <div class="modal ${size === "lg" ? "modal-lg" : ""}">
        <div class="modal-head">
          <h3>${escapeHtml(title)}</h3>
          <button class="modal-x" data-close aria-label="Close">
            <svg width="16" height="16"><use href="#i-x"/></svg>
          </button>
        </div>
        <div class="modal-body">${body}</div>
        <div class="modal-foot">${footer || ""}</div>
      </div>`;
    host.appendChild(overlay);
    const close = (result = "closed") => {
      overlay.style.animation = "fadeIn 0.14s ease reverse";
      overlay.remove();
      document.body.style.overflow = "";
      resolve(result);
    };
    overlay.addEventListener("click", (e) => {
      if (e.target === overlay) close();
    });
    overlay.querySelector("[data-close]").addEventListener("click", close);
    document.body.style.overflow = "hidden";
    overlay._close = close;
    // resolve handles for footer buttons
    overlay._resolve = close;
  });
}

export function closeTopModal() {
  const overlays = document.querySelectorAll(".modal-overlay");
  const last = overlays[overlays.length - 1];
  if (last?._close) last._close("closed");
}

/* ================= Confirm dialog ================= */
export function confirmDialog({ title = "Are you sure?", message = "", confirmLabel = "Confirm", danger = false }) {
  return new Promise((resolve) => {
    const host = document.getElementById("modal-host");
    const overlay = document.createElement("div");
    overlay.className = "modal-overlay";
    overlay.innerHTML = `
      <div class="modal" style="max-width:400px">
        <div class="modal-body" style="padding:30px 26px">
          <div class="confirm-icon ${danger ? "danger" : "warn"}">${danger ? "!" : "?"}</div>
          <h3 class="h2 text-center" style="margin-bottom:8px">${escapeHtml(title)}</h3>
          <div class="confirm-text">${message}</div>
        </div>
        <div class="modal-foot">
          <button class="btn btn-ghost" data-cancel>Cancel</button>
          <button class="btn ${danger ? "btn-danger" : "btn-primary"}" data-ok>${escapeHtml(confirmLabel)}</button>
        </div>
      </div>`;
    host.appendChild(overlay);
    const done = (v) => {
      overlay.remove();
      document.body.style.overflow = "";
      resolve(v);
    };
    overlay.querySelector("[data-cancel]").addEventListener("click", () => done(false));
    overlay.querySelector("[data-ok]").addEventListener("click", () => done(true));
    overlay.addEventListener("click", (e) => {
      if (e.target === overlay) done(false);
    });
    document.body.style.overflow = "hidden";
  });
}

/* ================= Badge ================= */
export function badge(status, label = null) {
  if (!status) return "—";
  const cls = `st-${String(status).toUpperCase().replace(/\s+/g, "_")}`;
  return `<span class="badge ${cls}"><span class="dot"></span>${escapeHtml(label || status)}</span>`;
}

export function activeBadge(active) {
  return active === false
    ? `<span class="badge st-SUSPENDED"><span class="dot"></span>Inactive</span>`
    : `<span class="badge st-ACTIVE"><span class="dot"></span>Active</span>`;
}

/* ================= Page header ================= */
export function pageHeader(title, subtitle, actions = "") {
  return `
    <div class="page-head fade-up">
      <div>
        <div class="title">${escapeHtml(title)}</div>
        ${subtitle ? `<div class="sub">${escapeHtml(subtitle)}</div>` : ""}
      </div>
      ${actions ? `<div class="page-actions">${actions}</div>` : ""}
    </div>`;
}

export function icon(name) {
  return `<svg width="16" height="16"><use href="#${name}"/></svg>`;
}

export function spinnerBtn(id, label) {
  return `<button class="btn btn-primary" id="${id}" style="width:100%;padding:12px">
    <span>${label}</span>
  </button>`;
}

/* ================= Toolbar ================= */
export function toolbar({ search = false, searchPlaceholder = "Search…", onSearch, filters = [], onFilterChange, children = "" }) {
  const el = document.createElement("div");
  el.className = "toolbar";
  let html = "";
  if (search) {
    html += `
      <div class="search-box">
        <span class="icon"><svg width="16" height="16"><use href="#i-search"/></svg></span>
        <input class="input" type="search" placeholder="${escapeHtml(searchPlaceholder)}" data-search>
      </div>`;
  }
  for (const f of filters) {
    html += `
      <select class="select" data-filter="${escapeHtml(f.key)}" style="width:auto;min-width:140px">
        <option value="">${escapeHtml(f.label)}</option>
        ${f.options.map((o) => `<option value="${escapeHtml(o.value)}">${escapeHtml(o.label)}</option>`).join("")}
      </select>`;
  }
  html += `<div class="toolbar-spacer"></div>${children}`;
  el.innerHTML = html;
  if (search) {
    const input = el.querySelector("[data-search]");
    let t;
    input.addEventListener("input", () => {
      clearTimeout(t);
      t = setTimeout(() => onSearch?.(input.value), 280);
    });
  }
  for (const f of filters) {
    el.querySelector(`[data-filter="${f.key}"]`).addEventListener("change", (e) => {
      onFilterChange?.({ [f.key]: e.target.value });
    });
  }
  return el;
}

/* ================= Data table =================
   columns: [{key, title, render(row), sortable, align, print}]
   rows: array; filters: fn(row) => bool applied before pagination
   state: {sortKey, sortDir, page, pageSize}
*/
export class Table {
  constructor({ columns, state, onStateChange, pageSizes = [10, 20, 50], rowsPerPageDefault = 10 }) {
    this.columns = columns;
    this.state = state || { sortKey: null, sortDir: "asc", page: 0, pageSize: rowsPerPageDefault };
    this.onStateChange = onStateChange || (() => {});
    this.pageSizes = pageSizes;
    this.rows = [];
    this.extraHtml = "";
    this.emptyText = "No records found.";
  }

  setRows(rows) {
    this.rows = rows || [];
    if (this.state.page * this.state.pageSize >= Math.max(1, this.rows.length)) {
      this.state.page = 0;
    }
  }

  sorted() {
    const { sortKey, sortDir } = this.state;
    if (!sortKey) return [...this.rows];
    const dir = sortDir === "desc" ? -1 : 1;
    const col = this.columns.find((c) => c.key === sortKey);
    return [...this.rows].sort((a, b) => {
      const av = col?.sortValue ? col.sortValue(a) : a[sortKey];
      const bv = col?.sortValue ? col.sortValue(b) : b[sortKey];
      return (av === null || av === undefined ? 1 : av < bv ? -1 : av > bv ? 1 : 0) * dir;
    });
  }

  pageRows() {
    const sorted = this.sorted();
    const start = this.state.page * this.state.pageSize;
    return sorted.slice(start, start + this.state.pageSize);
  }

  render() {
    const rows = this.pageRows();
    const sorted = this.sorted();
    const totalPages = Math.max(1, Math.ceil(sorted.length / this.state.pageSize));
    const total = sorted.length;

    const thead = this.columns
      .map((c) => {
        const arrow = this.state.sortKey === c.key ? (this.state.sortDir === "desc" ? "↓" : "↑") : "";
        const cls = c.sortable ? "sortable" : "";
        return `<th class="${cls} ${c.align === "right" ? "text-right" : ""}" data-sort="${escapeHtml(c.key)}">
          ${escapeHtml(c.title)}<span class="sort-arrow">${arrow}</span></th>`;
      })
      .join("");

    let tbody;
    if (rows.length === 0) {
      tbody = `<tr><td colspan="${this.columns.length}">
        <div class="table-empty">
          <div class="icon"><svg width="22" height="22"><use href="#i-box"/></svg></div>
          ${escapeHtml(this.emptyText)}
        </div></td></tr>`;
    } else {
      tbody = rows
        .map(
          (row) =>
            `<tr>${this.columns
              .map((c) => `<td class="${c.align === "right" ? "text-right" : ""}">${c.render ? c.render(row) : escapeHtml(row[c.key])}</td>`)
              .join("")}</tr>`
        )
        .join("");
    }

    const pageButtons = [];
    const cur = this.state.page;
    const startP = Math.max(0, cur - 2);
    const endP = Math.min(totalPages - 1, cur + 2);
    for (let p = startP; p <= endP; p++) {
      pageButtons.push(`<button class="page-btn ${p === cur ? "active" : ""}" data-page="${p}">${p + 1}</button>`);
    }

    const from = total === 0 ? 0 : cur * this.state.pageSize + 1;
    const to = Math.min(total, (cur + 1) * this.state.pageSize);

    return `
      ${this.extraHtml}
      <div class="table-wrap">
        <table class="table">
          <thead><tr>${thead}</tr></thead>
          <tbody>${tbody}</tbody>
        </table>
      </div>
      <div class="pager">
        <div class="pager-info">Showing ${from}–${to} of ${total} records</div>
        <div class="pager-pages">
          <button class="page-btn" data-page="${cur - 1}" ${cur === 0 ? "disabled" : ""}>‹</button>
          ${pageButtons.join("")}
          <button class="page-btn" data-page="${cur + 1}" ${cur >= totalPages - 1 ? "disabled" : ""}>›</button>
        </div>
        <div class="page-size">
          <span>Rows</span>
          <select class="select" data-pagesize>
            ${this.pageSizes.map((s) => `<option value="${s}" ${s === this.state.pageSize ? "selected" : ""}>${s}</option>`).join("")}
          </select>
        </div>
      </div>`;
  }

  bind(el) {
    el.querySelectorAll("th[data-sort]").forEach((th) => {
      th.addEventListener("click", () => {
        const key = th.dataset.sort;
        if (this.state.sortKey === key) {
          this.state.sortDir = this.state.sortDir === "asc" ? "desc" : "asc";
        } else {
          this.state.sortKey = key;
          this.state.sortDir = "asc";
        }
        this.state.page = 0;
        this.onStateChange();
      });
    });
    el.querySelectorAll(".page-btn").forEach((btn) => {
      btn.addEventListener("click", () => {
        const p = Number(btn.dataset.page);
        if (p >= 0 && p < Math.ceil(this.sorted().length / this.state.pageSize)) {
          this.state.page = p;
          this.onStateChange();
        }
      });
    });
    const ps = el.querySelector("[data-pagesize]");
    if (ps) {
      ps.addEventListener("change", () => {
        this.state.pageSize = Number(ps.value);
        this.state.page = 0;
        this.onStateChange();
      });
    }
  }
}

/* ================= Export actions ================= */
export function exportActions({ columns, rows, filename, title, subtitle }) {
  const csv = () => exportCsvFile(filename, columns, rows);
  const prt = () => printReport(title, subtitle, columns, rows);
  return {
    csv,
    print: prt,
    actionsHtml: `
      <button class="btn btn-ghost btn-sm" data-act="csv">${icon("i-download")} CSV</button>
      <button class="btn btn-ghost btn-sm" data-act="print">${icon("i-print")} Print</button>`,
    bind: (el) => {
      const btnCsv = el.querySelector('[data-act="csv"]');
      const btnPrint = el.querySelector('[data-act="print"]');
      if (btnCsv) btnCsv.addEventListener("click", csv);
      if (btnPrint) btnPrint.addEventListener("click", prt);
    },
  };
}

export function exportCsvFile(filename, columns, rows) {
  const esc = (v) => {
    if (v === null || v === undefined) return "";
    const s = String(v);
    return /[",\n]/.test(s) ? `"${s.replaceAll('"', '""')}"` : s;
  };
  const head = columns.map((c) => esc(c.title)).join(",");
  const body = rows
    .map((row) => columns.map((c) => esc(c.exportValue ? c.exportValue(row) : c.render ? String(c.render(row)).replace(/<[^>]+>/g, "") : row[c.key])).join(","))
    .join("\r\n");
  const blob = new Blob(["\uFEFF" + head + "\r\n" + body], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `${filename}-${new Date().toISOString().slice(0, 10)}.csv`;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 2000);
}

export function printReport(title, subtitle, columns, rows) {
  const esc = escapeHtml;
  const head = columns.map((c) => `<th>${esc(c.title)}</th>`).join("");
  const body = rows
    .map((row) => `<tr>${columns.map((c) => `<td>${esc(c.printValue ? c.printValue(row) : c.render ? String(c.render(row)).replace(/<[^>]+>/g, "") : row[c.key])}</td>`).join("")}</tr>`)
    .join("");
  const area = document.getElementById("print-area");
  area.innerHTML = `
    <div class="print-title">${esc(title)}</div>
    <div class="print-sub">${esc(subtitle)} · Generated ${esc(new Date().toLocaleString("en-IN"))}</div>
    <table class="print-table"><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table>`;
  document.body.classList.add("printing");
  window.print();
  setTimeout(() => {
    document.body.classList.remove("printing");
    area.innerHTML = "";
  }, 800);
}

/* ================= Form modal (create / edit) ================= */
/* field: {name, label, type: text|email|textarea|select|number|datetime-local|checkbox,
           options: [value,label]|fn(row), required, min, max, step, span2, placeholder, disabled(row)} */
export function formModal({ title, fields, initial = {}, submitLabel = "Save", onInit }) {
  return new Promise((resolve) => {
    const values = { ...initial };
    const rows = fields
      .map(
        (f) => `
      <div class="field ${f.span2 ? "span2" : ""}">
        <label class="${f.required ? "req" : ""}" for="f-${f.name}">${escapeHtml(f.label)}</label>
        ${fieldControl(f, values[f.name])}
        <div class="field-error hidden" id="err-${f.name}"></div>
      </div>`
      )
      .join("");

    openModal({
      title,
      body: `<form id="modal-form" novalidate><div class="form-grid">${rows}</div></form>`,
      footer: `
        <button class="btn btn-ghost" data-close>Cancel</button>
        <button class="btn btn-primary" data-submit>${escapeHtml(submitLabel)}</button>`,
      size: "lg",
    }).then(() => resolve(false));

    const overlay = [...document.querySelectorAll(".modal-overlay")].at(-1);
    const closeBtn = overlay.querySelector("[data-close]");
    closeBtn.addEventListener("click", () => resolve(false));
    overlay.addEventListener("click", (e) => {
      if (e.target === overlay) resolve(false);
    });

    // populate dynamic selects (options can depend on row)
    fields.forEach(async (f) => {
      if (f.type === "select") {
        const sel = overlay.querySelector(`#f-${f.name}`);
        if (!sel) return;
        let opts = [];
        if (typeof f.options === "function") {
          try {
            opts = await f.options(values);
          } catch {
            opts = [];
          }
        } else {
          opts = f.options || [];
        }
        sel.innerHTML = opts
          .map((o) => {
            const v = Array.isArray(o) ? o[0] : o.value;
            const l = Array.isArray(o) ? o[1] : o.label;
            return `<option value="${escapeHtml(v)}" ${String(values[f.name]) === String(v) ? "selected" : ""}>${escapeHtml(l)}</option>`;
          })
          .join("");
      }
    });

    overlay.querySelector("[data-submit]").addEventListener("click", async (e) => {
      const btnEl = e.currentTarget;
      btnEl.disabled = true;
      const form = overlay.querySelector("#modal-form");
      const out = {};
      let firstError = null;
      for (const f of fields) {
        const control = form.querySelector(`[name="${f.name}"]`);
        if (!control) continue;
        let val = control.type === "checkbox" ? control.checked : control.value;
        if (f.type === "number" && val !== "") val = Number(val);
        if (f.type === "datetime-local" && val === "") val = null;
        out[f.name] = val;
        const errEl = overlay.querySelector(`#err-${f.name}`);
        if (errEl) {
          errEl.textContent = "";
          errEl.classList.add("hidden");
        }
        if (f.required && (val === "" || val === null || val === undefined || val === false && f.type === "select")) {
          const msg = `${f.label} is required`;
          if (errEl) {
            errEl.textContent = msg;
            errEl.classList.remove("hidden");
          }
          if (!firstError) firstError = errEl || null;
        }
      }
      if (firstError) {
        btnEl.disabled = false;
        return;
      }
      try {
        const result = await onInit(out, values);
        resolve(result ?? true);
        closeTopModal();
      } catch (err) {
        btnEl.disabled = false;
        toast(errorMessage(err), "error");
        const errs = err?.errors;
        if (errs && typeof errs === "object") {
          fields.forEach((f) => {
            const msg = errs[f.name];
            const errEl = overlay.querySelector(`#err-${f.name}`);
            if (msg && errEl) {
              errEl.textContent = msg;
              errEl.classList.remove("hidden");
            }
          });
        }
      }
    });
  });
}

function fieldControl(f, value) {
  const v = value ?? "";
  const disabled = f.disabled ? " disabled" : "";
  switch (f.type) {
    case "textarea":
      return `<textarea class="textarea" id="f-${f.name}" name="${f.name}" placeholder="${escapeHtml(f.placeholder || "")}" maxlength="${f.max || 1000}"${disabled}>${escapeHtml(v)}</textarea>`;
    case "select":
      return `<select class="select" id="f-${f.name}" name="${f.name}"${disabled}></select>`;
    case "checkbox":
      return `<label class="checkbox"><input type="checkbox" name="${f.name}" ${v ? "checked" : ""}${disabled}><span>${escapeHtml(f.help || "")}</span></label>`;
    case "number":
      return `<input class="input" type="number" id="f-${f.name}" name="${f.name}" value="${escapeHtml(v)}" min="${f.min ?? ""}" max="${f.max ?? ""}" step="${f.step ?? ""}" placeholder="${escapeHtml(f.placeholder || "")}"${disabled}>`;
    case "datetime-local":
      return `<input class="input" type="datetime-local" id="f-${f.name}" name="${f.name}" value="${escapeHtml(v)}"${disabled}>`;
    default:
      return `<input class="input" type="${f.type === "email" ? "email" : "text"}" id="f-${f.name}" name="${f.name}" value="${escapeHtml(v)}" placeholder="${escapeHtml(f.placeholder || "")}" maxlength="${f.max || ""}"${disabled}>`;
  }
}

/* ================= Server-side pagination helper ================= */
export async function fetchAllPages(resource, params = {}) {
  const size = 100;
  let page = 0;
  const items = [];
  for (;;) {
    const payload = await api.get(`${resource}${qs({ ...params, page, size })}`);
    const data = unwrap(payload);
    if (Array.isArray(data)) {
      // Non-paginated endpoint (e.g. /roles, /settings, /notifications)
      return data;
    }
    const pg = pageOf(data || payload);
    items.push(...pg.items);
    if (pg.page >= pg.totalPages - 1 || pg.items.length === 0) break;
    page = pg.page + 1;
  }
  return items;
}

/* ================= Full CRUD page factory =================
   opts: {
     title, subtitle,
     resource,                    // "/users"
     permission: { read, write },
     columns,                     // Table columns (render/sortable/sortValue/exportValue/printValue)
     fields,                      // formModal fields
     toBody: (values, row) => body,   // map form values -> API body
     statusField: { key, options, api: (row, status) => Promise },
     rowActions: (row, canWrite) => extraHtml,
     clientFilter: (row, state) => bool,
     filters: [{key,label,options}] // toolbar selects (status etc.)
     serverParams: (state) => ({...}),   // e.g. { status }
     emptyText
   }
*/
export function crudPage(el, opts) {
  const canWrite = auth.hasPermission(opts.permission.write);
  const state = { query: "", page: 0, pageSize: 10, sortKey: null, sortDir: "asc", filter: "" };
  let allRows = [];

  async function load() {
    try {
      const params = { query: state.query, ...(opts.serverParams ? opts.serverParams(state) : {}) };
      allRows = await fetchAllPages(opts.resource, params);
      tableState.page = 0;
      state.page = 0;
    } catch (err) {
      toast(errorMessage(err), "error");
      allRows = [];
    }
    renderTable();
  }

  function visibleRows() {
    let rows = sorted(allRows);
    if (opts.clientFilter) rows = rows.filter((r) => opts.clientFilter(r, state));
    return rows;
  }

  function sorted(list) {
    const { sortKey, sortDir } = state;
    if (!sortKey) return [...list];
    const col = opts.columns.find((c) => c.key === sortKey);
    const dir = sortDir === "desc" ? -1 : 1;
    return [...list].sort((a, b) => {
      const av = col?.sortValue ? col.sortValue(a) : a[sortKey];
      const bv = col?.sortValue ? col.sortValue(b) : b[sortKey];
      const cmp = av === null || av === undefined ? 1 : bv === null || bv === undefined ? -1 : av < bv ? -1 : av > bv ? 1 : 0;
      return cmp * dir;
    });
  }

  const tableState = state;

  function paginate(list) {
    const total = list.length;
    const pages = Math.max(1, Math.ceil(total / state.pageSize));
    if (state.page >= pages) state.page = 0;
    return { items: list.slice(state.page * state.pageSize, (state.page + 1) * state.pageSize), total, pages };
  }

  /* ---- form actions ---- */
  function openCreate() {
    formModal({
      title: `New ${opts.title.slice(0, -1)}`,
      fields: opts.fields,
      submitLabel: "Create",
      onInit: async (values) => {
        await api.post(opts.resource, opts.toBody(values, null));
        toast(`${opts.title.slice(0, -1)} created`, "success");
        load();
      },
    });
  }

  function openEdit(row) {
    formModal({
      title: `Edit ${opts.title.slice(0, -1)}`,
      fields: opts.fields,
      initial: row,
      submitLabel: "Save changes",
      onInit: async (values) => {
        await api.put(`${opts.resource}/${row.id}`, opts.toBody(values, row));
        toast(`${opts.title.slice(0, -1)} updated`, "success");
        load();
      },
    });
  }

  async function remove(row) {
    const label = opts.idOf ? opts.idOf(row) : `#${row.id}`;
    const ok = await confirmDialog({
      title: opts.deleteTitle ? opts.deleteTitle(row) : `Delete ${opts.title.slice(0, -1).toLowerCase()} ${label}?`,
      message: opts.deleteMessage || `This will permanently remove this record. This action cannot be undone.`,
      confirmLabel: opts.deleteConfirmLabel || "Delete",
      danger: true,
    });
    if (!ok) return;
    try {
      await api.delete(`${opts.resource}/${row.id}`);
      toast(`Deleted ${label}`, "success");
      load();
    } catch (err) {
      toast(errorMessage(err), "error");
    }
  }

  async function changeStatus(row, status) {
    if (!opts.statusField) return;
    try {
      await opts.statusField.api(row, status);
      toast(`Status changed to ${status.replaceAll("_", " ").toLowerCase()}`, "success");
      load();
    } catch (err) {
      toast(errorMessage(err), "error");
    }
  }

  function rowActionHtml(row) {
    const parts = [];
    if (opts.statusField && canWrite) {
      const current = opts.statusField.current ? opts.statusField.current(row) : row[opts.statusField.key];
      parts.push(`
        <select class="select" data-status title="Change status" style="width:auto;min-width:118px;padding:5px 28px 5px 10px;font-size:12px">
          ${opts.statusField.options
            .map((o) => {
              const v = Array.isArray(o) ? o[0] : o.value;
              const l = Array.isArray(o) ? o[1] : o.label;
              return `<option value="${escapeHtml(v)}" ${String(current) === String(v) ? "selected" : ""}>${escapeHtml(l)}</option>`;
            })
            .join("")}
        </select>`);
    }
    if (canWrite) {
      parts.push(`<button class="btn btn-ghost btn-icon-sm" data-edit title="Edit"><svg width="15" height="15"><use href="#i-edit"/></svg></button>`);
      parts.push(`<button class="btn btn-ghost btn-icon-sm" data-del title="Delete" style="color:var(--danger)"><svg width="15" height="15"><use href="#i-trash"/></svg></button>`);
    }
    if (opts.rowActions) parts.push(opts.rowActions(row, canWrite));
    return parts.length ? `<div class="actions">${parts.join("")}</div>` : "—";
  }

  /* ---- exports ---- */
  function doExportCsv() {
    exportCsvFile(`${opts.title.toLowerCase().replace(/\s+/g, "-")}`, opts.columns, visibleRows());
  }
  function doPrint() {
    printReport(`${opts.title} — MaidItQuick Admin`, opts.subtitle, opts.columns, visibleRows());
  }

  /* ---- render ---- */
  function renderTable() {
    const body = document.getElementById("table-body");
    if (!body) return;
    const p = paginate(visibleRows());
    if (p.items.length === 0) {
      body.innerHTML = `
        <div class="table-wrap"><table class="table"><thead><tr>${opts.columns
          .map((c) => `<th>${escapeHtml(c.title)}</th>`)
          .join("")}<th></th></tr></thead></table>
        <div class="table-empty"><div class="icon"><svg width="22" height="22"><use href="#i-box"/></svg></div>${escapeHtml(opts.emptyText || "No records found.")}</div></div>`;
      return;
    }
    const thead = opts.columns
      .map((c) => {
        const arrow = state.sortKey === c.key ? (state.sortDir === "desc" ? "↓" : "↑") : "";
        return `<th class="${c.sortable ? "sortable" : ""} ${c.align === "right" ? "text-right" : ""}" data-sort="${escapeHtml(c.key)}">${escapeHtml(c.title)}<span class="sort-arrow">${arrow}</span></th>`;
      })
      .join("");
    const tbody = p.items
      .map(
        (row) => `<tr data-id="${row.id}">${opts.columns
          .map((c) => `<td class="${c.align === "right" ? "text-right" : ""}">${c.render ? c.render(row) : escapeHtml(row[c.key])}</td>`)
          .join("")}<td class="text-right">${rowActionHtml(row)}</td></tr>`
      )
      .join("");
    const pageBtns = [];
    for (let i = Math.max(0, p.pages - 5 > 0 ? Math.max(0, state.page - 2) : 0); i < p.pages && i <= state.page + 2; i++) {
      pageBtns.push(`<button class="page-btn ${i === state.page ? "active" : ""}" data-gopage="${i}">${i + 1}</button>`);
    }
    const from = p.total === 0 ? 0 : state.page * state.pageSize + 1;
    const to = Math.min(p.total, (state.page + 1) * state.pageSize);
    body.innerHTML = `
      <div class="table-wrap">
        <table class="table">
          <thead><tr>${thead}<th class="text-right">Actions</th></tr></thead>
          <tbody>${tbody}</tbody>
        </table>
      </div>
      <div class="pager">
        <div class="pager-info">Showing ${from}–${to} of ${p.total} records</div>
        <div class="pager-pages">
          <button class="page-btn" data-gopage="${state.page - 1}" ${state.page === 0 ? "disabled" : ""}>‹</button>
          ${pageBtns.join("")}
          <button class="page-btn" data-gopage="${state.page + 1}" ${state.page >= p.pages - 1 ? "disabled" : ""}>›</button>
        </div>
        <div class="page-size">
          <span>Rows</span>
          <select class="select" data-pagesize>
            ${[10, 20, 50, 100].map((s) => `<option value="${s}" ${s === state.pageSize ? "selected" : ""}>${s}</option>`).join("")}
          </select>
        </div>
      </div>`;
  }

  function render() {
    el.innerHTML = pageHeader(
      opts.title,
      opts.subtitle,
      `
      <button class="btn btn-ghost" data-csv>${icon("i-download")} CSV</button>
      <button class="btn btn-ghost" data-print>${icon("i-print")} Print</button>
      ${canWrite ? `<button class="btn btn-primary" data-add>${icon("i-plus")} Add ${opts.title.slice(0, -1)}</button>` : ""}
      `
    );

    const tb = toolbar({
      search: true,
      searchPlaceholder: `Search ${opts.title.toLowerCase()}…`,
      onSearch: (q) => {
        state.query = q.trim();
        state.page = 0;
        load();
      },
      filters: opts.filters || [],
      onFilterChange: (f) => {
        Object.assign(state, f);
        state.page = 0;
        load();
      },
    });

    const card = document.createElement("div");
    card.className = "card fade-up";
    card.appendChild(tb);
    const body = document.createElement("div");
    body.id = "table-body";
    card.appendChild(body);
    el.appendChild(card);

    el.querySelector("[data-csv]").addEventListener("click", doExportCsv);
    el.querySelector("[data-print]").addEventListener("click", doPrint);
    el.querySelector("[data-add]")?.addEventListener("click", openCreate);

    card.addEventListener("click", (e) => {
      if (e.target.closest("th[data-sort]")) {
        const key = e.target.closest("th").dataset.sort;
        if (state.sortKey === key) state.sortDir = state.sortDir === "asc" ? "desc" : "asc";
        else {
          state.sortKey = key;
          state.sortDir = "asc";
        }
        state.page = 0;
        renderTable();
        return;
      }
      if (e.target.closest("[data-gopage]")) {
        const p = Number(e.target.closest("[data-gopage]").dataset.gopage);
        const max = paginate(visibleRows()).pages - 1;
        if (p >= 0 && p <= max) {
          state.page = p;
          renderTable();
        }
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
      const row = allRows.find((r) => r.id === Number(tr.dataset.id));
      if (!row) return;
      if (e.target.closest("[data-edit]")) openEdit(row);
      else if (e.target.closest("[data-del]")) remove(row);
      else if (e.target.closest("[data-status]")) changeStatus(row, e.target.value);
      else if (opts.onRowAction) {
        Promise.resolve(opts.onRowAction(row, e.target.closest("button"))).then((done) => {
          if (done === true) load();
        });
      }
    });
    renderTable();
  }

  render();
  load();
}

export function statusSelectOptions(values) {
  return values.map((v) => [v, v.replaceAll("_", " ").toLowerCase().replace(/\b\w/g, (c) => c.toUpperCase())]);
}

/* ================= Router ================= */
async function route() {
  const hash = window.location.hash.replace(/^#\/?/, "") || "dashboard";
  const mod = moduleFor(hash);
  if (!mod) {
    window.location.hash = "#/dashboard";
    return;
  }
  const loader = loaders.get(hash);
  setBreadcrumbs(mod.label);
  setActiveNav(hash);
  viewEl.innerHTML = "";
  if (!auth.hasPermission(mod.permission)) {
    viewEl.innerHTML = `
      <div class="no-access fade-up">
        <div class="icon"><svg width="30" height="30"><use href="#i-lock"/></svg></div>
        <h2>No access to ${escapeHtml(mod.label)}</h2>
        <p>Your role does not include the required permission. Contact a SUPER_ADMIN to request access.</p>
        <button class="btn btn-primary" id="go-dash">Go to Dashboard</button>
      </div>`;
    document.getElementById("go-dash")?.addEventListener("click", () => (window.location.hash = "#/dashboard"));
    return;
  }
  if (!loader) {
    // Lazy-load the module bundle for this route; each module file
    // calls registerModule() on import.
    try {
      await import(`./${hash}.js`);
    } catch (err) {
      console.error(err);
      viewEl.innerHTML = `
        <div class="state-box">
          <div class="icon"><svg width="28" height="28"><use href="#i-error"/></svg></div>
          <h3>Module unavailable</h3>
          <p>Could not load the <b>${escapeHtml(mod.label)}</b> module.</p>
          <button class="btn btn-primary" id="reload-module">Retry</button>
        </div>`;
      document.getElementById("reload-module")?.addEventListener("click", route);
      return;
    }
  }
  const finalLoader = loaders.get(hash);
  if (!finalLoader) {
    viewEl.innerHTML = `<div class="state-box"><p class="muted">Module not registered.</p></div>`;
    return;
  }
  try {
    await finalLoader(viewEl);
  } catch (err) {
    console.error(err);
    viewEl.innerHTML = `
      <div class="state-box">
        <div class="icon"><svg width="28" height="28"><use href="#i-error"/></svg></div>
        <h3>Something went wrong</h3>
        <p>${escapeHtml(errorMessage(err))}</p>
        <button class="btn btn-primary" onclick="location.reload()">Reload</button>
      </div>`;
  }
}

/* ================= Top navigation ================= */
function setBreadcrumbs(label) {
  document.getElementById("breadcrumbs").innerHTML = `
    <span>MaidItQuick</span><span class="sep">/</span>
    <span class="current">${escapeHtml(label)}</span>`;
}

function setActiveNav(path) {
  document.querySelectorAll(".nav-item[data-path]").forEach((a) => {
    a.classList.toggle("active", a.dataset.path === path);
  });
}

function renderTopnav() {
  const nav = document.getElementById("topnav");
  const primary = MODULES.filter((m) => m.group === "Primary" && auth.hasPermission(m.permission));
  const more = MODULES.filter((m) => m.group === "More" && auth.hasPermission(m.permission));
  nav.innerHTML = `
    ${primary
      .map(
        (m) => `
      <a class="nav-item" href="#/${m.path}" data-path="${m.path}">
        <svg><use href="#${m.icon}"/></svg>
        ${escapeHtml(m.label)}
        <span class="nav-badge hidden" data-badge="${m.path}"></span>
      </a>`
      )
      .join("")}
    <button class="nav-item nav-logout" id="nav-logout" data-action="logout">
      <svg><use href="#i-logout"/></svg>
      Logout
    </button>
    ${more.length ? `
      <div class="dropdown" id="nav-more-drop" style="margin-left:auto">
        <button class="nav-item nav-more" id="nav-more-btn">
          <svg><use href="#i-menu"/></svg>
          More
          <svg width="13" height="13"><use href="#i-chev-d"/></svg>
        </button>
        <div class="dropdown-panel" style="min-width:230px;right:8px;top:calc(100% + 6px)">
          ${more
            .map(
              (m) => `
            <a class="dropdown-item" href="#/${m.path}" data-path="${m.path}" style="justify-content:flex-start">
              <svg><use href="#${m.icon}"/></svg>
              ${escapeHtml(m.label)}
              <span class="nav-badge hidden" data-badge="${m.path}" style="margin-left:auto"></span>
            </a>`
            )
            .join("")}
        </div>
      </div>` : ""}
  `;
  document.getElementById("nav-more-btn")?.addEventListener("click", (e) => {
    e.stopPropagation();
    const drop = document.getElementById("nav-more-drop");
    const wasOpen = drop.classList.contains("open");
    document.querySelectorAll(".dropdown.open").forEach((d) => d.classList.remove("open"));
    if (!wasOpen) drop.classList.add("open");
  });
  document.getElementById("nav-logout")?.addEventListener("click", async (e) => {
    e.preventDefault();
    const ok = await confirmDialog({
      title: "Sign out?",
      message: "You will need to sign in again to access the dashboard.",
      confirmLabel: "Sign out",
      danger: true,
    });
    if (!ok) return;
    await auth.logout();
    window.location.replace("login.html");
  });
}

export function setNavBadge(path, count) {
  const els = document.querySelectorAll(`[data-badge="${path}"]`);
  els.forEach((el) => {
    if (count > 0) {
      el.textContent = count > 99 ? "99+" : count;
      el.classList.remove("hidden");
    } else {
      el.classList.add("hidden");
    }
  });
}

/* ================= Topbar: profile ================= */
function renderProfile() {
  const p = auth.getProfile();
  const init = auth.currentInitials();
  const name = p?.name || "Admin";
  const mail = p?.email || "";
  const role = p?.role?.name || "";
  const set = (id, v) => (document.getElementById(id).textContent = v);
  set("top-name", name);
  set("top-avatar", init);
  set("pd-name", name);
  set("pd-mail", mail);
  set("pd-avatar", init);
}

/* ================= Theme switching ================= */
export function currentTheme() {
  return document.documentElement.dataset.theme || "light";
}

export function setTheme(theme) {
  document.documentElement.dataset.theme = theme;
  try {
    localStorage.setItem("mq-theme", theme);
  } catch {
    /* ignore */
  }
}

function bindThemeToggle() {
  const btn = document.getElementById("theme-toggle");
  if (!btn) return;
  btn.addEventListener("click", () => {
    setTheme(currentTheme() === "dark" ? "light" : "dark");
    toast(currentTheme() === "dark" ? "Dark mode enabled" : "Light mode enabled", "info");
  });
}

/* ================= Boot ================= */
async function boot() {
  try {
    await auth.restoreSession();
  } catch {
    window.location.replace("login.html");
    return;
  }
  window.addEventListener("app:session-expired", () => {
    window.location.replace("login.html");
  });

  renderTopnav();
  renderProfile();
  bindThemeToggle();

  // Dropdowns
  const profileDrop = document.getElementById("profile-drop");
  document.getElementById("profile-btn").addEventListener("click", (e) => {
    e.stopPropagation();
    const wasOpen = profileDrop.classList.contains("open");
    document.querySelectorAll(".dropdown.open").forEach((d) => d.classList.remove("open"));
    if (!wasOpen) profileDrop.classList.add("open");
  });

  document.querySelectorAll(".dropdown-item").forEach((btn) => {
    btn.addEventListener("click", async (e) => {
      e.stopPropagation();
      profileDrop.classList.remove("open");
      const action = btn.dataset.action;
      if (action === "logout") {
        const ok = await confirmDialog({
          title: "Sign out?",
          message: "You will need to sign in again to access the dashboard.",
          confirmLabel: "Sign out",
          danger: true,
        });
        if (!ok) return;
        await auth.logout();
        window.location.replace("login.html");
      }
      if (action === "profile") {
        window.location.hash = "#/admin-profile";
      }
    });
  });

  document.addEventListener("click", (e) => {
    if (!e.target.closest(".dropdown")) {
      document.querySelectorAll(".dropdown.open").forEach((d) => d.classList.remove("open"));
    }
  });

  // Router
  window.addEventListener("hashchange", route);
  await route();
}

function profileCard() {
  const p = auth.getProfile();
  if (!p) return "";
  return `
    <div style="display:flex;flex-direction:column;align-items:center;gap:14px;padding:8px 0 14px">
      <div class="cell-avatar" style="width:74px;height:74px;font-size:26px">${escapeHtml(auth.currentInitials())}</div>
      <div style="text-align:center">
        <div class="h1" style="font-size:19px">${escapeHtml(p.name)}</div>
        <div class="muted" style="margin-top:2px">${escapeHtml(p.email)}</div>
      </div>
      ${p.role ? badge(p.role.code, p.role.name) : ""}
    </div>
    <div class="card" style="padding:14px 16px">
      <div class="muted" style="text-transform:uppercase;letter-spacing:.08em;font-weight:700;margin-bottom:8px">Permissions (${p.permissions?.length || 0})</div>
      <div style="display:flex;flex-wrap:wrap;gap:6px">
        ${(p.permissions || []).map((perm) => `<span class="badge st-INFO">${escapeHtml(perm)}</span>`).join("")}
      </div>
    </div>`;
}

boot();
