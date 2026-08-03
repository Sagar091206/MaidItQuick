/* ============================================================
   MaidItQuick Admin — live-ops.js
   Real-time operations: interactive map + live status feed.
   - Green pins: available partners
   - Blue pins: partners on an active booking
   - Red pins: live customer service requests
   - Live feed with status stages + running timers
   - Booking escalation modal with emergency support
   ============================================================ */

import { api, unwrap, errorMessage } from "./api.js";
import * as auth from "./auth.js";
import {
  registerModule, pageHeader, toast, openModal, closeTopModal,
  confirmDialog, badge, icon,
} from "./app.js";
import { escapeHtml, fmtDateTime, money } from "./utils.js";

const STAGE_ORDER = { PENDING: 1, CONFIRMED: 2, IN_PROGRESS: 3 };
const STAGES = ["Requested", "Accepted by Partner", "In-Progress / Maid Arrived", "Service Completed"];
const STATUS_STAGE = { PENDING: 1, CONFIRMED: 2, IN_PROGRESS: 3, COMPLETED: 4 };

function loadLeaflet() {
  return new Promise((resolve) => {
    if (window.L) return resolve(true);
    const s = document.createElement("script");
    s.src = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.js";
    s.onload = () => resolve(true);
    s.onerror = () => resolve(false);
    document.head.appendChild(s);
  });
}

