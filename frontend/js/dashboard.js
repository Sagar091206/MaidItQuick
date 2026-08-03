/* ============================================================
   MaidItQuick Admin — dashboard.js
   Operational dashboard (no analytics, no charts).
   - Pending partner KYC queue (review / approve / reject)
   - Today's operations chips
   - Live bookings table (ID, customer, partner, status, ETA,
     location, view details)
   - Recent activities feed
   - Quick actions
   ============================================================ */

import { api, unwrap, pageOf, errorMessage } from "./api.js";
import { registerModule, pageHeader, toast, badge, icon, confirmDialog, openModal, closeTopModal, fetchAllPages } from "./app.js";
import * as auth from "./auth.js";
import { money, number, fmtDateTime, timeAgo, escapeHtml } from "./utils.js";

registerModule("dashboard", async (el) => {
  el.innerHTML = pageHeader(
    "Dashboard",
    "Operations overview — what needs attention right now.",
    `<button class="btn btn-ghost" id="dash-refresh">${icon("i-refresh")} Refresh</button>`
  );
  const wrap = document.createElement("div");
  wrap.id = "dash-wrap";
  wrap.innerHTML = `<div class="state-box"><div class="spinner-inline" style="width:34px;height:34px"></div></div>`;
  el.appendChild(wrap);
  await loadDashboard(wrap, el);
  el.addEventListener("click", (e) => {
    const btn = e.target.closest("[data-goto]");
    if (btn) window.location.hash = `#/${btn.dataset.goto}`;
  });
  document.getElementById("dash-refresh").addEventListener("click", async () => {
    toast("Refreshing dashboard…", "info");
    await loadDashboard(wrap, el);
  });
});

async function loadDashboard(el) {
  el.innerHTML = `<div class="state-box"><div class="spinner-inline" style="width:34px;height:34px"></div></div>`;
  try {
    const [kycCounts, liveBookings, activities] = await Promise.all([
      loadKycCounts(),
      loadLiveBookings(),
      loadActivities(),
    ]);
    renderKycQueue(el, kycCounts);
    renderTodayOps(el);
    renderLiveBookings(el, liveBookings);
    renderActivities(el, activities);
    renderQuickActions(el);
  } catch (err) {
    el.innerHTML = `<div class="state-box">
      <div class="icon"><svg width="28" height="28"><use href="#i-error"/></svg></div>
      <h3>Could not load the dashboard</h3>
      <p>${escapeHtml(errorMessage(err))}</p>
      <button class="btn btn-primary" onclick="location.reload()">Retry</button>
    </div>`;
  }
}

/* ---------------- Pending partner KYC ---------------- */
async function loadKycCounts() {
  const counts = { PENDING: 0, APPROVED: 0, REJECTED: 0 };
  if (!auth.hasPermission("PARTNERS_READ")) return counts;
  try {
    const list = await fetchAllPages("/partners", {});
    for (const p of list) {
      if (counts[p.kycStatus] !== undefined) counts[p.kycStatus]++;
    }
  } catch {
    /* keep zeros */
  }
  return counts;
}

function renderKycQueue(el, c) {
  const seg = document.createElement("section");
  seg.className = "card dash-section fade-up";
  const needsResub = 0;
  seg.innerHTML = `
    <div class="dash-section-head">
      <div>
        <div class="h2">Pending Partner KYC</div>
        <div class="muted" style="margin-top:2px">Partners waiting for identity &amp; address verification</div>
      </div>
      <button class="btn btn-ghost btn-sm" data-goto="kyc">${icon("i-verify")} Open queue</button>
    </div>
    <div class="ops-grid three">
      <div class="ops-tile warn">
        <div class="ops-label">Pending Review</div>
        <div class="ops-value">${number(c.PENDING)}</div>
        <div class="ops-sub">awaiting verification</div>
      </div>
      <div class="ops-tile amber">
        <div class="ops-label">Need Resubmission</div>
        <div class="ops-value">${number(needsResub)}</div>
        <div class="ops-sub">documents to be re-uploaded</div>
      </div>
      <div class="ops-tile danger">
        <div class="ops-label">Rejected</div>
        <div class="ops-value">${number(c.REJECTED)}</div>
        <div class="ops-sub">with feedback sent</div>
      </div>
    </div>
    <div class="ops-actions">
      <button class="btn btn-primary btn-sm" data-goto="kyc">${icon("i-eye")} Review</button>
      <button class="btn btn-success btn-sm" data-goto="kyc">${icon("i-check")} Approve</button>
      <button class="btn btn-danger btn-sm" data-goto="kyc">${icon("i-alert")} Reject</button>
    </div>`;
  el.appendChild(seg);
}

