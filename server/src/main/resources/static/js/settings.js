/* ============================================================
   MaidItQuick Admin — settings.js
   Key/value application settings + Promotions & Discounts V1
   ============================================================ */

import { api, unwrap, errorMessage } from "./api.js";
import { registerModule, pageHeader, toast, confirmDialog, icon, openModal, closeTopModal, badge, exportCsvFile, printReport } from "./app.js";
import { escapeHtml, fmtDateTime } from "./utils.js";
import * as auth from "./auth.js";

registerModule("settings", async (el) => {
  const canWrite = auth.hasPermission("SETTINGS_WRITE");

  el.innerHTML = pageHeader(
    "Settings & Promotions",
    "System configuration, first-order discounts, and promo codes.",
    `
    <div id="header-actions-general">
      <button class="btn btn-ghost" id="s-csv">${icon("i-download")} CSV</button>
      <button class="btn btn-ghost" id="s-print">${icon("i-print")} Print</button>
      ${canWrite ? `<button class="btn btn-primary" id="s-add">${icon("i-plus")} New setting</button>` : ""}
    </div>
    <div id="header-actions-promos" style="display:none">
      ${canWrite ? `<button class="btn btn-primary" id="p-add">${icon("i-plus")} New promo code</button>` : ""}
    </div>
    `
  );

  const tabsHost = document.createElement("div");
  tabsHost.className = "seg-tabs";
  tabsHost.id = "settings-tabs";
  tabsHost.style.marginBottom = "16px";
  tabsHost.innerHTML = `
    <button class="active" data-tab="general">${icon("i-settings")} System Settings</button>
    <button data-tab="promotions">${icon("i-payments")} Promotions &amp; Discounts</button>
  `;
  el.appendChild(tabsHost);

  const generalPanel = document.createElement("div");
  generalPanel.className = "tab-panel";
  generalPanel.setAttribute("data-panel", "general");

  const promoPanel = document.createElement("div");
  promoPanel.className = "tab-panel";
  promoPanel.setAttribute("data-panel", "promotions");
  promoPanel.style.display = "none";

  el.appendChild(generalPanel);
  el.appendChild(promoPanel);

  // -------------------------------------------------------------
  // Tab Switching
  // -------------------------------------------------------------
  let activeTab = "general";
  tabsHost.addEventListener("click", (e) => {
    const btn = e.target.closest("button[data-tab]");
    if (!btn || btn.dataset.tab === activeTab) return;
    activeTab = btn.dataset.tab;
    tabsHost.querySelectorAll("button").forEach((b) => b.classList.toggle("active", b === btn));
    if (activeTab === "general") {
      generalPanel.style.display = "";
      promoPanel.style.display = "none";
      document.getElementById("header-actions-general").style.display = "";
      document.getElementById("header-actions-promos").style.display = "none";
    } else {
      generalPanel.style.display = "none";
      promoPanel.style.display = "";
      document.getElementById("header-actions-general").style.display = "none";
      document.getElementById("header-actions-promos").style.display = "";
      loadPromotions();
    }
  });

  // -------------------------------------------------------------
  // System Settings State & Rendering
  // -------------------------------------------------------------
  const wrap = document.createElement("div");
  wrap.className = "settings-grid fade-up";
  wrap.innerHTML = `<div class="card" style="grid-column:1/-1"><div class="state-box"><div class="spinner-inline" style="width:30px;height:30px"></div></div></div>`;
  generalPanel.appendChild(wrap);

  let items = [];

  async function loadSettings() {
    try {
      items = unwrap(await api.get("/settings")) || [];
      renderSettings();
    } catch (err) {
      wrap.innerHTML = `<div class="card" style="grid-column:1/-1"><div class="state-box"><p class="muted">${escapeHtml(errorMessage(err))}</p></div></div>`;
    }
  }

  function renderSettings() {
    if (items.length === 0) {
      wrap.innerHTML = `<div class="card" style="grid-column:1/-1"><div class="table-empty" style="padding:52px"><div class="icon"><svg width="22" height="22"><use href="#i-settings"/></svg></div>No settings configured yet.</div></div>`;
      return;
    }
    const total = items.length;
    const text = items.filter((s) => !s.settingKey.includes("_JSON")).length;
    const updated = items.filter((s) => s.updatedAt).length;

    wrap.innerHTML = `
      <div class="card" style="overflow:hidden">
        <div class="card-header"><h3>All settings</h3><span class="badge st-INFO">${total} entries</span></div>
        <div class="table-wrap"><table class="table">
          <thead><tr><th>Key</th><th>Value</th><th>Description</th><th class="text-right">Updated</th>${canWrite ? "<th></th>" : ""}</tr></thead>
          <tbody>${items
            .map(
              (s) => `<tr data-id="${s.id}">
                <td><span class="mono" style="color:var(--accent-2)">${escapeHtml(s.settingKey)}</span></td>
                <td><code class="pre" style="max-width:200px;display:inline-block;max-height:none">${escapeHtml(s.settingValue)}</code></td>
                <td class="muted ellipsis" style="max-width:180px">${escapeHtml(s.description || "—")}</td>
                <td class="text-right muted">${s.updatedAt ? fmtDateTime(s.updatedAt) : "—"}</td>
                ${canWrite ? `<td class="text-right"><div class="actions">
                  <button class="btn btn-ghost btn-icon-sm" data-edit title="Edit"><svg width="15" height="15"><use href="#i-edit"/></svg></button>
                  <button class="btn btn-ghost btn-icon-sm" data-del style="color:var(--danger)" title="Delete"><svg width="15" height="15"><use href="#i-trash"/></svg></button>
                </div></td>` : ""}
              </tr>`
            )
            .join("")}
          </tbody></table></div>
      </div>

      <div class="card card-pad">
        <div class="h2" style="margin-bottom:16px">Overview</div>
        <div class="stat-strip" style="grid-template-columns:1fr;margin-bottom:0">
          <div class="s-mini"><div class="l">Total settings</div><div class="v">${total}</div></div>
          <div class="s-mini"><div class="l">Text values</div><div class="v">${text}</div></div>
          <div class="s-mini"><div class="l">Recently updated</div><div class="v">${updated}</div></div>
        </div>
      </div>`;
  }

  function openSetting(s = null) {
    openModal({
      title: s ? `Edit setting — ${s.settingKey}` : "New setting",
      body: `
        <div class="field"><label class="req">Key</label>
          <input class="input" id="s-key" value="${escapeHtml(s?.settingKey || "")}" ${s ? "disabled" : ""} maxlength="120" placeholder="e.g. SUPPORT_EMAIL">
          <div class="muted" style="margin-top:5px">Uppercase letters, numbers, dots, dashes, underscores. Spaces become underscores.</div>
        </div>
        <div class="field"><label class="req">Value</label>
          <textarea class="textarea" id="s-val" maxlength="2000" placeholder="Setting value">${escapeHtml(s?.settingValue || "")}</textarea>
        </div>
        <div class="field"><label>Description</label>
          <textarea class="textarea" id="s-desc" maxlength="500" placeholder="What does this setting control?">${escapeHtml(s?.description || "")}</textarea>
        </div>`,
      footer: `
        <button class="btn btn-ghost" data-close>Cancel</button>
        <button class="btn btn-primary" data-save>${s ? "Save changes" : "Create setting"}</button>`,
    });
    const overlay = [...document.querySelectorAll(".modal-overlay")].at(-1);
    overlay.querySelector("[data-close]").addEventListener("click", closeTopModal);
    overlay.querySelector("[data-save]").addEventListener("click", async () => {
      const key = overlay.querySelector("#s-key").value.trim();
      const value = overlay.querySelector("#s-val").value.trim();
      const description = overlay.querySelector("#s-desc").value.trim();
      if (!key || !value) {
        toast("Key and value are required", "warning");
        return;
      }
      const btn = overlay.querySelector("[data-save]");
      btn.disabled = true;
      try {
        if (s) {
          await api.put(`/settings/${s.id}`, { key: s.settingKey, value, description: description || null });
          toast("Setting updated", "success");
        } else {
          await api.post("/settings", { key, value, description: description || null });
          toast("Setting created", "success");
        }
        closeTopModal();
        loadSettings();
      } catch (err) {
        btn.disabled = false;
        toast(errorMessage(err), "error");
      }
    });
  }

  async function removeSetting(s) {
    const ok = await confirmDialog({
      title: "Delete setting?",
      message: `"${escapeHtml(s.settingKey)}" will be permanently removed.`,
      confirmLabel: "Delete",
      danger: true,
    });
    if (!ok) return;
    try {
      await api.delete(`/settings/${s.id}`);
      toast("Setting deleted", "success");
      loadSettings();
    } catch (err) {
      toast(errorMessage(err), "error");
    }
  }

  document.getElementById("s-add")?.addEventListener("click", () => openSetting());
  document.getElementById("s-csv").addEventListener("click", () =>
    exportCsvFile("settings", [
      { key: "settingKey", title: "Key" },
      { key: "settingValue", title: "Value" },
      { key: "description", title: "Description" },
      { key: "updatedAt", title: "Updated" },
    ], items)
  );
  document.getElementById("s-print").addEventListener("click", () =>
    printReport("Settings — MaidItQuick Admin", "Key/value configuration", [
      { title: "Key", printValue: (s) => s.settingKey },
      { title: "Value", printValue: (s) => s.settingValue },
      { title: "Description", printValue: (s) => s.description || "" },
    ], items)
  );

  wrap.addEventListener("click", (e) => {
    const tr = e.target.closest("tr[data-id]");
    if (!tr) return;
    const s = items.find((x) => x.id === Number(tr.dataset.id));
    if (!s) return;
    if (e.target.closest("[data-edit]")) openSetting(s);
    else if (e.target.closest("[data-del]")) removeSetting(s);
  });

  // -------------------------------------------------------------
  // Promotions State & Rendering
  // -------------------------------------------------------------
  const promoWrap = document.createElement("div");
  promoWrap.className = "settings-grid fade-up";
  promoWrap.innerHTML = `<div class="card" style="grid-column:1/-1"><div class="state-box"><div class="spinner-inline" style="width:30px;height:30px"></div></div></div>`;
  promoPanel.appendChild(promoWrap);

  let firstOrderPct = 20;
  let promoCodes = [];

  async function loadPromotions() {
    promoWrap.innerHTML = `<div class="card" style="grid-column:1/-1"><div class="state-box"><div class="spinner-inline" style="width:30px;height:30px"></div></div></div>`;
    try {
      const [foRes, promoRes] = await Promise.all([
        api.get("/promos/first-order"),
        api.get("/promos"),
      ]);
      const foData = unwrap(foRes);
      if (foData && typeof foData.percentage === "number") {
        firstOrderPct = foData.percentage;
      }
      promoCodes = unwrap(promoRes) || [];
      renderPromotions();
    } catch (err) {
      promoWrap.innerHTML = `<div class="card" style="grid-column:1/-1"><div class="state-box"><p class="muted">${escapeHtml(errorMessage(err))}</p></div></div>`;
    }
  }

  function renderPromotions() {
    const totalPromos = promoCodes.length;
    const activePromos = promoCodes.filter((p) => p.enabled).length;
    const inactivePromos = totalPromos - activePromos;

    promoWrap.innerHTML = `
      <div style="display:flex;flex-direction:column;gap:16px">
        <!-- First-Order Discount Card -->
        <div class="card card-pad">
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:12px">
            <div>
              <h3 style="margin:0 0 4px 0">First-Order Discount</h3>
              <p class="muted" style="margin:0;font-size:13px">
                Automatically applied to an eligible customer's first completed/paid booking.
              </p>
            </div>
            <span class="badge ${firstOrderPct > 0 ? "st-ACTIVE" : "st-INACTIVE"}">${firstOrderPct}% Active</span>
          </div>

          <div style="background:var(--surface-sunken, rgba(0,0,0,0.02));border-radius:var(--radius-sm, 6px);padding:14px;display:flex;align-items:center;gap:16px;flex-wrap:wrap">
            <div style="display:flex;align-items:center;gap:8px">
              <label for="fo-discount-input" style="font-weight:600;font-size:13px">Discount Percentage (%):</label>
              <input type="number" class="input" id="fo-discount-input" min="0" max="100" value="${firstOrderPct}" style="width:90px" ${canWrite ? "" : "disabled"}>
            </div>
            ${canWrite ? `<button class="btn btn-primary btn-sm" id="fo-save-btn">${icon("i-edit")} Update Discount</button>` : ""}
          </div>
          <div class="muted" style="font-size:12px;margin-top:8px">
            Note: If a customer enters a valid promo code at checkout, the promo code takes precedence. Discounts are never stacked.
          </div>
        </div>

        <!-- Promo Codes Table Card -->
        <div class="card" style="overflow:hidden">
          <div class="card-header">
            <h3>Promo Codes</h3>
            <div style="display:flex;gap:8px;align-items:center">
              <span class="badge st-INFO">${totalPromos} codes</span>
              ${canWrite ? `<button class="btn btn-primary btn-sm" id="p-add-table">${icon("i-plus")} Add Code</button>` : ""}
            </div>
          </div>
          ${
            promoCodes.length === 0
              ? `<div class="table-empty" style="padding:48px"><div class="icon"><svg width="22" height="22"><use href="#i-payments"/></svg></div>No promo codes configured yet.</div>`
              : `<div class="table-wrap"><table class="table">
                  <thead>
                    <tr>
                      <th>Promo Code</th>
                      <th>Discount</th>
                      <th>Status</th>
                      <th>Created</th>
                      ${canWrite ? "<th class=\"text-right\">Actions</th>" : ""}
                    </tr>
                  </thead>
                  <tbody>
                    ${promoCodes
                      .map(
                        (p) => `
                        <tr data-promo-id="${p.id}">
                          <td>
                            <strong class="mono" style="font-size:13px;padding:3px 6px;border-radius:4px;background:rgba(99,102,241,0.08);color:var(--primary, #6366f1)">${escapeHtml(p.code)}</strong>
                          </td>
                          <td>
                            <strong>${p.discountPercentage}%</strong>
                          </td>
                          <td>
                            ${badge(p.enabled ? "ACTIVE" : "INACTIVE")}
                          </td>
                          <td class="muted" style="font-size:12px">
                            ${p.createdAt ? fmtDateTime(p.createdAt) : "—"}
                          </td>
                          ${
                            canWrite
                              ? `<td class="text-right">
                                  <div class="actions">
                                    <button class="btn btn-ghost btn-icon-sm" data-toggle-promo title="${p.enabled ? "Deactivate" : "Activate"}">
                                      <svg width="15" height="15"><use href="${p.enabled ? "#i-x" : "#i-refresh"}"/></svg>
                                    </button>
                                    <button class="btn btn-ghost btn-icon-sm" data-del-promo style="color:var(--danger)" title="Delete">
                                      <svg width="15" height="15"><use href="#i-trash"/></svg>
                                    </button>
                                  </div>
                                </td>`
                              : ""
                          }
                        </tr>`
                      )
                      .join("")}
                  </tbody>
                </table></div>`
          }
        </div>
      </div>

      <!-- Overview / Stats Column -->
      <div style="display:flex;flex-direction:column;gap:16px">
        <div class="card card-pad">
          <div class="h2" style="margin-bottom:16px">Promotions Overview</div>
          <div class="stat-strip" style="grid-template-columns:1fr;margin-bottom:0">
            <div class="s-mini"><div class="l">First-Order Rate</div><div class="v">${firstOrderPct}%</div></div>
            <div class="s-mini"><div class="l">Total Promo Codes</div><div class="v">${totalPromos}</div></div>
            <div class="s-mini"><div class="l">Active Promos</div><div class="v">${activePromos}</div></div>
            <div class="s-mini"><div class="l">Inactive Promos</div><div class="v">${inactivePromos}</div></div>
          </div>
        </div>

        <div class="card card-pad" style="border-left:4px solid var(--accent, #6366f1)">
          <div class="h3" style="margin-bottom:8px;font-size:14px;font-weight:700">Promotion Rules V1</div>
          <ul style="margin:0;padding-left:18px;font-size:12px;color:var(--text-muted);display:flex;flex-direction:column;gap:6px">
            <li><strong>Single Discount:</strong> Customers receive exactly one promotional discount per booking.</li>
            <li><strong>Stacking Priority:</strong> A valid promo code always supersedes the first-order discount.</li>
            <li><strong>First-Order Eligibility:</strong> Applies only to customers with 0 completed/paid bookings. Cancelled or failed bookings do not burn eligibility.</li>
            <li><strong>Case-Insensitive:</strong> Promo codes can be typed in uppercase or lowercase by customers.</li>
          </ul>
        </div>
      </div>
    `;

    // Bind First-Order Save
    const foSaveBtn = promoWrap.querySelector("#fo-save-btn");
    if (foSaveBtn) {
      foSaveBtn.addEventListener("click", async () => {
        const input = promoWrap.querySelector("#fo-discount-input");
        const val = parseInt(input.value, 10);
        if (isNaN(val) || val < 0 || val > 100) {
          toast("Discount percentage must be between 0 and 100", "warning");
          return;
        }
        foSaveBtn.disabled = true;
        try {
          await api.put("/promos/first-order", { percentage: val });
          toast(`First-order discount updated to ${val}%`, "success");
          firstOrderPct = val;
          renderPromotions();
        } catch (err) {
          toast(errorMessage(err), "error");
          foSaveBtn.disabled = false;
        }
      });
    }

    // Bind Add Promo Button
    const addBtn = promoWrap.querySelector("#p-add-table");
    if (addBtn) addBtn.addEventListener("click", () => openPromoModal());
  }

  function openPromoModal() {
    openModal({
      title: "New Promo Code",
      body: `
        <div class="field"><label class="req">Promo Code</label>
          <input class="input" id="p-code" maxlength="30" placeholder="e.g. WELCOME25" style="text-transform:uppercase">
          <div class="muted" style="margin-top:4px">Letters, numbers, dashes. Automatically converted to uppercase.</div>
        </div>
        <div class="field"><label class="req">Discount Percentage (%)</label>
          <input type="number" class="input" id="p-discount" min="1" max="100" value="20" placeholder="1 to 100">
        </div>
        <div class="field" style="margin-top:10px">
          <label style="display:flex;align-items:center;gap:8px;cursor:pointer">
            <input type="checkbox" id="p-enabled" checked style="width:16px;height:16px">
            <span>Enabled (Active immediately)</span>
          </label>
        </div>
      `,
      footer: `
        <button class="btn btn-ghost" data-close>Cancel</button>
        <button class="btn btn-primary" data-save>Create Promo Code</button>
      `,
    });

    const overlay = [...document.querySelectorAll(".modal-overlay")].at(-1);
    overlay.querySelector("[data-close]").addEventListener("click", closeTopModal);
    overlay.querySelector("[data-save]").addEventListener("click", async () => {
      const code = overlay.querySelector("#p-code").value.trim().toUpperCase();
      const discountVal = parseInt(overlay.querySelector("#p-discount").value, 10);
      const enabled = overlay.querySelector("#p-enabled").checked;

      if (!code || code.length < 2) {
        toast("Please provide a valid promo code (at least 2 characters)", "warning");
        return;
      }
      if (isNaN(discountVal) || discountVal < 1 || discountVal > 100) {
        toast("Discount percentage must be between 1 and 100", "warning");
        return;
      }

      const saveBtn = overlay.querySelector("[data-save]");
      saveBtn.disabled = true;
      try {
        await api.post("/promos", {
          code,
          discountPercentage: discountVal,
          enabled,
        });
        toast(`Promo code ${code} created`, "success");
        closeTopModal();
        loadPromotions();
      } catch (err) {
        saveBtn.disabled = false;
        toast(errorMessage(err), "error");
      }
    });
  }

  async function togglePromoStatus(promo) {
    const action = promo.enabled ? "deactivate" : "activate";
    try {
      await api.put(`/promos/${promo.id}/toggle`);
      toast(`Promo code ${promo.code} ${action}d`, "success");
      loadPromotions();
    } catch (err) {
      toast(errorMessage(err), "error");
    }
  }

  async function deletePromo(promo) {
    const ok = await confirmDialog({
      title: "Delete promo code?",
      message: `Promo code "${escapeHtml(promo.code)}" will be permanently removed.`,
      confirmLabel: "Delete",
      danger: true,
    });
    if (!ok) return;
    try {
      await api.delete(`/promos/${promo.id}`);
      toast(`Promo code ${promo.code} deleted`, "success");
      loadPromotions();
    } catch (err) {
      toast(errorMessage(err), "error");
    }
  }

  document.getElementById("p-add")?.addEventListener("click", () => openPromoModal());

  promoWrap.addEventListener("click", (e) => {
    const tr = e.target.closest("tr[data-promo-id]");
    if (!tr) return;
    const promo = promoCodes.find((x) => x.id === Number(tr.dataset.promoId));
    if (!promo) return;
    if (e.target.closest("[data-toggle-promo]")) {
      togglePromoStatus(promo);
    } else if (e.target.closest("[data-del-promo]")) {
      deletePromo(promo);
    }
  });

  // Initial load
  await loadSettings();
});
