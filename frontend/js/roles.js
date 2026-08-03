/* ============================================================
   MaidItQuick Admin â€” roles.js
   Roles + permission matrix editor
   ============================================================ */

import { api, unwrap, errorMessage } from "./api.js";
import { registerModule, pageHeader, badge, toast, confirmDialog, icon, openModal, closeTopModal, showSpinner, hideSpinner, exportCsvFile, printReport } from "./app.js";
import { escapeHtml } from "./utils.js";
import * as auth from "./auth.js";

registerModule("roles", async (el) => {
  const canWrite = auth.hasPermission("ROLES_WRITE");
  el.innerHTML = pageHeader(
    "Roles",
    "Role-based access control â€” assign permissions to roles.",
    `
    <button class="btn btn-ghost" id="roles-csv">${icon("i-download")} CSV</button>
    <button class="btn btn-ghost" id="roles-print">${icon("i-print")} Print</button>
    ${canWrite ? `<button class="btn btn-primary" id="roles-add">${icon("i-plus")} New role</button>` : ""}
    `
  );

  const card = document.createElement("div");
  card.className = "card fade-up";
  const body = document.createElement("div");
  body.id = "roles-body";
  body.innerHTML = `<div class="state-box"><div class="spinner-inline" style="width:30px;height:30px"></div></div>`;
  card.appendChild(body);
  el.appendChild(card);

  let roles = [];
  let permissions = [];

  async function load() {
    try {
      [roles, permissions] = await Promise.all([
        unwrap(await api.get("/roles")) || [],
        unwrap(await api.get("/roles/permissions")) || [],
      ]);
      render();
    } catch (err) {
      body.innerHTML = `<div class="state-box"><p class="muted">${escapeHtml(errorMessage(err))}</p></div>`;
    }
  }

  const columns = [
    { key: "code", title: "Code" },
    { key: "name", title: "Name" },
    { key: "permissions", title: "Permissions" },
    { key: "", title: "Actions" },
  ];

  function render() {
    body.innerHTML = `
      <div class="table-wrap"><table class="table">
        <thead><tr>${columns.map((c) => `<th>${escapeHtml(c.title)}</th>`).join("")}</tr></thead>
        <tbody>${roles
          .map(
            (r) => `<tr data-id="${r.id}">
              <td><span class="mono">${escapeHtml(r.code)}</span></td>
              <td><strong>${escapeHtml(r.name)}</strong></td>
              <td>
                <div style="display:flex;gap:5px;flex-wrap:wrap;max-width:520px">
                  ${(r.permissions || []).slice(0, 4).map((p) => `<span class="badge st-INFO">${escapeHtml(p.code)}</span>`).join("")}
                  ${(r.permissions || []).length > 4 ? `<span class="badge st-gray badge-gray">+${r.permissions.length - 4}</span>` : ""}
                </div>
              </td>
              <td class="text-right"><div class="actions">
                ${canWrite ? `<button class="btn btn-ghost btn-icon-sm" data-edit title="Edit"><svg width="15" height="15"><use href="#i-edit"/></svg></button>` : ""}
                ${canWrite ? `<button class="btn btn-ghost btn-icon-sm" data-del title="Delete" style="color:var(--danger)"><svg width="15" height="15"><use href="#i-trash"/></svg></button>` : ""}
              </div></td>
            </tr>`
          )
          .join("")}
        </tbody></table></div>`;

    if (roles.length === 0) {
      body.innerHTML += `<div class="table-empty"><div class="icon"><svg width="22" height="22"><use href="#i-box"/></svg></div>No roles yet.</div>`;
    }
  }

  function openRoleModal(role = null) {
    const isEdit = Boolean(role);
    const selected = new Set((role?.permissions || []).map((p) => p.code));
    const permHtml = permissions
      .map(
        (p) => `
      <label class="perm-chip ${selected.has(p.code) ? "checked" : ""}" data-code="${escapeHtml(p.code)}">
        <input type="checkbox" ${selected.has(p.code) ? "checked" : ""}>
        <span>${escapeHtml(p.code)}</span>
      </label>`
      )
      .join("");

    openModal({
      title: isEdit ? `Edit role â€” ${role.name}` : "New role",
      size: "lg",
      body: `
        <div class="form-grid">
          <div class="field"><label class="req">Code</label>
            <input class="input" id="r-code" value="${escapeHtml(role?.code || "")}" placeholder="e.g. OPERATIONS" maxlength="80">
          </div>
          <div class="field"><label class="req">Name</label>
            <input class="input" id="r-name" value="${escapeHtml(role?.name || "")}" placeholder="e.g. Operations Manager" maxlength="120">
          </div>
        </div>
        <div class="field">
          <label>Permissions</label>
          <div class="perm-grid">${permHtml}</div>
        </div>`,
      footer: `
        <button class="btn btn-ghost" data-close>Cancel</button>
        <button class="btn btn-primary" data-save>${isEdit ? "Save changes" : "Create role"}</button>`,
    });

    const overlay = [...document.querySelectorAll(".modal-overlay")].at(-1);
    overlay.addEventListener("click", (e) => {
      const chip = e.target.closest(".perm-chip");
      if (chip) {
        chip.classList.toggle("checked");
        const input = chip.querySelector("input");
        input.checked = !input.checked;
      }
    });
    overlay.querySelector("[data-close]").addEventListener("click", closeTopModal);
    overlay.querySelector("[data-save]").addEventListener("click", async () => {
      const code = overlay.querySelector("#r-code").value.trim();
      const name = overlay.querySelector("#r-name").value.trim();
      const permissionCodes = [...overlay.querySelectorAll(".perm-chip.checked")].map((c) => c.dataset.code);
      if (!code || !name) {
        toast("Code and name are required", "warning");
        return;
      }
      const btn = overlay.querySelector("[data-save]");
      btn.disabled = true;
      try {
        if (isEdit) {
          await api.put(`/roles/${role.id}`, { code, name, permissionCodes });
          toast("Role updated", "success");
        } else {
          await api.post("/roles", { code, name, permissionCodes });
          toast("Role created", "success");
        }
        closeTopModal();
        load();
      } catch (err) {
        btn.disabled = false;
        toast(errorMessage(err), "error");
      }
    });
  }

  async function removeRole(role) {
    const ok = await confirmDialog({
      title: `Delete role ${role.code}?`,
      message: `Role "${escapeHtml(role.name)}" will be removed permanently. Roles assigned to administrators cannot be deleted.`,
      confirmLabel: "Delete",
      danger: true,
    });
    if (!ok) return;
    try {
      await api.delete(`/roles/${role.id}`);
      toast("Role deleted", "success");
      load();
    } catch (err) {
      toast(errorMessage(err), "error");
    }
  }

  document.getElementById("roles-add")?.addEventListener("click", () => openRoleModal());
  document.getElementById("roles-csv").addEventListener("click", () => {
    exportCsvFile("roles", columns, roles.map((r) => ({ code: r.code, name: r.name, permissions: (r.permissions || []).map((p) => p.code).join(" ") })));
  });
  document.getElementById("roles-print").addEventListener("click", () => {
    printReport(
      "Roles â€” MaidItQuick Admin",
      "Role-based access control",
      [
        { title: "Code", printValue: (r) => r.code },
        { title: "Name", printValue: (r) => r.name },
        { title: "Permissions", printValue: (r) => (r.permissions || []).map((p) => p.code).join(", ") },
      ],
      roles
    );
  });

  body.addEventListener("click", (e) => {
    const tr = e.target.closest("tr[data-id]");
    if (!tr) return;
    const role = roles.find((r) => r.id === Number(tr.dataset.id));
    if (!role) return;
    if (e.target.closest("[data-edit]")) openRoleModal(role);
    else if (e.target.closest("[data-del]")) removeRole(role);
  });

  await load();
});
