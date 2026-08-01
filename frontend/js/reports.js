/* ============================================================
   MaidItQuick Admin â€” reports.js
   Revenue / bookings analytics with exportable charts
   ============================================================ */

import { api, unwrap, errorMessage } from "./api.js";
import { registerModule, pageHeader, toast, icon, exportCsvFile, printReport } from "./app.js";
import { escapeHtml, money, number } from "./utils.js";

registerModule("reports", async (el) => {
  el.innerHTML = pageHeader(
    "Reports",
    "Revenue and booking analytics.",
    `<button class="btn btn-ghost" id="rep-refresh">${icon("i-refresh")} Refresh</button>`
  );

  const wrap = document.createElement("div");
  wrap.id = "rep-wrap";
  wrap.innerHTML = `<div class="state-box"><div class="spinner-inline" style="width:34px;height:34px"></div></div>`;
  el.appendChild(wrap);

  document.getElementById("rep-refresh").addEventListener("click", load);

  async function load() {
    wrap.innerHTML = `<div class="state-box"><div class="spinner-inline" style="width:34px;height:34px"></div></div>`;
    try {
      const [total, revenue, byStatus, top] = await Promise.all([
        api.get("/reports/revenue-total"),
        api.get("/reports/revenue-by-month"),
        api.get("/reports/bookings-by-status"),
        api.get("/reports/top-services"),
      ]);
      const t = unwrap(total) || {};
      const months = unwrap(revenue) || [];
      const statuses = unwrap(byStatus) || [];
      const services = unwrap(top) || [];

      wrap.innerHTML = `
        <div class="report-grid fade-up">
          ${bigCard("Total revenue", money(t.totalRevenue), "ic-green", "i-money")}
          ${bigCard("Paid payments", number(t.paidPayments), "ic-indigo", "i-payments")}
          ${bigCard("Pending payments", number(t.pendingPayments), "ic-amber", "i-clock")}
          ${bigCard("Average rating", t.averageRating ? `${Number(t.averageRating).toFixed(2)} / 5` : "â€”", "ic-cyan", "i-star")}
        </div>

        <div class="report-chart-grid">
          <div class="card chart-card">
            <div class="c-head">
              <div>
                <div class="c-title">Monthly revenue</div>
                <div class="c-sub">Last 12 months Â· paid payments</div>
              </div>
              <button class="btn btn-ghost btn-sm" data-csv="revenue">${icon("i-download")} CSV</button>
            </div>
            <div class="chart-wrap">${areaChart(months.map((m) => m.month), months.map((m) => Number(m.revenue) || 0))}</div>
          </div>
          <div class="card chart-card">
            <div class="c-head">
              <div>
                <div class="c-title">Bookings by status</div>
                <div class="c-sub">Current pipeline distribution</div>
              </div>
              <button class="btn btn-ghost btn-sm" data-csv="status">${icon("i-download")} CSV</button>
            </div>
            <div class="chart-wrap">${statusChart(statuses)}</div>
          </div>
        </div>

        <div class="card card-pad report-full fade-up">
          <div class="flex-between" style="margin-bottom:18px">
            <div>
              <div class="h2">Top services</div>
              <div class="muted" style="margin-top:2px">By number of bookings</div>
            </div>
            <button class="btn btn-ghost btn-sm" data-csv="top">${icon("i-download")} CSV</button>
          </div>
          ${rankList(services)}
        </div>`;

      wrap.querySelector('[data-csv="revenue"]').addEventListener("click", () =>
        exportCsvFile("monthly-revenue", [
          { key: "month", title: "Month" },
          { key: "revenue", title: "Revenue" },
        ], months)
      );
      wrap.querySelector('[data-csv="status"]').addEventListener("click", () =>
        exportCsvFile("bookings-by-status", [
          { key: "status", title: "Status" },
          { key: "count", title: "Count" },
        ], statuses)
      );
      wrap.querySelector('[data-csv="top"]').addEventListener("click", () =>
        exportCsvFile("top-services", [
          { key: "service", title: "Service" },
          { key: "bookings", title: "Bookings" },
        ], services)
      );
    } catch (err) {
      wrap.innerHTML = `<div class="state-box">
        <div class="icon"><svg width="28" height="28"><use href="#i-error"/></svg></div>
        <h3>Could not load reports</h3>
        <p>${escapeHtml(errorMessage(err))}</p>
      </div>`;
    }
  }

  function bigCard(label, value, ic, iconName) {
    return `
      <div class="card card-pad">
        <div class="s-icon ${ic}" style="width:38px;height:38px;margin-bottom:14px">
          <svg width="19" height="19"><use href="#${iconName}"/></svg>
        </div>
        <div class="big-number">${value}</div>
        <div class="big-label">${label}</div>
      </div>`;
  }

  function areaChart(labels, values) {
    const W = 640, H = 240, PL = 52, PR = 14, PT = 16, PB = 30;
    const max = Math.max(...values, 1);
    const x = (i) => PL + (labels.length === 1 ? (W - PL - PR) / 2 : (i / (labels.length - 1)) * (W - PL - PR));
    const y = (v) => PT + (H - PT - PB) - (v / max) * (H - PT - PB);
    let g = "";
    for (let t = 0; t <= 4; t++) {
      const v = (max * t) / 4;
      const yy = y(v);
      g += `<line x1="${PL}" y1="${yy}" x2="${W - PR}" y2="${yy}" stroke="rgba(255,255,255,.06)"/>
        <text x="${PL - 8}" y="${yy + 4}" text-anchor="end" font-size="10.5" fill="var(--text-3)">${short(v)}</text>`;
    }
    const line = values.map((v, i) => `${x(i)},${y(v)}`).join(" ");
    const area = `${PL},${H - PB} ${line} ${x(values.length - 1)},${H - PB}`;
    return `<svg class="chart-svg" viewBox="0 0 ${W} ${H}">
      <defs><linearGradient id="rep-g" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" stop-color="var(--accent-2)" stop-opacity="0.35"/>
        <stop offset="100%" stop-color="var(--accent-2)" stop-opacity="0.02"/>
      </linearGradient></defs>
      ${g}
      <polygon points="${area}" fill="url(#rep-g)"/>
      <polyline points="${line}" fill="none" stroke="var(--accent-2)" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="filter:drop-shadow(0 4px 10px rgba(34,211,238,.4))"/>
      ${values.map((v, i) => `<circle cx="${x(i)}" cy="${y(v)}" r="3.5" fill="var(--accent-2)"><title>${escapeHtml(labels[i])}: ${money(v)}</title></circle>`).join("")}
      ${labels.map((l, i) => `<text x="${x(i)}" y="${H - 8}" text-anchor="middle" font-size="10" fill="var(--text-3)">${l}</text>`).join("")}
    </svg>`;
  }

  function statusChart(statuses) {
    const order = ["PENDING", "CONFIRMED", "IN_PROGRESS", "COMPLETED", "CANCELLED"];
    const counts = new Map(statuses.map((s) => [s.status, Number(s.count)]));
    const labels = order.filter((o) => counts.has(o));
    const values = labels.map((l) => counts.get(l));
    const colors = {
      PENDING: "var(--warning)",
      CONFIRMED: "var(--info)",
      IN_PROGRESS: "var(--accent)",
      COMPLETED: "var(--success)",
      CANCELLED: "var(--danger)",
    };
    if (labels.length === 0) return `<div class="muted" style="padding:40px;text-align:center">No bookings yet.</div>`;
    const W = 640, H = 240, PL = 40, PR = 12, PT = 26, PB = 30;
    const max = Math.max(...values, 1);
    const step = (W - PL - PR) / labels.length;
    const bw = Math.min(46, step * 0.55);
    let g = "";
    for (let t = 0; t <= 4; t++) {
      const v = (max * t) / 4;
      const yy = PT + (H - PT - PB) - (v / max) * (H - PT - PB);
      g += `<line x1="${PL}" y1="${yy}" x2="${W - PR}" y2="${yy}" stroke="rgba(255,255,255,.06)"/>
        <text x="${PL - 8}" y="${yy + 4}" text-anchor="end" font-size="10.5" fill="var(--text-3)">${short(v)}</text>`;
    }
    const bars = values
      .map((v, i) => {
        const cx = PL + step * i + step / 2;
        const h = (v / max) * (H - PT - PB);
        const yTop = PT + (H - PT - PB) - h;
        return `<rect x="${cx - bw / 2}" y="${yTop}" width="${bw}" height="${Math.max(h, 2)}" rx="7" fill="${colors[labels[i]]}" opacity="0.9">
            <title>${escapeHtml(labels[i])}: ${v}</title></rect>
          <text x="${cx}" y="${yTop - 7}" text-anchor="middle" font-size="11" font-weight="700" fill="var(--text-2)">${v}</text>
          <text x="${cx}" y="${H - 8}" text-anchor="middle" font-size="9.5" fill="var(--text-3)">${escapeHtml(labels[i].replace("_", " "))}</text>`;
      })
      .join("");
    return `<svg class="chart-svg" viewBox="0 0 ${W} ${H}">${g}${bars}</svg>`;
  }

  function rankList(services) {
    if (services.length === 0) return `<div class="muted" style="text-align:center;padding:20px">No booking data yet.</div>`;
    const max = Math.max(...services.map((s) => Number(s.bookings) || 0), 1);
    return `<div class="rank-list">${services
      .map(
        (s, i) => `
      <div class="rank-item">
        <div class="r-top">
          <div class="r-name"><span class="muted mono" style="min-width:16px">${i + 1}</span>${escapeHtml(s.service)}</div>
          <div class="r-count">${number(s.bookings)} bookings</div>
        </div>
        <div class="r-bar"><div class="r-fill" style="width:${Math.max(4, (Number(s.bookings) / max) * 100)}%"></div></div>
      </div>`
      )
      .join("")}</div>`;
  }

  function short(v) {
    if (v >= 1_000_000) return `${(v / 1_000_000).toFixed(1)}M`;
    if (v >= 1_000) return `${(v / 1_000).toFixed(1)}k`;
    return String(Math.round(v));
  }

  load();
});
