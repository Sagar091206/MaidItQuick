/* ============================================================
   MaidItQuick Admin â€” settings.js
   Key/value application settings
   ============================================================ */

import { api, unwrap, errorMessage } from "./api.js";
import { registerModule, pageHeader, toast, confirmDialog, icon, openModal, closeTopModal, badge, exportCsvFile, printReport } from "./app.js";
import { escapeHtml, fmtDateTime } from "./utils.js";
import * as auth from "./auth.js";

registerModule("settings", async (el) => {
  const canWrite = auth.hasPermission("SETTINGS_WRITE");
  el.innerHTML = pageHeader(
    "Settings",
    "Key/value configuration for the platform.",
    `
    <button class="btn btn-ghost" id="s-csv">${icon("i-download")} CSV</button>
    <button class="btn btn-ghost" id="s-print">${icon("i-print")} Print</button>
    ${canWrite ? `<button class="btn btn-primary" id="s-add">${icon("i-plus")} New setting</button>` : ""}
    `
  );

  const wrap = document.createElement("div");
  wrap.className = "settings-grid fade-up";
  wrap.innerHTML = `<div class="card" style="grid-column:1/-1"><div class="state-box"><div class="spinner-inline" style="width:30px;height:30px"></div></div></div>`;
  el.appendChild(wrap);

  let items = [];

  async function load() {
    try {
      items = unwrap(await api.get("/settings")) || [];
      render();
    } catch (err) {
      wrap.innerHTML = `<div class="card" style="grid-column:1/-1"><div class="state-box"><p class="muted">${escapeHtml(errorMessage(err))}</p></div></div>`;
    }
  }

  function render() {
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
                <td class="muted ellipsis" style="max-width:180px">${escapeHtml(s.description || "â€”")}</td>
                <td class="text-right muted">${s.updatedAt ? fmtDateTime(s.updatedAt) : "â€”"}</td>
                ${canWrite ? `<td class="text-right"><div class="actions">
                  <button class="btn btn-ghost btn-icon-sm" data-edit><svg width="15" height="15"><use href="#i-edit"/></svg></button>
                  <button class="btn btn-ghost btn-icon-sm" data-del style="color:var(--danger)"><svg width="15" height="15"><use href="#i-trash"/></svg></button>
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
      title: s ? `Edit setting â€” ${s.settingKey}` : "New setting",
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
        load();
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
      load();
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
    printReport("Settings â€” MaidItQuick Admin", "Key/value configuration", [
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

  await load();
});
