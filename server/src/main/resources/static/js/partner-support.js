/* MaidItQuick Admin — support requests raised by partner and customer accounts. */
import { rootApi } from "./api.js";
import { badge, closeTopModal, openModal, pageHeader, registerModule, toast } from "./app.js";
import { escapeHtml, fmtDateTime } from "./utils.js";

const statuses = ["OPEN", "IN_REVIEW", "IN_PROGRESS", "WAITING_FOR_CUSTOMER", "RESOLVED", "CLOSED"];
const roles = [
  { key: "", label: "All Requesters" },
  { key: "CUSTOMER", label: "Customers" },
  { key: "WORKER", label: "Partners" },
];

function priorityBadge(priority) {
  if (!priority) return "";
  const p = priority.toUpperCase();
  const cls = p === "URGENT" ? "st-DANGER" : p === "HIGH" ? "st-WARNING" : p === "MEDIUM" ? "st-INFO" : "st-MUTED";
  return `<span class="badge ${cls}" style="font-weight:700;font-size:10px">${escapeHtml(p)}</span>`;
}

function rows(tickets, canWrite) {
  if (!tickets.length) return `<tr><td colspan="8" class="empty-cell">No support requests found.</td></tr>`;
  return tickets.map((ticket) => {
    const isCustomer = ticket.requesterRole === "CUSTOMER";
    const roleBadge = isCustomer
      ? `<span class="badge st-INFO">Customer</span>`
      : `<span class="badge st-SUCCESS">Partner</span>`;
    const catBadge = ticket.category
      ? `<span class="badge st-PENDING" style="font-size:10px">${escapeHtml(ticket.category)}</span>`
      : "";
    const bookingBadge = ticket.bookingId
      ? `<span class="badge st-WARNING" style="font-size:10px">Booking #${ticket.bookingId}</span>`
      : "";
    const scenarioBadge = ticket.scenario
      ? `<span class="badge st-MUTED" style="font-size:10px">${escapeHtml(ticket.scenario.replaceAll("_", " "))}</span>`
      : "";
    const evidenceBadge = ticket.evidenceList && ticket.evidenceList.length
      ? `<span class="badge st-INFO" style="font-size:10px" title="${ticket.evidenceList.length} photo(s) attached">📷 ${ticket.evidenceList.length}</span>`
      : "";

    return `<tr data-ticket="${ticket.id}">
      <td class="mono">#${ticket.id}</td>
      <td>
        <strong>${escapeHtml(ticket.subject)}</strong>
        <div style="margin-top:4px;display:flex;gap:4px;flex-wrap:wrap;align-items:center;">
          ${priorityBadge(ticket.priority)}
          ${catBadge}
          ${bookingBadge}
          ${scenarioBadge}
          ${evidenceBadge}
        </div>
        <div class="meta ellipsis" style="max-width:340px;margin-top:2px;">${escapeHtml(ticket.message)}</div>
      </td>
      <td>${escapeHtml(ticket.requester || "User")}</td>
      <td>${roleBadge}</td>
      <td>${priorityBadge(ticket.priority) || `<span class="muted" style="font-size:11px">—</span>`}</td>
      <td>${badge(ticket.status)}</td>
      <td class="muted" style="white-space:nowrap">${fmtDateTime(ticket.createdAt)}</td>
      <td class="text-right">
        <button class="btn btn-sm btn-primary" data-view="${ticket.id}">View</button>
        ${canWrite ? ` <button class="btn btn-sm btn-ghost" data-reply="${ticket.id}">Reply</button>` : ""}
      </td>
    </tr>`;
  }).join("");
}

