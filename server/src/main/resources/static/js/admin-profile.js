/* ============================================================
   MaidItQuick Admin — admin-profile.js (M13)
   Admin profile page: identity, role, permissions,
   change password, active sessions, sign-out everywhere.
   ============================================================ */

import * as auth from "./auth.js";
import { api, unwrap, errorMessage } from "./api.js";
import {
  registerModule, pageHeader, toast, badge, icon, confirmDialog, showSpinner, hideSpinner,
} from "./app.js";
import { escapeHtml, fmtDateTime, timeAgo } from "./utils.js";

registerModule("admin-profile", async (el) => {
  const p = auth.getProfile();
  if (!p) {
    el.innerHTML = `<div class="state-box"><h3>Profile unavailable</h3><p>Sign in again to view your profile.</p></div>`;
    return;
  }

  el.innerHTML = pageHeader("Admin Profile", "Your identity, role, permissions and security", "");
  el.innerHTML += `
    <div class="profile-grid" style="display:grid;grid-template-columns:340px 1fr;gap:16px;align-items:start">
      <div class="card fade-up" style="padding:26px;text-align:center">
        <div class="cell-avatar" style="width:84px;height:84px;font-size:30px;margin:0 auto 14px">${escapeHtml(auth.currentInitials())}</div>
        <div class="h1" style="font-size:19px">${escapeHtml(p.name)}</div>
        <div class="muted" style="margin-top:4px">${escapeHtml(p.email)}</div>
        <div style="margin-top:12px">${p.role ? badge(p.role.code, p.role.name) : ""}</div>
        <div class="kv-grid" style="margin-top:20px;text-align:left">
          <div class="kv"><span>Admin ID</span><strong class="mono">#${escapeHtml(String(p.id))}</strong></div>
          <div class="kv"><span>Last login</span><strong>${p.lastLoginAt ? fmtDateTime(p.lastLoginAt) : "—"}</strong></div>
        </div>
      </div>
      <div class="card fade-up" style="padding:22px">
        <div class="muted" style="text-transform:uppercase;letter-spacing:.08em;font-weight:700;margin-bottom:10px">
          Permissions (${p.permissions?.length || 0})
        </div>
        <div style="display:flex;flex-wrap:wrap;gap:6px">
          ${(p.permissions || []).map((perm) => `<span class="badge st-INFO">${escapeHtml(perm)}</span>`).join("")}
        </div>
      </div>
    </div>`;

  const security = document.createElement("div");
  security.className = "card fade-up";
  security.style.marginTop = "16px";
  security.style.padding = "22px";
  security.innerHTML = `
    <div style="display:flex;align-items:center;gap:12px;margin-bottom:18px">
      <div class="icon" style="width:42px;height:42px;border-radius:12px;background:var(--warning-soft);color:var(--warning);display:flex;align-items:center;justify-content:center">
        <svg width="20" height="20"><use href="#i-lock"/></svg>
      </div>
      <div style="flex:1">
        <div style="font-weight:650">Security &amp; sessions</div>
        <div class="muted">Manage your password and the devices signed in to your account.</div>
      </div>
      <button class="btn btn-danger" id="pfp-signout-all" disabled>${icon("i-logout")} Sign out everywhere</button>
    </div>

    <div style="display:grid;grid-template-columns:380px 1fr;gap:24px;align-items:start">
      <div>
        <div class="muted" style="text-transform:uppercase;letter-spacing:.08em;font-weight:700;margin-bottom:10px">Change password</div>
        <div class="field">
          <label>Current password <span class="req"></span></label>
          <input class="input" type="password" id="pfp-current" autocomplete="current-password" placeholder="Your current password">
        </div>
        <div class="field">
          <label>New password <span class="req"></span></label>
          <input class="input" type="password" id="pfp-new" autocomplete="new-password" placeholder="Min. 12 characters">
        </div>
        <div class="field">
          <label>Confirm new password <span class="req"></span></label>
          <input class="input" type="password" id="pfp-confirm" autocomplete="new-password" placeholder="Repeat the new password">
        </div>
        <button class="btn btn-primary" id="pfp-change-btn">${icon("i-check")} Update password</button>
        <div class="muted" style="margin-top:10px;font-size:12px">Changing your password signs every other device out of your account.</div>
      </div>

      <div>
        <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:10px">
          <div class="muted" style="text-transform:uppercase;letter-spacing:.08em;font-weight:700">Active sessions</div>
          <button class="btn btn-ghost btn-sm" id="pfp-sessions-refresh">${icon("i-refresh")} Refresh</button>
        </div>
        <div id="pfp-sessions" class="state-box"><div class="spinner-inline" style="width:30px;height:30px"></div></div>
      </div>
    </div>`;
  el.appendChild(security);

  const sessionsBox = security.querySelector("#pfp-sessions");
  const changeBtn = security.querySelector("#pfp-change-btn");
  const signOutBtn = security.querySelector("#pfp-signout-all");

  const login = () => {
    auth.logout().finally(() => window.location.replace("login.html"));
  };

  async function loadSessions() {
    try {
      const list = unwrap(await api.get("/auth/sessions")) || [];
      signOutBtn.disabled = list.length <= 1;
      if (!list.length) {
        sessionsBox.innerHTML = `<div class="state-box"><h3>No active sessions</h3><p>Your session may have expired — sign in again.</p></div>`;
        return;
      }
      sessionsBox.innerHTML = list.map((s) => `
        <div style="display:flex;align-items:center;gap:14px;padding:13px 4px;border-bottom:1px solid var(--border-soft)">
          <div class="icon" style="width:40px;height:40px;border-radius:11px;background:var(--bg-soft);color:var(--text-2);display:flex;align-items:center;justify-content:center">
            <svg width="19" height="19"><use href="#i-phone"/></svg>
          </div>
          <div style="flex:1;min-width:0">
            <div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap">
              <strong style="font-size:13.5px">${escapeHtml(deviceLabel(s.userAgent))}</strong>
              ${s.current ? `<span class="badge st-ACTIVE"><span class="dot"></span>This device</span>` : ""}
            </div>
            <div class="muted" style="font-size:12px;margin-top:3px">
              ${escapeHtml(s.ipAddress || "—")} · signed in ${timeAgo(s.createdAt)} · last active ${timeAgo(s.lastUsedAt)}
            </div>
            <div class="muted" style="font-size:11.5px">${escapeHtml(fmtDateTime(s.expiresAt))} — session expiry</div>
          </div>
          ${s.current ? "" : `
            <button class="btn btn-ghost btn-sm" data-revoke="${s.id}">${icon("i-logout")} Revoke</button>`}
        </div>`).join("");
      sessionsBox.querySelectorAll("[data-revoke]").forEach((btn) => {
        btn.addEventListener("click", async () => {
          const id = Number(btn.dataset.revoke);
          const confirmed = await confirmDialog({
            title: "Revoke this session?",
            message: `Signs this device out immediately. It will need the account password to sign in again.`,
            confirmLabel: "Revoke session",
            danger: true,
          });
          if (!confirmed) return;
          try {
            const payload = await api.post(`/auth/sessions/${id}/revoke`);
            toast(payload?.message || "Session revoked", "success");
            const msg = payload?.message || "";
            if (/signed out/i.test(msg)) login();
            else loadSessions();
          } catch (err) {
            toast(errorMessage(err), "error");
          }
        });
      });
    } catch (err) {
      sessionsBox.innerHTML = `<div class="state-box"><h3>Could not load sessions</h3><p>${escapeHtml(errorMessage(err))}</p></div>`;
    }
  }

  changeBtn.addEventListener("click", async () => {
    const current = security.querySelector("#pfp-current").value;
    const next = security.querySelector("#pfp-new").value;
    const confirm = security.querySelector("#pfp-confirm").value;

    if (!current || !next || !confirm) {
      toast("Fill in all three password fields", "warning");
      return;
    }
    if (next.length < 12) {
      toast("New password must be at least 12 characters", "warning");
      return;
    }
    if (next !== confirm) {
      toast("New passwords do not match", "warning");
      return;
    }
    changeBtn.disabled = true;
    showSpinner();
    try {
      const payload = await api.post("/auth/change-password", { currentPassword: current, newPassword: next });
      toast(payload?.message || "Password changed", "success");
      security.querySelector("#pfp-current").value = "";
      security.querySelector("#pfp-new").value = "";
      security.querySelector("#pfp-confirm").value = "";
      loadSessions();
    } catch (err) {
      toast(errorMessage(err), "error");
    } finally {
      changeBtn.disabled = false;
      hideSpinner();
    }
  });

  security.querySelector("#pfp-sessions-refresh").addEventListener("click", loadSessions);

  signOutBtn.addEventListener("click", async () => {
    const confirmed = await confirmDialog({
      title: "Sign out everywhere?",
      message: `Revokes every active session, including this device. You will be returned to the sign-in screen.`,
      confirmLabel: "Sign out everywhere",
      danger: true,
    });
    if (!confirmed) return;
    signOutBtn.disabled = true;
    showSpinner();
    try {
      const payload = await api.post("/auth/sign-out-everywhere");
      toast(payload?.message || "Signed out everywhere", "success");
      login();
    } catch (err) {
      toast(errorMessage(err), "error");
      signOutBtn.disabled = false;
      hideSpinner();
    }
  });

  loadSessions();
});

/* ---- user-agent -> short human label ---- */
function deviceLabel(ua) {
  if (!ua) return "Unknown device";
  let browser = "Browser";
  if (/Edg\//i.test(ua)) browser = "Edge";
  else if (/Chrome\//i.test(ua)) browser = "Chrome";
  else if (/Firefox\//i.test(ua)) browser = "Firefox";
  else if (/Safari\//i.test(ua)) browser = "Safari";
  let os = "Unknown OS";
  if (/Windows/i.test(ua)) os = "Windows";
  else if (/Mac OS X|Macintosh/i.test(ua)) os = "macOS";
  else if (/Android/i.test(ua)) os = "Android";
  else if (/iPhone|iPad|iPod/i.test(ua)) os = "iOS";
  else if (/Linux/i.test(ua)) os = "Linux";
  return `${browser} · ${os}`;
}