/* ---------------- Today's operations ---------------- */
async function renderTodayOps(el) {
  const seg = document.createElement("section");
  seg.className = "card dash-section fade-up";
  seg.innerHTML = `
    <div class="dash-section-head">
      <div>
        <div class="h2">Today's Operations</div>
        <div class="muted" style="margin-top:2px">Live workload across the platform</div>
      </div>
    </div>
    <div class="ops-chips" id="ops-chips">
      ${Array.from({ length: 9 }).fill(`<div class="skeleton" style="height:74px;border-radius:12px"></div>`).join("")}
    </div>`;
  el.appendChild(seg);
  const host = seg.querySelector("#ops-chips");
  const chips = await Promise.all([
    totalRevenue(),
    totalBookings(),
    todayPaidBookings(),
    liveServices(),
    upcomingServices(),
    completedToday(),
    failedPayments(),
    pendingRefunds(),
    openUserRequests(),
  ]);
  host.innerHTML = chips.map((c) => `
    <a class="ops-chip" href="#/${c.goto}">
      <div class="oc-icon ${c.cls}"><svg width="17" height="17"><use href="#${c.icon}"/></svg></div>
      <div>
        <div class="oc-label">${escapeHtml(c.label)}</div>
        <div class="oc-value">${c.value}</div>
      </div>
    </a>`).join("");
}

async function totalRevenue() {
  const base = { label: "Total Revenue", icon: "i-money", cls: "oc-green", goto: "payments" };
  if (!auth.hasPermission("PAYMENTS_READ")) return { ...base, value: "—" };
  try {
    const page = pageOf(await api.get(`/payments?page=0&size=100`));
    const total = page.items.filter((p) => p.status === "PAID").reduce((s, p) => s + Number(p.amount || 0), 0);
    return { ...base, value: money(total) };
  } catch { return { ...base, value: "—" }; }
}

async function totalBookings() {
  const base = { label: "Total Bookings", icon: "i-bookings", cls: "oc-blue", goto: "bookings" };
  if (!auth.hasPermission("BOOKINGS_READ")) return { ...base, value: "—" };
  try {
    const list = await fetchAllPages("/bookings");
    return { ...base, value: number(list.length) };
  } catch { return { ...base, value: "—" }; }
}

async function todayPaidBookings() {
  const base = { label: "Paid Bookings", icon: "i-bookings", cls: "oc-green", goto: "bookings" };
  if (!auth.hasPermission("PAYMENTS_READ")) return { ...base, value: "—" };
  try {
    const page = pageOf(await api.get(`/payments?page=0&size=100`));
    const paid = page.items.filter((p) => p.status === "PAID").length;
    return { ...base, value: number(paid) };
  } catch { return { ...base, value: "—" }; }
}

async function liveServices() {
  const base = { label: "Live Services", icon: "i-live", cls: "oc-blue", goto: "live-ops" };
  if (!auth.hasPermission("BOOKINGS_READ")) return { ...base, value: "—" };
  try {
    const list = unwrap(await api.get("/bookings/live")) || [];
    return { ...base, value: number(list.filter((b) => b.status === "IN_PROGRESS").length) };
  } catch { return { ...base, value: "—" }; }
}

async function upcomingServices() {
  const base = { label: "Upcoming Services", icon: "i-calendar", cls: "oc-amber", goto: "bookings" };
  if (!auth.hasPermission("BOOKINGS_READ")) return { ...base, value: "—" };
  try {
    const list = unwrap(await api.get("/bookings/live")) || [];
    return { ...base, value: number(list.filter((b) => b.status === "CONFIRMED" || b.status === "PENDING").length) };
  } catch { return { ...base, value: "—" }; }
}

