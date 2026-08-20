/* MaidItQuick Admin — canonical service catalogue + PIN pricing */
import { api, rootApi, unwrap } from "./api.js";
import { registerModule, pageHeader, openModal, closeTopModal, toast, activeBadge, fetchAllPages } from "./app.js";
import { escapeHtml, money } from "./utils.js";

const rupees = (paise) => Number(paise || 0) / 100;
const payout = (paise, pct) => Math.round(Number(paise || 0) * (100 - pct) / 100);

async function loadCommission() {
  try {
    const value = unwrap(await api.get("/settlements/commission"));
    return Number(value ?? 20);
  } catch { return 20; }
}

const loadServices = () => rootApi.get("/api/services/admin");

function serviceRows(services, pct) {
  if (!services.length) return `<tr><td colspan="6" class="empty-cell">No services configured.</td></tr>`;
  return services.map((service) => `<tr>
    <td><div class="cell-main"><span class="cell-avatar">${escapeHtml(service.emoji || (service.name || "?")[0])}</span><div><strong>${escapeHtml(service.name)}</strong><div class="meta">${escapeHtml(service.description || "No description")}</div></div></div></td>
    <td><strong>${money(rupees(service.pricePaise))}</strong><div class="meta">Default customer price</div></td>
    <td><strong>${money(rupees(payout(service.pricePaise, pct)))}</strong><div class="meta">After ${pct}% commission</div></td>
    <td>${service.defaultDurationMinutes || 60} min</td><td>${activeBadge(service.enabled)}</td>
    <td class="text-right"><button class="btn btn-sm btn-ghost" data-edit="${service.id}">Edit</button> <button class="btn btn-sm btn-primary" data-areas="${service.id}">PIN pricing</button></td>
  </tr>`).join("");
}

function serviceForm(service = {}) {
  return `<form id="catalog-service-form" novalidate><div class="form-grid">
    <div class="field"><label>Service name</label><input class="input" name="name" required maxlength="120" value="${escapeHtml(service.name || "")}"></div>
    <div class="field"><label>Default customer price (₹)</label><input class="input" name="priceRupees" type="number" required min="1" step="1" value="${rupees(service.pricePaise) || ""}"></div>
    <div class="field"><label>Duration (minutes)</label><input class="input" name="duration" type="number" required min="1" value="${service.defaultDurationMinutes || 60}"></div>
    <div class="field"><label>Status</label><select class="input" name="enabled"><option value="true" ${service.enabled !== false ? "selected" : ""}>Available</option><option value="false" ${service.enabled === false ? "selected" : ""}>Unavailable</option></select></div>
    <div class="field span2"><label>Description</label><textarea class="input" name="description" maxlength="1000">${escapeHtml(service.description || "")}</textarea></div>
  </div></form>`;
}

async function editService(service, reload) {
  openModal({ title: service ? "Edit service" : "Add service", body: serviceForm(service), footer: `<button class="btn btn-ghost" data-close>Cancel</button><button class="btn btn-primary" id="save-catalog-service">Save service</button>` });
  document.getElementById("save-catalog-service").addEventListener("click", async () => {
    const form = document.getElementById("catalog-service-form");
    if (!form.reportValidity()) return;
    const data = new FormData(form);
    const priceRupees = Math.round(Number(data.get("priceRupees")));
    const body = { name: String(data.get("name")).trim(), priceRupees, description: String(data.get("description") || ""), defaultDurationMinutes: Number(data.get("duration")), enabled: data.get("enabled") === "true" };
    try {
      if (service) await rootApi.put(`/api/services/admin/${service.id}`, body);
      else {
        const created = await rootApi.post("/api/services", { name: body.name, priceRupees });
        await rootApi.put(`/api/services/admin/${created.id}`, body);
      }
      closeTopModal(); toast("Service saved", "success"); await reload();
    } catch (err) { toast(err.message || "Could not save service", "error"); }
  });
}

