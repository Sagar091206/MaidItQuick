/* ============================================================
   MaidItQuick Admin — utils.js
   Formatting, DOM helpers, export (CSV / PDF-print), escape
   ============================================================ */

export function escapeHtml(value) {
  if (value === null || value === undefined) return "";
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

export function initials(name) {
  if (!name) return "?";
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0].toUpperCase())
    .join("");
}

export function money(value) {
  const n = Number(value || 0);
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 2,
  }).format(n);
}

export function number(value) {
  return new Intl.NumberFormat("en-IN").format(Number(value || 0));
}

export function fmtDate(value) {
  if (!value) return "—";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return String(value);
  return d.toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
}

export function fmtDateTime(value) {
  if (!value) return "—";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return String(value);
  return d.toLocaleDateString("en-IN", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function timeAgo(value) {
  if (!value) return "—";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return String(value);
  const secs = Math.floor((Date.now() - d.getTime()) / 1000);
  if (secs < 45) return "just now";
  const mins = Math.floor(secs / 60);
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  const days = Math.floor(hrs / 24);
  if (days < 7) return `${days}d ago`;
  return fmtDate(value);
}

export function debounce(fn, ms = 300) {
  let t;
  return (...args) => {
    clearTimeout(t);
    t = setTimeout(() => fn(...args), ms);
  };
}

export function badgeClass(status) {
  return status ? `st-${String(status).toUpperCase()}` : "";
}

export function stars(rating) {
  const n = Number(rating || 0);
  const full = "★".repeat(Math.max(0, Math.min(5, Math.round(n))));
  const empty = "☆".repeat(Math.max(0, 5 - full.length));
  return `<span class="stars" title="${n.toFixed(1)} / 5">${full}${empty}</span>`;
}

/* ---------- CSV export ---------- */
export function exportCsv(filename, columns, rows) {
  const esc = (v) => {
    if (v === null || v === undefined) return "";
    const s = String(v);
    return /[",\n]/.test(s) ? `"${s.replaceAll('"', '""')}"` : s;
  };
  const head = columns.map((c) => esc(c.title)).join(",");
  const body = rows
    .map((row) => columns.map((c) => esc(c.render ? c.render(row) : row[c.key])).join(","))
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

/* ---------- Print / PDF ---------- */
export function printView(title, subtitle, columns, rows) {
  const esc = escapeHtml;
  const head = columns
    .map((c) => `<th>${esc(c.title)}</th>`)
    .join("");
  const body = rows
    .map(
      (row) =>
        `<tr>${columns
          .map((c) => `<td>${esc(c.print ? c.print(row) : c.render ? c.render(row) : row[c.key])}</td>`)
          .join("")}</tr>`
    )
    .join("");
  const area = document.getElementById("print-area");
  const stamp = new Date().toLocaleString("en-IN");
  area.innerHTML = `
    <div class="print-title">${esc(title)}</div>
    <div class="print-sub">${esc(subtitle)} · Generated ${esc(stamp)}</div>
    <table class="print-table">
      <thead><tr>${head}</tr></thead>
      <tbody>${body}</tbody>
    </table>`;
  document.body.classList.add("printing");
  window.print();
  setTimeout(() => {
    document.body.classList.remove("printing");
    area.innerHTML = "";
  }, 800);
}

/* ---------- Query string helpers ---------- */
export function qs(params) {
  const p = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) {
    if (v !== undefined && v !== null && v !== "") p.set(k, String(v));
  }
  const s = p.toString();
  return s ? `?${s}` : "";
}

export function parseId(raw) {
  const n = Number(raw);
  return Number.isInteger(n) && n > 0 ? n : null;
}

/* ---------- Client-side sorting ---------- */
export function compareValues(a, b) {
  if (a === null || a === undefined) return 1;
  if (b === null || b === undefined) return -1;
  if (typeof a === "number" && typeof b === "number") return a - b;
  return String(a).localeCompare(String(b), "en", { numeric: true, sensitivity: "base" });
}

/* ---------- File download (JSON snapshots) ---------- */
export function downloadJson(filename, data) {
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `${filename}-${new Date().toISOString().slice(0, 10)}.json`;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 2000);
}