async function completedToday() {
  const base = { label: "Completed Services", icon: "i-check", cls: "oc-green", goto: "bookings" };
  if (!auth.hasPermission("BOOKINGS_READ")) return { ...base, value: "—" };
  try {
    const page = pageOf(await api.get("/bookings?page=0&size=100"));
    const start = new Date();
    start.setHours(0, 0, 0, 0);
    const done = page.items.filter((b) => b.status === "COMPLETED" && b.completedAt && new Date(b.completedAt) >= start);
    return { ...base, value: number(done.length) };
  } catch { return { ...base, value: "—" }; }
}

async function failedPayments() {
  const base = { label: "Failed Payments", icon: "i-error", cls: "oc-red", goto: "payments" };
  if (!auth.hasPermission("PAYMENTS_READ")) return { ...base, value: "—" };
  try {
    const page = pageOf(await api.get(`/payments?page=0&size=100`));
    return { ...base, value: number(page.items.filter((p) => p.status === "FAILED").length) };
  } catch { return { ...base, value: "—" }; }
}

async function pendingRefunds() {
  const base = { label: "Pending Refunds", icon: "i-returns", cls: "oc-amber", goto: "returns" };
  if (!auth.hasPermission("PAYMENTS_READ")) return { ...base, value: "—" };
  try {
    const n = unwrap(await api.get("/returns/pending-count"));
    return { ...base, value: number(n) };
  } catch { return { ...base, value: "—" }; }
}

async function openUserRequests() {
  const base = { label: "Open User Requests", icon: "i-request", cls: "oc-blue", goto: "user-requests" };
  if (!auth.hasPermission("DISPUTES_READ")) return { ...base, value: "—" };
  try {
    const n = unwrap(await api.get("/support-requests/open-count"));
    return { ...base, value: number(n) };
  } catch { return { ...base, value: "—" }; }
}

/* ---------------- Live bookings ---------------- */
async function loadLiveBookings() {
  if (!auth.hasPermission("BOOKINGS_READ")) return null;
  try {
    return unwrap(await api.get("/bookings/live")) || [];
  } catch {
    return null;
  }
}

function renderLiveBookings(el, list) {
  const seg = document.createElement("section");
  seg.className = "card dash-section fade-up";
  seg.innerHTML = `
    <div class="dash-section-head">
      <div>
        <div class="h2">Live Bookings</div>
        <div class="muted" style="margin-top:2px">Active bookings awaiting or in service</div>
      </div>
      <button class="btn btn-ghost btn-sm" data-goto="bookings">${icon("i-bookings")} All bookings</button>
    </div>`;
  const body = document.createElement("div");
  body.id = "dash-live-table";
  seg.appendChild(body);
  el.appendChild(seg);

  if (list === null) {
    body.innerHTML = `<div class="muted" style="padding:18px">No booking permissions.</div>`;
    return;
  }
  if (list.length === 0) {
    body.innerHTML = `<div class="table-empty"><div class="icon"><svg width="22" height="22"><use href="#i-bookings"/></svg></div>No live bookings right now.</div>`;
    return;
  }
  body.innerHTML = `<div class="table-wrap"><table class="table">
    <thead><tr>
      <th>Booking ID</th><th>Customer</th><th>Partner</th><th>Status</th>
      <th>ETA</th><th>Current Location</th><th class="text-right">Action</th>
    </tr></thead>
    <tbody>${list.map((b) => `
      <tr data-id="${b.id}">
        <td class="mono">#${b.id}</td>
        <td><div class="cell-main"><span class="cell-avatar">${escapeHtml((b.customer?.name || "?")[0]?.toUpperCase() || "?")}</span>
          <div><div>${escapeHtml(b.customer?.name || "—")}</div><div class="meta">${escapeHtml(b.customer?.phone || "")}</div></div></div></td>
        <td>${escapeHtml(b.partner?.name || "—")}</td>
        <td>${badge(b.status)}</td>
        <td>${b.scheduledAt ? fmtDateTime(b.scheduledAt) : "—"}</td>
        <td class="muted ellipsis" style="max-width:210px" title="${escapeHtml(b.address || "")}">
          ${b.latitude && b.longitude ? `<span class="map-dot" title="Coordinates available"></span>` : ""}
          ${escapeHtml(b.address || "—")}
        </td>
        <td class="text-right"><button class="btn btn-ghost btn-sm" data-view>${icon("i-eye")} View Details</button></td>
      </tr>`).join("")}</tbody></table></div>`;
  body.querySelectorAll("[data-view]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const row = list.find((b) => b.id === Number(btn.closest("tr").dataset.id));
      if (row) openBookingDetails(row);
    });
  });
}