registerModule("live-ops", async (el) => {
  const canWrite = auth.hasPermission("BOOKINGS_WRITE");
  let bookings = [];
  let partners = [];
  let map = null;
  let layerGroup = null;
  let timerInt = null;
  let polling = false;

  clearInterval(window.__livePoll);
  window.__livePoll = null;

  el.innerHTML = pageHeader(
    "Live Operations & Dispatch",
    "Active partner pins, live customer requests and in-flight bookings on one map.",
    ``
  );
  el.innerHTML += `
    <div class="live-layout">
      <div class="card fade-up" style="padding:0">
        <div class="map-legend">
          <span class="lg"><span class="map-pin green"></span> Available partner</span>
          <span class="lg"><span class="map-pin blue"></span> Partner on active booking</span>
          <span class="lg"><span class="map-pin red"></span> Live customer request</span>
          <span class="toolbar-spacer"></span>
          <button class="btn btn-ghost btn-sm" id="live-refresh">${icon("i-refresh")} Refresh</button>
        </div>
        <div id="live-map"></div>
      </div>
      <div class="card fade-up">
        <div style="display:flex;align-items:center;justify-content:space-between;padding:14px 16px 10px">
          <div class="h2" style="font-size:15px">Live bookings</div>
          <span class="muted" id="live-count" style="font-size:12px"></span>
        </div>
        <div class="feed-list" id="live-feed"></div>
      </div>
    </div>`;

  const mapEl = document.getElementById("live-map");

  async function poll() {
    if (polling || document.hidden) return;
    polling = true;
    try {
      const [liveRes, partnerRes] = await Promise.all([
        api.get("/bookings/live"),
        api.get("/partners?status=APPROVED&size=100"),
      ]);
      bookings = unwrap(liveRes) || [];
      partners = unwrap(partnerRes)?.items || [];
      renderFeed();
      renderMap();
    } catch (err) {
      toast(errorMessage(err), "error");
    } finally {
      polling = false;
    }
  }

  function stageSteps(booking) {
    const current = STATUS_STAGE[booking.status] || 1;
    return STAGES.map((label, i) => {
      const step = i + 1;
      const cls = step < current ? "done" : step === current ? "current" : "";
      return `<div class="stage-step ${cls}">${escapeHtml(label)}</div>`;
    }).join("");
  }

  function timerBase(booking) {
    return booking.startedAt || booking.createdAt;
  }

  function formatElapsed(booking) {
    const start = new Date(timerBase(booking)).getTime();
    if (Number.isNaN(start)) return "—";
    let secs = Math.max(0, Math.floor((Date.now() - start) / 1000));
    const h = Math.floor(secs / 3600);
    const m = Math.floor((secs % 3600) / 60);
    const s = secs % 60;
    const pad = (n) => String(n).padStart(2, "0");
    return `${h > 0 ? pad(h) + ":" : ""}${pad(m)}:${pad(s)}`;
  }

  function renderFeed() {
    const host = document.getElementById("live-feed");
    const countEl = document.getElementById("live-count");
    const sorted = [...bookings].sort(
      (a, b) => (STAGE_ORDER[a.status] || 4) - (STAGE_ORDER[b.status] || 4)
    );
    countEl.textContent = `${sorted.length} active`;
    if (sorted.length === 0) {
      host.innerHTML = `<div class="table-empty"><div class="icon"><svg width="22" height="22"><use href="#i-box"/></svg></div>No live bookings right now.</div>`;
      return;
    }
    host.innerHTML = sorted
      .map(
        (b) => `<div class="feed-card" data-bid="${b.id}">
          <div class="f-top">
            <span class="f-title">Booking #${b.id} — ${escapeHtml(b.service?.name || "Service")}</span>
            <span class="timer-chip" data-timer="${b.id}">${icon("i-clock")} ${formatElapsed(b)}</span>
          </div>
          <div class="f-addr">${escapeHtml(b.address || "")}</div>
          <div class="f-people">
            <span><b>Customer:</b> ${escapeHtml(b.customer?.name || "—")}</span>
            <span><b>Partner:</b> ${escapeHtml(b.partner?.name || "Unassigned")}</span>
          </div>
          ${stageSteps(b)}
        </div>`
      )
      .join("");
    host.querySelectorAll(".feed-card").forEach((card) => {
      card.addEventListener("click", () => {
        const b = bookings.find((x) => x.id === Number(card.dataset.bid));
        if (b) openBooking(b);
      });
    });
  }

  async function renderMap() {
    const ready = await loadLeaflet();
    const mapEl2 = document.getElementById("live-map");
    if (!mapEl2) return;
    if (!ready) {
      mapEl2.innerHTML = `<div class="table-empty"><div class="icon"><svg width="22" height="22"><use href="#i-pin"/></svg></div>
        Map tiles are unavailable (Leaflet CDN unreachable). The live feed below still works.</div>`;
      return;
    }
    if (!map) {
      map = L.map(mapEl2, { scrollWheelZoom: false }).setView([19.076, 72.8777], 11);
      L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
        maxZoom: 18,
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
      }).addTo(map);
      map.on("click", () => {
        if (map.scrollWheelZoom.enabled()) map.scrollWheelZoom.disable();
      });
      map.on("dblclick", () => map.scrollWheelZoom.enable());
    }
    if (layerGroup) layerGroup.clearLayers();
    layerGroup = L.layerGroup().addTo(map);

    const onBookingPartnerIds = new Set(
      bookings
        .filter((b) => ["CONFIRMED", "IN_PROGRESS"].includes(b.status) && b.partner)
        .map((b) => b.partner.id)
    );

    partners
      .filter((p) => p.latitude != null && p.longitude != null)
      .forEach((p) => {
        const onBooking = onBookingPartnerIds.has(p.id);
        const pin = L.circleMarker([p.latitude, p.longitude], {
          radius: 9,
          color: "#ffffff",
          weight: 2,
          fillColor: onBooking ? "#2563eb" : "#16a34a",
          fillOpacity: 1,
        }).addTo(layerGroup);
        pin.bindPopup(
          `<div class="lp-title">${escapeHtml(p.name)}</div>
           <div class="lp-sub">${onBooking ? "On an active booking" : "Available"}</div>
           <div class="lp-sub">${escapeHtml(p.phone || "")}</div>`
        );
      });

    bookings
      .filter((b) => b.latitude != null && b.longitude != null)
      .forEach((b) => {
        const pin = L.circleMarker([b.latitude, b.longitude], {
          radius: 9,
          color: "#ffffff",
          weight: 2,
          fillColor: "#dc2626",
          fillOpacity: 1,
        }).addTo(layerGroup);
        pin.bindPopup(
          `<div class="lp-title">Request #${b.id} — ${escapeHtml(b.customer?.name || "Customer")}</div>
           <div class="lp-sub">${escapeHtml(b.service?.name || "")} · ${money(b.totalAmount)}</div>
           <div class="lp-sub">${escapeHtml(b.address || "")}</div>`
        );
        pin.on("click", () => openBooking(b));
      });

    const latlngs = layerGroup.getLayers().map((l) => l.getLatLng());
    if (latlngs.length > 0) map.fitBounds(L.latLngBounds(latlngs).pad(0.25));
  }

  function openBooking(b) {
    const start = new Date(timerBase(b)).getTime();
    const body = `
      <div class="big-timer" id="esc-timer" data-base="${Number.isNaN(start) ? "" : start}">${formatElapsed(b)}</div>
      <div class="kv-grid">
        <div class="kv"><span>Customer</span><strong>${escapeHtml(b.customer?.name || "—")}</strong></div>
        <div class="kv"><span>Customer phone</span><strong>${escapeHtml(b.customer?.phone || "—")}</strong></div>
        <div class="kv"><span>Partner</span><strong>${escapeHtml(b.partner?.name || "Unassigned")}</strong></div>
        <div class="kv"><span>Partner phone</span><strong>${escapeHtml(b.partner?.phone || "—")}</strong></div>
        <div class="kv"><span>Service</span><strong>${escapeHtml(b.service?.name || "—")}</strong></div>
        <div class="kv"><span>Amount</span><strong>${money(b.totalAmount)}</strong></div>
        <div class="kv" style="grid-column:1/-1"><span>Status</span><strong>${badge(b.status)}</strong></div>
        <div class="kv" style="grid-column:1/-1"><span>Service address</span><strong>${escapeHtml(b.address || "—")}</strong></div>
        <div class="kv" style="grid-column:1/-1"><span>Requested at</span><strong>${fmtDateTime(b.createdAt)}</strong></div>
      </div>
      ${canWrite ? `
        <div class="emergency-box" id="esc-btn" role="button" tabindex="0">
          ${icon("i-alert")} Emergency support for this booking
        </div>` : ""}`;
    openModal({
      title: `Booking #${b.id} — live escalation`,
      body,
      footer: `<button class="btn btn-ghost" data-close>Close</button>`,
      size: "lg",
    });
    const overlay = [...document.querySelectorAll(".modal-overlay")].at(-1);
    overlay.querySelector("[data-close]").addEventListener("click", closeTopModal);
    const escBtn = overlay.querySelector("#esc-btn");
    if (escBtn) escBtn.addEventListener("click", () => escalate(b));
    const timerEl = overlay.querySelector("#esc-timer");
    if (timerEl && timerEl.dataset.base) {
      const tick = setInterval(() => {
        if (!document.body.contains(timerEl)) { clearInterval(tick); return; }
        const el = document.getElementById("esc-timer");
        if (!el) { clearInterval(tick); return; }
        const base = Number(el.dataset.base);
        let secs = Math.max(0, Math.floor((Date.now() - base) / 1000));
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        const s = secs % 60;
        const pad = (n) => String(n).padStart(2, "0");
        el.textContent = `${h > 0 ? pad(h) + ":" : ""}${pad(m)}:${pad(s)}`;
      }, 1000);
    }
  }

  async function escalate(b) {
    const ok = await confirmDialog({
      title: "Request emergency support?",
      message: `Dispatches an emergency escalation for booking #${b.id}. A high-priority alert is raised and logged for the operations team.`,
      confirmLabel: "Dispatch Emergency",
      danger: true,
    });
    if (!ok) return;
    try {
      await api.post(`/bookings/${b.id}/escalate`);
      toast(`Emergency support dispatched for booking #${b.id}`, "success");
      closeTopModal();
    } catch (err) {
      toast(errorMessage(err), "error");
    }
  }

  document.getElementById("live-refresh").addEventListener("click", poll);

  await poll();
  timerInt = setInterval(() => {
    document.querySelectorAll(".timer-chip[data-timer]").forEach((chip) => {
      const b = bookings.find((x) => x.id === Number(chip.dataset.timer));
      if (b) chip.textContent = `${icon("i-clock")} ${formatElapsed(b)}`;
    });
  }, 1000);
  window.__livePoll = setInterval(poll, 20000);
});
