/* ============================================================
   MaidItQuick Admin â€” notifications.js
   ============================================================ */

import { api, unwrap, errorMessage } from "./api.js";
import { registerModule, pageHeader, toast, confirmDialog, icon, openModal, closeTopModal, badge, showSpinner, hideSpinner, exportCsvFile, printReport } from "./app.js";
import { escapeHtml, fmtDateTime, timeAgo } from "./utils.js";
import * as auth from "./auth.js";

const TYPES = ["INFO", "SUCCESS", "WARNING", "ERROR"];

registerModule("notifications", async (el) => {
  const canWrite = auth.hasPermission("NOTIFICATIONS_WRITE");
  el.innerHTML = pageHeader(
    "Notifications",
    "Broadcast announcements and system messages.",
    `
    <button class="btn btn-ghost" id="n-csv">${icon("i-download")} CSV</button>
    <button class="btn btn-ghost" id="n-print">${icon("i-print")} Print</button>
    ${canWrite ? `<button class="btn btn-ghost" id="n-read-all">${icon("i-check")} Mark all read</button>` : ""}
    ${canWrite ? `<button class="btn btn-primary" id="n-add">${icon("i-plus")} Send notification</button>` : ""}
    `
  );

  const card = document.createElement("div");
  card.className = "card fade-up";
  const body = document.createElement("div");
  body.id = "n-body";
  body.innerHTML = `<div class="state-box"><div class="spinner-inline" style="width:30px;height:30px"></div></div>`;
  card.appendChild(body);
  el.appendChild(card);

  let items = [];

  async function load() {
    try {
      items = unwrap(await api.get("/notifications")) || [];
      render();
    } catch (err) {
      body.innerHTML = `<div class="state-box"><p class="muted">${escapeHtml(errorMessage(err))}</p></div>`;
    }
  }

  function render() {
    if (items.length === 0) {
      body.innerHTML = `<div class="table-empty" style="padding:56px"><div class="icon"><svg width="22" height="22"><use href="#i-bell"/></svg></div>No notifications yet.</div>`;
      return;
    }
    body.innerHTML = `<div class="notif-page-list" style="padding:10px">
      ${items
        .map(
          (n) => `
        <div class="card notif-page-item ${n.read ? "" : "unread"}" data-id="${n.id}">
          <div class="np-icon ${badgeType(n.type)}">
            <svg width="19" height="19"><use href="#i-${typeIcon(n.type)}"/></svg>
          </div>
          <div class="np-body">
            <div class="np-title">
              ${escapeHtml(n.title)}
              ${n.read ? "" : '<span class="badge st-INFO">New</span>'}
            </div>
            ${n.message ? `<div class="np-msg">${escapeHtml(n.message)}</div>` : ""}
            <div class="np-time">${fmtDateTime(n.createdAt)} Â· ${timeAgo(n.createdAt)}</div>
          </div>
          <div style="display:flex;gap:8px;align-items:center">
            ${badge(n.type)}
            ${canWrite ? `
              ${n.read ? "" : `<button class="btn btn-ghost btn-icon-sm" data-read title="Mark as read"><svg width="15" height="15"><use href="#i-check"/></svg></button>`}
              <button class="btn btn-ghost btn-icon-sm" data-del title="Delete" style="color:var(--danger)"><svg width="15" height="15"><use href="#i-trash"/></svg></button>` : ""}
          </div>
        </div>`
        )
        .join("")}
    </div>`;
  }

  function badgeType(type) {
    const map = { INFO: "ic-blue", SUCCESS: "ic-green", WARNING: "ic-amber", ERROR: "ic-red" };
    return map[type] || "ic-blue";
  }
  function typeIcon(type) {
    const map = { INFO: "info", SUCCESS: "check", WARNING: "warn", ERROR: "error" };
    return map[type] || "info";
  }

  function openCreate() {
    openModal({
      title: "Send notification",
      body: `
        <div class="field"><label class="req">Title</label>
          <input class="input" id="n-title" maxlength="200" placeholder="e.g. Maintenance window tonight">
        </div>
        <div class="field"><label>Type</label>
          <select class="select" id="n-type">
            ${TYPES.map((t) => `<option value="${t}">${t}</option>`).join("")}
          </select>
        </div>
        <div class="field"><label>Message</label>
          <textarea class="textarea" id="n-msg" maxlength="1000" placeholder="Optional message text"></textarea>
        </div>`,
      footer: `
        <button class="btn btn-ghost" data-close>Cancel</button>
        <button class="btn btn-primary" data-send>Send</button>`,
    });
    const overlay = [...document.querySelectorAll(".modal-overlay")].at(-1);
    overlay.querySelector("[data-close]").addEventListener("click", closeTopModal);
    overlay.querySelector("[data-send]").addEventListener("click", async () => {
      const title = overlay.querySelector("#n-title").value.trim();
      if (!title) {
        toast("Title is required", "warning");
        return;
      }
      const btn = overlay.querySelector("[data-send]");
      btn.disabled = true;
      try {
        await api.post("/notifications", {
          title,
          type: overlay.querySelector("#n-type").value,
          message: overlay.querySelector("#n-msg").value.trim() || null,
        });
        toast("Notification sent", "success");
        closeTopModal();
        load();
      } catch (err) {
        btn.disabled = false;
        toast(errorMessage(err), "error");
      }
    });
  }

  async function markRead(id) {
    try {
      await api.patch(`/notifications/${id}/read`);
      load();
    } catch (err) {
      toast(errorMessage(err), "error");
    }
  }

  async function markAllRead() {
    try {
      await api.patch("/notifications/read-all");
      toast("All notifications marked as read", "success");
      load();
    } catch (err) {
      toast(errorMessage(err), "error");
    }
  }

  async function remove(id) {
    const ok = await confirmDialog({
      title: "Delete notification?",
      message: "This notification will be permanently removed.",
      confirmLabel: "Delete",
      danger: true,
    });
    if (!ok) return;
    try {
      await api.delete(`/notifications/${id}`);
      toast("Notification deleted", "success");
      load();
    } catch (err) {
      toast(errorMessage(err), "error");
    }
  }

  document.getElementById("n-add")?.addEventListener("click", openCreate);
  document.getElementById("n-read-all")?.addEventListener("click", markAllRead);
  document.getElementById("n-csv").addEventListener("click", () =>
    exportCsvFile("notifications", [
      { key: "title", title: "Title" },
      { key: "type", title: "Type" },
      { key: "message", title: "Message" },
      { key: "read", title: "Read" },
      { key: "createdAt", title: "Created" },
    ], items)
  );
  document.getElementById("n-print").addEventListener("click", () =>
    printReport("Notifications â€” MaidItQuick Admin", "Broadcast messages", [
      { title: "Title", printValue: (n) => n.title },
      { title: "Type", printValue: (n) => n.type },
      { title: "Message", printValue: (n) => n.message || "" },
      { title: "Status", printValue: (n) => (n.read ? "READ" : "UNREAD") },
      { title: "Created", printValue: (n) => fmtDateTime(n.createdAt) },
    ], items)
  );

  body.addEventListener("click", (e) => {
    const item = e.target.closest("[data-id]");
    if (!item) return;
    const id = Number(item.dataset.id);
    if (e.target.closest("[data-read]")) markRead(id);
    else if (e.target.closest("[data-del]")) remove(id);
  });

  await load();
});
