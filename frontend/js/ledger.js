/* ============================================================
   MaidItQuick Admin — ledger.js
   Past bookings, financial ledger & advanced filters.
   - Commission (configurable % via settings) and net payout
   - Date range, status, customer and partner filters
   - Reset filters + CSV export of the filtered dataset
   ============================================================ */

import { api, unwrap, errorMessage, pageOf } from "./api.js";
import {
  registerModule, pageHeader, toast, badge, icon, exportCsvFile, fetchAllPages,
} from "./app.js";
import { escapeHtml, fmtDateTime, money, qs } from "./utils.js";

const STATUSES = ["PENDING", "CONFIRMED", "IN_PROGRESS", "COMPLETED", "CANCELLED"];

registerModule("ledger", (el) => {
  const state = { from: "", to: "", status: "", customerQ: "", partnerQ: "", page: 0, pageSize: 10, sortKey: "createdAt", sortDir: "desc" };
  let rows = [];

  async function load() {
    try {
      rows = await fetchAllPages(`/bookings/ledger`, {
        from: state.from, to: state.to, status: state.status,
        customerQ: state.customerQ, partnerQ: state.partnerQ,
      });
    } catch (err) {
      toast(errorMessage(err), "error");
      rows = [];
    }
    renderChips();
    renderTable();
  }

  function sorted() {
    const { sortKey, sortDir } = state;
    const dir = sortDir === "desc" ? -1 : 1;
    return [...rows].sort((a, b) => {
      let av = a[sortKey];
      let bv = b[sortKey];
      if (sortKey === "amountPaid" || sortKey === "commission" || sortKey === "netPayout") {
        av = Number(a[sortKey] || 0);
        bv = Number(b[sortKey] || 0);
      } else if (sortKey === "customerName" || sortKey === "partnerName" || sortKey === "serviceName") {
        av = (a[sortKey] || "").toLowerCase();
        bv = (b[sortKey] || "").toLowerCase();
      }
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

  function renderChips() {
    const host = document.getElementById("ledger-chips");
    if (!host) return;
    const sum = (k) => rows.reduce((acc, r) => acc + Number(r[k] || 0), 0);
    host.innerHTML = `
      <div class="chip"><span class="c-label">Bookings</span><span class="c-value">${rows.length}</span></div>
      <div class="chip"><span class="c-label">Total collected</span><span class="c-value">${money(sum("amountPaid"))}</span></div>
      <div class="chip"><span class="c-label">Platform commission</span><span class="c-value purple">${money(sum("commission"))}</span></div>
      <div class="chip"><span class="c-label">Net partner payouts</span><span class="c-value green">${money(sum("netPayout"))}</span></div>`;
  }

  function renderTable() {
    const body = document.getElementById("ledger-table");
    if (!body) return;
    const cols = [
      { key: "id", title: "Booking" },
      { key: "createdAt", title: "Date" },
      { key: "customerName", title: "Customer" },
      { key: "partnerName", title: "Partner" },
      { key: "serviceName", title: "Service" },
      { key: "status", title: "Status" },
      { key: "amountPaid", title: "Amount Paid", right: true },
      { key: "commission", title: "Commission", right: true },
      { key: "netPayout", title: "Net Payout", right: true },
    ];
    const p = paginate(sorted());
    const thead = cols
      .map((c) => {
        const arrow = state.sortKey === c.key ? (state.sortDir === "desc" ? "↓" : "↑") : "";
        return `<th class="sortable ${c.right ? "text-right" : ""}" data-sort="${c.key}">${c.title}<span class="sort-arrow">${arrow}</span></th>`;
      })
      .join("");
    if (p.items.length === 0) {
      body.innerHTML = `<div class="table-wrap"><table class="table"><thead><tr>${thead}</tr></thead></table>
        <div class="table-empty"><div class="icon"><svg width="22" height="22"><use href="#i-box"/></svg></div>No bookings match the current filters.</div></div>`;
      return;
    }
    const tbody = p.items
      .map((r) => `<tr data-id="${r.id}">
        <td><div class="cell-main"><span class="cell-avatar">#</span>
          <div><div><strong>#${r.id}</strong></div><div class="meta">${escapeHtml(r.scheduledAt ? "Scheduled " + fmtDateTime(r.scheduledAt) : "")}</div></div></div></td>
        <td>${fmtDateTime(r.createdAt)}</td>
        <td><div class="cell-main"><span class="cell-avatar">${escapeHtml((r.customerName || "?")[0]?.toUpperCase() || "?")}</span>
          <div><div>${escapeHtml(r.customerName || "—")}</div><div class="meta">${escapeHtml(r.customerPhone || "")}</div></div></div></td>
        <td>${r.partnerName ? `<div><div>${escapeHtml(r.partnerName)}</div><div class="meta">${escapeHtml(r.partnerPhone || "")}</div></div>` : '<span class="muted">—</span>'}</td>
        <td>${escapeHtml(r.serviceName || "—")}</td>
        <td>${badge(r.status)}</td>
        <td class="text-right"><strong>${money(r.amountPaid)}</strong></td>
        <td class="text-right"><span class="muted">${money(r.commission)}</span><div class="meta">${r.commissionPct ?? "—"}%</div></td>
        <td class="text-right"><strong style="color:var(--success)">${money(r.netPayout)}</strong></td>
      </tr>`)
      .join("");
    const pageBtns = [];
    for (let i = Math.max(0, state.page - 2); i < p.pages && i <= state.page + 2; i++) {
      pageBtns.push(`<button class="page-btn ${i === state.page ? "active" : ""}" data-gopage="${i}">${i + 1}</button>`);
    }
    const from = p.total === 0 ? 0 : state.page * state.pageSize + 1;
    const to = Math.min(p.total, (state.page + 1) * state.pageSize);
    body.innerHTML = `
      <div class="table-wrap"><table class="table">
        <thead><tr>${thead}</tr></thead>
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

  function resetFilters() {
    state.from = "";
    state.to = "";
    state.status = "";
    state.customerQ = "";
    state.partnerQ = "";
    document.getElementById("f-from").value = "";
    document.getElementById("f-to").value = "";
    document.getElementById("f-status").value = "";
    document.getElementById("f-customer").value = "";
    document.getElementById("f-partner").value = "";
    state.page = 0;
    load();
    toast("Filters reset — showing all bookings", "info");
  }

  function exportCsv() {
    if (rows.length === 0) {
      toast("Nothing to export — no bookings match the current filters", "warning");
      return;
    }
    exportCsvFile("bookings-ledger", [
      { key: "id", title: "Booking ID", exportValue: (r) => r.id },
      { key: "createdAt", title: "Date", exportValue: (r) => r.createdAt },
      { key: "customerName", title: "Customer Name", exportValue: (r) => r.customerName || "" },
      { key: "customerPhone", title: "Customer Phone", exportValue: (r) => r.customerPhone || "" },
      { key: "partnerName", title: "Partner Name", exportValue: (r) => r.partnerName || "" },
      { key: "partnerPhone", title: "Partner Phone", exportValue: (r) => r.partnerPhone || "" },
      { key: "serviceName", title: "Service", exportValue: (r) => r.serviceName || "" },
      { key: "status", title: "Status", exportValue: (r) => r.status },
      { key: "amountPaid", title: "Amount Paid", exportValue: (r) => Number(r.amountPaid || 0).toFixed(2) },
      { key: "commissionPct", title: "Commission %", exportValue: (r) => r.commissionPct },
      { key: "commission", title: "Commission Amount", exportValue: (r) => Number(r.commission || 0).toFixed(2) },
      { key: "netPayout", title: "Net Partner Payout", exportValue: (r) => Number(r.netPayout || 0).toFixed(2) },
    ], sorted());
    toast(`Exported ${rows.length} bookings to CSV`, "success");
  }

  el.innerHTML = pageHeader(
    "Past Bookings & Financial Ledger",
    "Every booking with the platform commission split and net partner payout.",
    `<button class="btn btn-primary" id="ledger-export">${icon("i-download")} Export to CSV</button>`
  );
  el.innerHTML += `
    <div class="card fade-up" style="margin-bottom:16px">
      <div class="filter-bar" style="padding:16px 16px 6px">
        <div class="field"><label for="f-from">From date</label><input class="input" type="date" id="f-from"></div>
        <div class="field"><label for="f-to">To date</label><input class="input" type="date" id="f-to"></div>
        <div class="field"><label for="f-status">Status</label>
          <select class="select" id="f-status">
            <option value="">All statuses</option>
            ${STATUSES.map((s) => `<option value="${s}">${s.replaceAll("_", " ").toLowerCase().replace(/\b\w/g, (c) => c.toUpperCase())}</option>`).join("")}
          </select></div>
        <div class="field"><label for="f-customer">Customer name / phone / ID</label><input class="input" type="search" id="f-customer" placeholder="Search customer…"></div>
        <div class="field"><label for="f-partner">Partner name / phone / ID</label><input class="input" type="search" id="f-partner" placeholder="Search partner…"></div>
        <div class="filter-actions">
          <button class="btn btn-ghost" id="ledger-reset">${icon("i-reset")} Reset Filters</button>
        </div>
      </div>
    </div>
    <div class="chip-row" id="ledger-chips"></div>
    <div class="card fade-up">
      <div id="ledger-table"></div>
    </div>`;

  document.getElementById("ledger-export").addEventListener("click", exportCsv);
  document.getElementById("ledger-reset").addEventListener("click", resetFilters);
  const onFilter = () => { state.page = 0; load(); };
  document.getElementById("f-from").addEventListener("change", (e) => { state.from = e.target.value; onFilter(); });
  document.getElementById("f-to").addEventListener("change", (e) => { state.to = e.target.value; onFilter(); });
  document.getElementById("f-status").addEventListener("change", (e) => { state.status = e.target.value; onFilter(); });
  const debounceSearch = (input, key) => {
    let t;
    input.addEventListener("input", () => {
      clearTimeout(t);
      t = setTimeout(() => { state[key] = input.value.trim(); onFilter(); }, 300);
    });
  };
  debounceSearch(document.getElementById("f-customer"), "customerQ");
  debounceSearch(document.getElementById("f-partner"), "partnerQ");

  el.querySelector(".card.fade-up").addEventListener("click", (e) => {
    const tableBody = document.getElementById("ledger-table");
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
    }
  });

  load();
});