function areaRows(areas, pct) {
  if (!areas.length) return `<tr><td colspan="6" class="empty-cell">No service areas configured yet.</td></tr>`;
  return areas.map((area) => `<tr data-area-row="${area.areaId}">
    <td><strong>${escapeHtml(area.pinCode)}</strong></td><td>${escapeHtml(area.locality || "—")}</td>
    <td><input class="input" data-area-price type="number" min="1" step="1" value="${rupees(area.pricePaise)}" style="max-width:130px"></td>
    <td data-worker-preview>${money(rupees(payout(area.pricePaise, pct)))}</td>
    <td><select class="input" data-area-enabled><option value="true" ${area.enabled ? "selected" : ""}>Available</option><option value="false" ${!area.enabled ? "selected" : ""}>Unavailable</option></select></td>
    <td class="text-right"><button class="btn btn-sm btn-primary" data-save-area>Save</button></td>
  </tr>`).join("");
}

async function editAreas(service, pct) {
  let areas;
  try { areas = await rootApi.get(`/api/services/admin/${service.id}/areas`); }
  catch (err) { toast(err.message || "Could not load PIN pricing", "error"); return; }
  openModal({ title: `${service.name} — PIN pricing`, size: "lg", body: `<p class="muted" style="margin-bottom:16px">Set the exact customer price and availability for each PIN code. Worker preview deducts the current ${pct}% commission.</p><div class="table-wrap"><table class="table"><thead><tr><th>PIN code</th><th>Locality</th><th>Customer price (₹)</th><th>Worker gets</th><th>Service</th><th></th></tr></thead><tbody>${areaRows(areas, pct)}</tbody></table></div>`, footer: `<button class="btn btn-primary" data-close>Done</button>` });
  document.querySelectorAll("[data-area-row]").forEach((row) => {
    const price = row.querySelector("[data-area-price]");
    price.addEventListener("input", () => { row.querySelector("[data-worker-preview]").textContent = money(Number(price.value || 0) * (100 - pct) / 100); });
    row.querySelector("[data-save-area]").addEventListener("click", async (event) => {
      if (!price.reportValidity()) return;
      event.currentTarget.disabled = true;
      try {
        await rootApi.put(`/api/services/admin/${service.id}/areas/${row.dataset.areaRow}`, { priceRupees: Math.round(Number(price.value)), enabled: row.querySelector("[data-area-enabled]").value === "true" });
        toast(`Pricing saved for ${row.children[0].textContent.trim()}`, "success");
      } catch (err) { toast(err.message || "Could not save PIN pricing", "error"); }
      finally { event.currentTarget.disabled = false; }
    });
  });
}

registerModule("services", async (el) => {
  let services = [], commissionPct = 20;
  const render = () => {
    el.innerHTML = `${pageHeader("Services", "Control the customer price and availability of every mobile service by PIN code.", `<button class="btn btn-primary" id="add-catalog-service">Add service</button>`)}<div class="card"><div class="card-header"><div><strong>Mobile service catalogue</strong><div class="meta">Workers see customer price less ${commissionPct}% commission.</div></div></div><div class="table-wrap"><table class="table"><thead><tr><th>Service</th><th>Customer price</th><th>Worker gets</th><th>Duration</th><th>Status</th><th class="text-right">Actions</th></tr></thead><tbody>${serviceRows(services, commissionPct)}</tbody></table></div></div>`;
    document.getElementById("add-catalog-service").addEventListener("click", () => editService(null, reload));
    el.querySelectorAll("[data-edit]").forEach((button) => button.addEventListener("click", () => editService(services.find((s) => s.id === Number(button.dataset.edit)), reload)));
    el.querySelectorAll("[data-areas]").forEach((button) => button.addEventListener("click", () => editAreas(services.find((s) => s.id === Number(button.dataset.areas)), commissionPct)));
  };
  const reload = async () => {
    try { [services, commissionPct] = await Promise.all([loadServices(), loadCommission()]); render(); }
    catch (err) { el.innerHTML = `${pageHeader("Services", "Manage mobile services and PIN pricing.")}<div class="card empty-state">${escapeHtml(err.message || "Could not load services")}</div>`; }
  };
  await reload();
});

// Legacy admin booking forms still reference the operations service table.
export async function serviceOptions() {
  try { return (await fetchAllPages("/services")).map((service) => [service.id, service.name]); }
  catch { return []; }
}