async function openBookingDetails(row) {
  let b = row;
  try {
    b = unwrap(await api.get(`/bookings/${row.id}`)) || row;
  } catch { /* keep row */ }
  const timeline = [
    ["Created", b.createdAt],
    ["Started", b.startedAt],
    ["Completed", b.completedAt],
  ].filter(([, v]) => v);
  openModal({
    title: `Booking #${b.id}`,
    body: `
      <div class="kv-grid" style="margin-bottom:14px">
        <div class="kv"><span>Status</span><strong>${badge(b.status)}</strong></div>
        <div class="kv"><span>Customer</span><strong>${escapeHtml(b.customer?.name || "—")}</strong></div>
        <div class="kv"><span>Partner</span><strong>${escapeHtml(b.partner?.name || "—")}</strong></div>
        <div class="kv"><span>Service</span><strong>${escapeHtml(b.service?.name || "—")}</strong></div>
        <div class="kv"><span>Amount</span><strong>${money(b.totalAmount)}</strong></div>
        <div class="kv"><span>Scheduled</span><strong>${b.scheduledAt ? fmtDateTime(b.scheduledAt) : "—"}</strong></div>
        <div class="kv" style="grid-column:1/-1"><span>Address</span><strong>${escapeHtml(b.address || "—")}</strong></div>
        ${b.latitude && b.longitude ? `<div class="kv" style="grid-column:1/-1"><span>Location</span><strong class="mono">${Number(b.latitude).toFixed(6)}, ${Number(b.longitude).toFixed(6)}</strong></div>` : ""}
      </div>
      ${timeline.length ? `
        <h4 style="margin:0 0 10px">Timeline</h4>
        <div class="timeline" style="padding-left:26px">
          ${timeline.map(([l, v]) => `<div class="tl-item"><div class="t-title">${escapeHtml(l)}</div>
            <div class="t-meta"><span>${fmtDateTime(v)}</span></div></div>`).join("")}
        </div>` : ""}
    `,
    footer: `<button class="btn btn-ghost" data-close>Close</button>
      <a class="btn btn-primary" href="#/bookings">Open Bookings</a>`,
    size: "lg",
  });
  const overlay = [...document.querySelectorAll(".modal-overlay")].at(-1);
  overlay.querySelector("[data-close]").addEventListener("click", closeTopModal);
}

/* ---------------- Recent activities ---------------- */
const ACTIVITY_ICONS = {
  CUSTOMER_CREATED: ["i-customers", "New Customer"],
  PARTNER_CREATED: ["i-partner", "New Partner"],
  PARTNER_APPROVED: ["i-check", "Partner Approved"],
  BOOKING_CREATED: ["i-bookings", "Booking Created"],
  PAYMENT_CREATED: ["i-payments", "Payment Recorded"],
  BOOKING_REFUNDED: ["i-returns", "Refund Raised"],
  BOOKING_STATUS_CHANGED: ["i-live", "Booking Updated"],
  BOOKING_ESCALATED: ["i-alert", "Booking Escalated"],
  CUSTOMER_STATUS_CHANGED: ["i-customers", "Customer Status Changed"],
  DISPUTE_CREATED: ["i-request", "Support Request Opened"],
  DISPUTE_RESOLVED: ["i-request", "Support Request Resolved"],
  NOTIFICATION_SENT: ["i-bell", "Notification Sent"],
};

