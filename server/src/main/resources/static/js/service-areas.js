/* MaidItQuick Admin — serviceable PIN code management. */
import { rootApi } from "./api.js";
import { activeBadge, closeTopModal, openModal, pageHeader, registerModule, toast } from "./app.js";
import { escapeHtml } from "./utils.js";

const loadAreas = () => rootApi.get("/api/operations/areas");

function rows(areas) {
  if (!areas.length) return `<tr><td colspan="4" class="empty-cell">No service areas configured yet.</td></tr>`;
  return areas
    .sort((a, b) => String(a.pinCode).localeCompare(String(b.pinCode)))
    .map((area) => `<tr>
      <td><strong>${escapeHtml(area.pinCode)}</strong></td>
      <td>${escapeHtml(area.locality)}</td>
      <td>${activeBadge(area.enabled)}</td>
      <td class="text-right"><button class="btn btn-sm btn-ghost" data-toggle="${area.id}">${area.enabled ? "Disable" : "Enable"}</button></td>
    </tr>`)
    .join("");
}

function addAreaDialog(reload) {
  openModal({
    title: "Add service area",
    body: `<form id="service-area-form" novalidate><div class="form-grid">
      <div class="field"><label>PIN code</label><input class="input" name="pinCode" inputmode="numeric" pattern="[0-9]{6}" maxlength="6" required placeholder="e.g. 712248"></div>
      <div class="field"><label>Locality</label><input class="input" name="locality" maxlength="120" required placeholder="e.g. Kolkata"></div>
    </div><p class="muted" style="margin:14px 0 0">After adding the PIN, open Services → PIN pricing to enable each service and set its customer price.</p></form>`,
    footer: `<button class="btn btn-ghost" data-close>Cancel</button><button class="btn btn-primary" id="save-service-area">Add PIN code</button>`,
  });
  document.getElementById("save-service-area").addEventListener("click", async () => {
    const form = document.getElementById("service-area-form");
    if (!form.reportValidity()) return;
    const data = new FormData(form);
    const button = document.getElementById("save-service-area");
    button.disabled = true;
    try {
      await rootApi.post("/api/operations/areas", {
        pinCode: String(data.get("pinCode")).trim(),
        locality: String(data.get("locality")).trim(),
      });
      closeTopModal();
      toast("Service area added. Configure its services and prices next.", "success");
      await reload();
    } catch (err) {
      toast(err.message || "Could not add the PIN code", "error");
    } finally {
      button.disabled = false;
    }
  });
}

registerModule("service-areas", async (el) => {
  let areas = [];
  const render = () => {
    el.innerHTML = `${pageHeader("Service Areas", "Choose the PIN codes where customers can book MaidItQuick services.", `<button class="btn btn-primary" id="add-service-area">Add PIN code</button>`)}
      <div class="card"><div class="table-wrap"><table class="table"><thead><tr><th>PIN code</th><th>Locality</th><th>Status</th><th class="text-right">Action</th></tr></thead><tbody>${rows(areas)}</tbody></table></div></div>`;
    document.getElementById("add-service-area").addEventListener("click", () => addAreaDialog(reload));
    el.querySelectorAll("[data-toggle]").forEach((button) => button.addEventListener("click", async () => {
      const area = areas.find((item) => item.id === Number(button.dataset.toggle));
      if (!area) return;
      button.disabled = true;
      try {
        await rootApi.post(`/api/operations/areas/${area.id}/enabled`, { enabled: !area.enabled });
        toast(`PIN ${area.pinCode} ${area.enabled ? "disabled" : "enabled"}.`, "success");
        await reload();
      } catch (err) {
        toast(err.message || "Could not update the service area", "error");
      } finally {
        button.disabled = false;
      }
    }));
  };
  const reload = async () => {
    try {
      areas = await loadAreas();
      render();
    } catch (err) {
      el.innerHTML = `${pageHeader("Service Areas", "Manage serviceable PIN codes.")}<div class="card empty-state">${escapeHtml(err.message || "Could not load service areas")}</div>`;
    }
  };
  await reload();
});
