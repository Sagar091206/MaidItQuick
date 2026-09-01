/* MaidItQuick Admin — support requests raised by partner accounts. */
import { rootApi } from "./api.js";
import { badge, closeTopModal, openModal, pageHeader, registerModule, toast } from "./app.js";
import { escapeHtml, fmtDateTime } from "./utils.js";

const statuses = ["OPEN", "IN_PROGRESS", "RESOLVED"];

function rows(tickets, canWrite) {
  if (!tickets.length) return `<tr><td colspan="6" class="empty-cell">No partner support requests yet.</td></tr>`;
  return tickets.map((ticket) => `<tr data-ticket="${ticket.id}">
    <td class="mono">#${ticket.id}</td>
    <td><strong>${escapeHtml(ticket.subject)}</strong><div class="meta ellipsis" style="max-width:360px">${escapeHtml(ticket.message)}</div></td>
    <td>${escapeHtml(ticket.requester || "Partner")}</td>
    <td>${badge(ticket.status)}</td>
    <td class="muted" style="white-space:nowrap">${fmtDateTime(ticket.createdAt)}</td>
    <td class="text-right"><button class="btn btn-sm btn-primary" data-view="${ticket.id}">View</button>${canWrite ? ` <button class="btn btn-sm btn-ghost" data-reply="${ticket.id}">Reply</button>` : ""}</td>
  </tr>`).join("");
}

function details(ticket, canWrite, reload) {
  openModal({
    title: `Partner support #${ticket.id}`,
    size: "lg",
    body: `<div class="kv-grid"><div class="kv"><span>Partner</span><strong>${escapeHtml(ticket.requester || "Partner")}</strong></div><div class="kv"><span>Status</span><strong>${badge(ticket.status)}</strong></div><div class="kv"><span>Created</span><strong>${fmtDateTime(ticket.createdAt)}</strong></div><div class="kv" style="grid-column:1/-1"><span>Subject</span><strong>${escapeHtml(ticket.subject)}</strong></div><div class="kv" style="grid-column:1/-1"><span>Message</span><strong>${escapeHtml(ticket.message)}</strong></div>${ticket.reply ? `<div class="kv" style="grid-column:1/-1"><span>Latest admin reply</span><strong>${escapeHtml(ticket.reply)}</strong></div>` : ""}</div>`,
    footer: `<button class="btn btn-ghost" data-close>Close</button>${canWrite ? `<button class="btn btn-primary" data-reply-ticket>Reply / update</button>` : ""}`,
  });
  document.querySelectorAll(".modal-overlay").at(-1)?.querySelector("[data-reply-ticket]")?.addEventListener("click", () => reply(ticket, reload));
}

function reply(ticket, reload) {
  closeTopModal();
  openModal({
    title: `Reply to ${ticket.requester || "partner"}`,
    body: `<div class="field"><label>Reply</label><textarea class="textarea" id="partner-ticket-reply" rows="5" maxlength="2000" required placeholder="Write a response for the partner…">${escapeHtml(ticket.reply || "")}</textarea></div><div class="field"><label>Status</label><select class="select" id="partner-ticket-status">${statuses.map(status => `<option value="${status}" ${status === ticket.status ? "selected" : ""}>${escapeHtml(status.replaceAll("_", " "))}</option>`).join("")}</select></div>`,
    footer: `<button class="btn btn-ghost" data-close>Cancel</button><button class="btn btn-primary" id="save-partner-ticket">Send reply</button>`,
  });
  document.getElementById("save-partner-ticket").addEventListener("click", async () => {
    const message = document.getElementById("partner-ticket-reply").value.trim();
    const status = document.getElementById("partner-ticket-status").value;
    if (!message) { toast("Enter a reply for the partner.", "warning"); return; }
    const button = document.getElementById("save-partner-ticket");
    button.disabled = true;
    try {
      await rootApi.post(`/api/support/tickets/${ticket.id}/reply`, { message });
      if (status !== "IN_PROGRESS") await rootApi.post(`/api/support/tickets/${ticket.id}/status`, { status });
      closeTopModal();
      toast("Reply sent to the partner.", "success");
      await reload();
    } catch (err) {
      toast(err.message || "Could not update the support ticket", "error");
    } finally { button.disabled = false; }
  });
}

registerModule("partner-support", async (el) => {
  const canWrite = true;
  let allTickets = [];
  let activeStatus = "";
  const render = () => {
    const tickets = allTickets.filter(ticket => ticket.status === activeStatus || !activeStatus);
    el.innerHTML = `${pageHeader("Partner Support", "Support tickets submitted from the Partner app.")}<div class="card"><div style="padding:14px 16px 4px" class="seg-tabs">${["", ...statuses].map(status => `<button class="${status === activeStatus ? "active" : ""}" data-status="${status}">${status ? escapeHtml(status.replaceAll("_", " ")) : "All"}</button>`).join("")}</div><div class="table-wrap"><table class="table"><thead><tr><th>ID</th><th>Request</th><th>Partner</th><th>Status</th><th>Created</th><th class="text-right">Actions</th></tr></thead><tbody>${rows(tickets, canWrite)}</tbody></table></div></div>`;
    el.querySelectorAll("[data-status]").forEach(button => button.addEventListener("click", () => { activeStatus = button.dataset.status; render(); }));
    el.querySelectorAll("[data-view], [data-reply]").forEach(button => button.addEventListener("click", () => {
      const ticket = allTickets.find(item => item.id === Number(button.dataset.view || button.dataset.reply));
      if (ticket) button.dataset.reply ? reply(ticket, reload) : details(ticket, canWrite, reload);
    }));
  };
  const reload = async () => {
    try {
      allTickets = (await rootApi.get("/api/support/tickets"))
        .filter(ticket => ticket.requesterRole === "WORKER")
        .sort((a, b) => b.id - a.id);
      render();
    } catch (err) {
      el.innerHTML = `${pageHeader("Partner Support", "Support tickets submitted from the Partner app.")}<div class="card empty-state">${escapeHtml(err.message || "Could not load partner support tickets")}</div>`;
    }
  };
  await reload();
});