function activityMeta(a) {
  if (a.action === "BOOKING_STATUS_CHANGED") {
    try {
      const nv = JSON.parse(a.newValue || "{}");
      if (nv.status === "COMPLETED") return ["i-check", "Booking Completed"];
      if (nv.status === "CANCELLED") return ["i-error", "Booking Cancelled"];
    } catch { /* ignore */ }
  }
  return ACTIVITY_ICONS[a.action] || ["i-clock", a.action ? a.action.replaceAll("_", " ").toLowerCase().replace(/\b\w/g, (c) => c.toUpperCase()) : "Activity"];
}

async function loadActivities() {
  if (!auth.hasPermission("AUDIT_READ")) return null;
  try {
    const page = pageOf(await api.get("/audit?page=0&size=40"));
    const relevant = Object.keys(ACTIVITY_ICONS);
    return page.items.filter((a) => relevant.includes(a.action) || a.action === "BOOKING_STATUS_CHANGED").slice(0, 12);
  } catch {
    return null;
  }
}

function renderActivities(el, items) {
  const seg = document.createElement("section");
  seg.className = "card dash-section fade-up";
  seg.innerHTML = `
    <div class="dash-section-head">
      <div>
        <div class="h2">Recent Activities</div>
        <div class="muted" style="margin-top:2px">Latest platform events</div>
      </div>
      <button class="btn btn-ghost btn-sm" data-goto="audit">${icon("i-audit")} Audit logs</button>
    </div>`;
  const body = document.createElement("div");
  body.className = "activity-list";
  seg.appendChild(body);
  el.appendChild(seg);

  if (items === null) {
    body.innerHTML = `<div class="muted" style="padding:18px">No audit permissions.</div>`;
    return;
  }
  if (items.length === 0) {
    body.innerHTML = `<div class="table-empty"><div class="icon"><svg width="22" height="22"><use href="#i-clock"/></svg></div>No recent activity yet.</div>`;
    return;
  }
  body.innerHTML = items.map((a) => {
    const [ic, label] = activityMeta(a);
    return `<div class="activity-item">
      <div class="ai-icon"><svg width="16" height="16"><use href="#${ic}"/></svg></div>
      <div class="ai-body">
        <div class="ai-title">${escapeHtml(label)}</div>
        <div class="ai-meta">${escapeHtml(a.module || "")}${a.recordId ? ` · #${escapeHtml(a.recordId)}` : ""}</div>
      </div>
      <div class="ai-time">${timeAgo(a.occurredAt)}</div>
    </div>`;
  }).join("");
}

/* ---------------- Quick actions ---------------- */
function renderQuickActions(el) {
  const seg = document.createElement("section");
  seg.className = "card dash-section fade-up";
  const actions = [
    auth.hasPermission("PARTNERS_WRITE") ? ["kyc", "i-verify", "Approve Partner", "Review pending KYC"] : null,
    auth.hasPermission("PARTNERS_WRITE") ? ["partners", "i-partner", "Add Partner", "Onboard a new partner"] : null,
    auth.hasPermission("CUSTOMERS_WRITE") ? ["customers", "i-customers", "Add Customer", "Create a customer record"] : null,
    auth.hasPermission("NOTIFICATIONS_WRITE") ? ["notifications", "i-bell", "Broadcast Notification", "Send a platform alert"] : null,
    auth.hasPermission("REPORTS_VIEW") ? ["reports", "i-reports", "Export Reports", "Download data exports"] : null,
  ].filter(Boolean);
  seg.innerHTML = `
    <div class="dash-section-head">
      <div>
        <div class="h2">Quick Actions</div>
        <div class="muted" style="margin-top:2px">Common operations</div>
      </div>
    </div>
    <div class="qa-grid">
      ${actions.map(([goto, ic, label, sub]) => `
        <a class="qa-item" href="#/${goto}">
          <div class="qa-icon"><svg width="18" height="18"><use href="#${ic}"/></svg></div>
          <div>
            <div class="qa-label">${escapeHtml(label)}</div>
            <div class="qa-sub">${escapeHtml(sub)}</div>
          </div>
        </a>`).join("")}
    </div>`;
  el.appendChild(seg);
}