async function details(ticket, canWrite, reload) {
  let messages = [];
  try { messages = await rootApi.get(`/api/support/tickets/${ticket.id}/messages`); } catch (_) { /* Supports existing tickets too. */ }
  const requesterLabel = escapeHtml(ticket.requester || (ticket.requesterRole === "CUSTOMER" ? "Customer" : "Partner"));
  const thread = [
    `<div class="kv" style="grid-column:1/-1"><span>${requesterLabel}</span><strong>${escapeHtml(ticket.message)}</strong></div>`,
    ...messages.map(message => `<div class="kv" style="grid-column:1/-1"><span>${message.senderRole === "ADMIN" ? "Support" : requesterLabel}</span><strong>${escapeHtml(message.message)}</strong><small>${fmtDateTime(message.createdAt)}</small></div>`),
    !messages.length && ticket.reply ? `<div class="kv" style="grid-column:1/-1"><span>Support</span><strong>${escapeHtml(ticket.reply)}</strong></div>` : "",
  ].join("");

  const roleName = ticket.requesterRole === "CUSTOMER" ? "Customer" : "Partner";

  const modalHtml = `<div class="kv-grid">
    <div class="kv"><span>Requester</span><strong>${requesterLabel} (${roleName})</strong></div>
    <div class="kv"><span>Status</span><strong>${badge(ticket.status)}</strong></div>
    <div class="kv"><span>Created</span><strong>${fmtDateTime(ticket.createdAt)}</strong></div>
    <div class="kv"><span>Priority</span><strong>${priorityBadge(ticket.priority) || "Normal"}</strong></div>
    ${ticket.severity ? `<div class="kv"><span>Severity</span><strong>${escapeHtml(ticket.severity)}</strong></div>` : ""}
    ${ticket.category ? `<div class="kv"><span>Category</span><strong>${escapeHtml(ticket.category)}</strong></div>` : ""}
    ${ticket.bookingId ? `<div class="kv"><span>Booking ID</span><strong>#${ticket.bookingId}</strong></div>` : ""}
    ${ticket.scenario ? `<div class="kv" style="grid-column:1/-1"><span>Scenario Rule</span><strong>${escapeHtml(ticket.scenario.replaceAll("_", " "))}</strong></div>` : ""}
    <div class="kv" style="grid-column:1/-1"><span>Subject</span><strong>${escapeHtml(ticket.subject)}</strong></div>

    ${ticket.recommendedAction ? `
      <div style="grid-column:1/-1;background:rgba(2,132,199,0.08);border-left:4px solid #0284c7;padding:12px 14px;border-radius:6px;margin:6px 0;">
        <div style="font-weight:700;font-size:12px;color:#0284c7;margin-bottom:4px;">⚡ System Recommendation / Action Plan</div>
        <div style="font-size:13px;line-height:1.4;color:#0f172a;">${escapeHtml(ticket.recommendedAction)}</div>
      </div>
    ` : ""}

    ${ticket.evidenceList && ticket.evidenceList.length ? `
      <div style="grid-column:1/-1;margin:8px 0;">
        <div style="font-weight:700;font-size:12px;margin-bottom:8px;color:#334155;">📷 Photographic Evidence (${ticket.evidenceList.length} photos)</div>
        <div style="display:flex;gap:10px;flex-wrap:wrap;">
          ${ticket.evidenceList.map((url, idx) => `
            <a href="${escapeHtml(url)}" target="_blank" rel="noopener" style="display:inline-block;border:1px solid #cbd5e1;border-radius:8px;overflow:hidden;width:96px;height:96px;background:#f8fafc;box-shadow:0 1px 3px rgba(0,0,0,0.06);transition:transform 0.15s ease;" title="Click to view full photo">
              <img src="${escapeHtml(url)}" alt="Evidence ${idx + 1}" style="width:100%;height:100%;object-fit:cover;" onerror="this.style.display='none';this.parentElement.innerHTML='<div style=\\\'padding:10px;font-size:11px;color:#64748b;text-align:center;\\'>Photo ${idx + 1}</div>'" />
            </a>
          `).join("")}
        </div>
      </div>
    ` : ""}

    ${ticket.connectsToRefund ? `
      <div style="grid-column:1/-1;background:rgba(245,158,11,0.08);border:1px solid rgba(245,158,11,0.3);padding:12px 14px;border-radius:8px;margin:6px 0;">
        <div style="font-weight:700;font-size:12px;color:#b45309;margin-bottom:4px;">💰 Refund System Integration</div>
        ${ticket.refundInfo ? `
          <div style="font-size:13px;color:#78350f;">
            Linked Return Request <strong>#${ticket.refundInfo.id}</strong> — Status: <strong>${badge(ticket.refundInfo.status)}</strong><br/>
            Requested: <strong>₹${ticket.refundInfo.requestedAmount}</strong> | Approved: <strong>₹${ticket.refundInfo.approvedAmount}</strong>
          </div>
        ` : `
          <div style="display:flex;justify-content:space-between;align-items:center;">
            <span style="font-size:13px;color:#78350f;">This ticket qualifies for refund review under existing return rules.</span>
            ${canWrite && ticket.bookingId ? `<button class="btn btn-sm btn-primary" id="btn-connect-refund">Initiate / Connect Refund</button>` : ""}
          </div>
        `}
      </div>
    ` : ""}

    ${thread}
  </div>`;

  openModal({
    title: `Support ticket #${ticket.id}`,
    size: "lg",
    body: modalHtml,
    footer: `<button class="btn btn-ghost" data-close>Close</button>${canWrite ? `<button class="btn btn-primary" data-reply-ticket>Reply / update</button>` : ""}`,
  });

  const activeOverlay = document.querySelectorAll(".modal-overlay").at(-1);
  activeOverlay?.querySelector("[data-reply-ticket]")?.addEventListener("click", () => reply(ticket, reload));
  activeOverlay?.querySelector("#btn-connect-refund")?.addEventListener("click", async () => {
    try {
      const res = await rootApi.post(`/api/support/tickets/${ticket.id}/connect-refund`, {});
      toast(`Return request #${res.returnId} linked (${res.status})`, "success");
      closeTopModal();
      await reload();
    } catch (err) {
      toast(err.message || "Failed to connect refund", "error");
    }
  });
}

