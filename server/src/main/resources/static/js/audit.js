/* ============================================================
   MaidItQuick Admin â€” audit.js
   Audit trail (server-paginated, raw Spring Page shape)
   ============================================================ */

import { api, pageOf, errorMessage } from "./api.js";
import { registerModule, pageHeader, icon, exportCsvFile, printReport } from "./app.js";
import { escapeHtml, fmtDateTime } from "./utils.js";

registerModule("audit", async (el) => {
  let state = { page: 0, size: 20 };
  let page = { items: [], total: 0, totalPages: 0 };

  async function load() {
    el.innerHTML = pageHeader(
      "Audit Logs",
      "A chronological trail of every administrative action.",
      `<button class="btn btn-ghost" id="aud-csv">${icon("i-download")} CSV</button>
       <button class="btn btn-ghost" id="aud-print">${icon("i-print")} Print</button>`
    );
    const card = document.createElement("div");
    card.className = "card fade-up";
    card.id = "aud-card";
    card.innerHTML = `<div class="state-box"><div class="spinner-inline" style="width:30px;height:30px"></div></div>`;
    el.appendChild(card);

    document.getElementById("aud-csv").addEventListener("click", () =>
      exportCsvFile("audit-logs", [
        { key: "occurredAt", title: "Time" },
        { key: "adminId", title: "Admin ID" },
        { key: "module", title: "Module" },
        { key: "action", title: "Action" },
        { key: "recordId", title: "Record" },
        { key: "ipAddress", title: "IP" },
      ], page.items)
    );
    document.getElementById("aud-print").addEventListener("click", () =>
      printReport("Audit Logs â€” MaidItQuick Admin", "Administrative actions", [
        { title: "Time", printValue: (a) => fmtDateTime(a.occurredAt) },
        { title: "Admin", printValue: (a) => `#${a.adminId || "?"}` },
        { title: "Module", printValue: (a) => a.module },
        { title: "Action", printValue: (a) => a.action },
        { title: "Record", printValue: (a) => a.recordId || "" },
        { title: "IP", printValue: (a) => a.ipAddress },
      ], page.items)
    );

    try {
      const payload = await api.get(`/audit?page=${state.page}&size=${state.size}`);
      page = pageOf(payload);
      render();
    } catch (err) {
      card.innerHTML = `<div class="state-box"><p class="muted">${escapeHtml(errorMessage(err))}</p></div>`;
    }
  }

  function humanAction(action) {
    return String(action || "")
      .toLowerCase()
      .split("_")
      .map((w) => w[0].toUpperCase() + w.slice(1))
      .join(" ");
  }

  function render() {
    const card = document.getElementById("aud-card");
    if (page.items.length === 0) {
      card.innerHTML = `<div class="table-empty" style="padding:56px"><div class="icon"><svg width="22" height="22"><use href="#i-audit"/></svg></div>No activity recorded yet.</div>`;
      return;
    }
    card.innerHTML = `
      <div class="table-wrap"><table class="table">
        <thead><tr>
          <th>When</th><th>Admin</th><th>Module</th><th>Action</th><th>Record</th><th>Payload changes</th><th class="text-right">Source</th>
        </tr></thead>
        <tbody>${page.items
          .map(
            (a) => `<tr>
              <td class="muted" style="white-space:nowrap">${fmtDateTime(a.occurredAt)}</td>
              <td><span class="mono">#${a.adminId || "â€”"}</span></td>
              <td><span class="badge st-gray badge-gray">${escapeHtml(a.module)}</span></td>
              <td><strong>${escapeHtml(humanAction(a.action))}</strong></td>
              <td class="mono muted">${escapeHtml(a.recordId || "â€”")}</td>
              <td>
                <div style="display:flex;gap:6px;align-items:center">
                  ${a.previousValue ? `<details class="pre" style="max-width:170px"><summary style="cursor:pointer;font-size:10.5px">before</summary>${escapeHtml(a.previousValue)}</details>` : ""}
                  ${a.newValue ? `<details class="pre" style="max-width:170px"><summary style="cursor:pointer;font-size:10.5px">after</summary>${escapeHtml(a.newValue)}</details>` : '<span class="muted">â€”</span>'}
                </div>
              </td>
              <td class="text-right">
                <div class="muted ellipsis" title="${escapeHtml(a.browser || "")}" style="max-width:200px;margin-left:auto">
                  ${escapeHtml(a.ipAddress || "â€”")}${a.browser ? ` Â· ${escapeHtml((a.browser || "").slice(0, 40))}${a.browser.length > 40 ? "â€¦" : ""}` : ""}
                </div>
              </td>
            </tr>`
          )
          .join("")}
        </tbody></table></div>
      <div class="pager">
        <div class="pager-info">Page ${page.page + 1} of ${Math.max(1, page.totalPages)} Â· ${page.total} records</div>
        <div class="pager-pages">
          <button class="page-btn" data-pg="${state.page - 1}" ${state.page === 0 ? "disabled" : ""}>â€¹</button>
          <button class="page-btn active">${state.page + 1}</button>
          <button class="page-btn" data-pg="${state.page + 1}" ${state.page >= page.totalPages - 1 ? "disabled" : ""}>â€º</button>
        </div>
        <div class="page-size">
          <span>Rows</span>
          <select class="select" data-size>
            ${[10, 20, 50, 100].map((s) => `<option value="${s}" ${s === state.size ? "selected" : ""}>${s}</option>`).join("")}
          </select>
        </div>
      </div>`;

    card.querySelectorAll("[data-pg]").forEach((btn) =>
      btn.addEventListener("click", () => {
        const p = Number(btn.dataset.pg);
        if (p >= 0 && p < page.totalPages) {
          state.page = p;
          load();
        }
      })
    );
    card.querySelector("[data-size]").addEventListener("change", (e) => {
      state.size = Number(e.target.value);
      state.page = 0;
      load();
    });
  }

  await load();
});