function reply(ticket, reload) {
  closeTopModal();
  const requesterName = escapeHtml(ticket.requester || (ticket.requesterRole === "CUSTOMER" ? "customer" : "partner"));
  openModal({
    title: `Reply to ${requesterName}`,
    body: `<div class="field"><label>Reply</label><textarea class="textarea" id="partner-ticket-reply" rows="5" maxlength="2000" required placeholder="Write a response for the ${ticket.requesterRole === "CUSTOMER" ? "customer" : "partner"}…">${escapeHtml(ticket.reply || "")}</textarea></div><div class="field"><label>Status</label><select class="select" id="partner-ticket-status">${statuses.map(status => `<option value="${status}" ${status === ticket.status ? "selected" : ""}>${escapeHtml(status.replaceAll("_", " "))}</option>`).join("")}</select></div>`,
    footer: `<button class="btn btn-ghost" data-close>Cancel</button><button class="btn btn-primary" id="save-partner-ticket">Send reply</button>`,
  });
  document.getElementById("save-partner-ticket").addEventListener("click", async () => {
    const message = document.getElementById("partner-ticket-reply").value.trim();
    const status = document.getElementById("partner-ticket-status").value;
    if (!message) { toast("Enter a reply.", "warning"); return; }
    const button = document.getElementById("save-partner-ticket");
    button.disabled = true;
    try {
      await rootApi.post(`/api/support/tickets/${ticket.id}/reply`, { message });
      if (status !== "IN_PROGRESS") await rootApi.post(`/api/support/tickets/${ticket.id}/status`, { status });
      closeTopModal();
      toast("Reply sent successfully.", "success");
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
  let activeRole = "";

  const render = () => {
    const tickets = allTickets.filter(ticket =>
      (!activeStatus || ticket.status === activeStatus) &&
      (!activeRole || ticket.requesterRole === activeRole)
    );

    el.innerHTML = `${pageHeader("Support Tickets", "Support tickets submitted from the Partner and Customer mobile apps.")}
    <div class="card">
      <div style="padding:14px 16px 4px; display:flex; flex-wrap:wrap; gap:12px; justify-content:space-between; align-items:center;">
        <div class="seg-tabs">
          ${roles.map(r => `<button class="${r.key === activeRole ? "active" : ""}" data-role="${r.key}">${escapeHtml(r.label)}</button>`).join("")}
        </div>
        <div class="seg-tabs">
          ${["", ...statuses].map(status => `<button class="${status === activeStatus ? "active" : ""}" data-status="${status}">${status ? escapeHtml(status.replaceAll("_", " ")) : "All Statuses"}</button>`).join("")}
        </div>
      </div>
      <div class="table-wrap">
        <table class="table">
          <thead>
            <tr>
              <th>ID</th>
              <th>Request</th>
              <th>Requester</th>
              <th>Role</th>
              <th>Priority</th>
              <th>Status</th>
              <th>Created</th>
              <th class="text-right">Actions</th>
            </tr>
          </thead>
          <tbody>${rows(tickets, canWrite)}</tbody>
        </table>
      </div>
    </div>`;

    el.querySelectorAll("[data-role]").forEach(button => button.addEventListener("click", () => { activeRole = button.dataset.role; render(); }));
    el.querySelectorAll("[data-status]").forEach(button => button.addEventListener("click", () => { activeStatus = button.dataset.status; render(); }));
    el.querySelectorAll("[data-view], [data-reply]").forEach(button => button.addEventListener("click", () => {
      const ticket = allTickets.find(item => item.id === Number(button.dataset.view || button.dataset.reply));
      if (ticket) button.dataset.reply ? reply(ticket, reload) : details(ticket, canWrite, reload);
    }));
  };

  const reload = async () => {
    try {
      allTickets = (await rootApi.get("/api/support/tickets")).sort((a, b) => b.id - a.id);
      render();
    } catch (err) {
      el.innerHTML = `${pageHeader("Support Tickets", "Support tickets submitted from the Partner and Customer mobile apps.")}<div class="card empty-state">${escapeHtml(err.message || "Could not load support tickets")}</div>`;
    }
  };

  await reload();
});
