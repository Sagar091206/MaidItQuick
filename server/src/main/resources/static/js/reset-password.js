/* ============================================================
   MaidItQuick Admin — reset-password.js (US 1.3)
   Reads ?token= from the emailed link, validates the new password
   (min 8, match), POSTs /api/v1/admin/reset-password.
   Invalid/expired/used token -> dedicated "request a new link" panel.
   ============================================================ */

import { api, ApiError, errorMessage } from "./api.js";

const form = document.getElementById("reset-form");
const passInput = document.getElementById("password");
const confirmInput = document.getElementById("password-confirm");
const errorBox = document.getElementById("reset-error");
const btn = document.getElementById("reset-btn");
const btnLabel = document.getElementById("reset-btn-label");
const donePanel = document.getElementById("reset-done");
const invalidPanel = document.getElementById("reset-invalid");

const token = new URLSearchParams(window.location.search).get("token") || "";

/* Status -> user-facing message (US 1.3 error contract). */
const STATUS_MESSAGES = {
  400: "This password reset link is invalid or has expired. Request a new one.",
  429: "Too many requests. Please wait a while and try again.",
  500: "Unable to process your request. Please try again later.",
};

function describeError(err) {
  if (err instanceof TypeError) {
    return "Unable to connect to the server. Is the API running?";
  }
  if (err instanceof ApiError && STATUS_MESSAGES[err.status]) {
    return STATUS_MESSAGES[err.status];
  }
  return errorMessage(err);
}

function showError(msg) {
  errorBox.textContent = msg;
  errorBox.classList.remove("hidden");
}

function hideError() {
  errorBox.classList.add("hidden");
}

function fieldError(id, msg) {
  const el = document.getElementById(id);
  el.textContent = msg;
  el.classList.toggle("hidden", !msg);
}

/* Show / hide password (shared by both eye toggles). */
function wireToggle(toggleId, inputId, eyeId, pupilId, visibleId) {
  let visible = false;
  document.getElementById(toggleId).addEventListener("click", () => {
    visible = !visible;
    const input = document.getElementById(inputId);
    input.type = visible ? "text" : "password";
    document.getElementById(toggleId).setAttribute("aria-label", visible ? "Hide password" : "Show password");
    document.getElementById(toggleId).classList.toggle("active", visible);
  });
}
wireToggle("pw-toggle", "password", "pw-eye", "pw-pupil");
wireToggle("pw-toggle-2", "password-confirm", "pw-eye-2", "pw-pupil-2");

function setLoading(loading) {
  btn.disabled = loading;
  if (loading) {
    btnLabel.innerHTML = '<span class="spinner-inline"></span> Changing Password…';
  } else {
    btnLabel.textContent = "Change Password";
  }
}

form.addEventListener("submit", async (e) => {
  e.preventDefault();
  hideError();
  fieldError("pass-err", "");
  fieldError("confirm-err", "");

  const password = passInput.value;
  const confirm = confirmInput.value;

  let valid = true;
  if (!password) {
    fieldError("pass-err", "Password is required");
    valid = false;
  } else if (password.length < 8) {
    fieldError("pass-err", "Password must be at least 8 characters");
    valid = false;
  } else if (password.length > 128) {
    fieldError("pass-err", "Password must be at most 128 characters");
    valid = false;
  }
  if (!confirm) {
    fieldError("confirm-err", "Please repeat the password");
    valid = false;
  } else if (confirm !== password) {
    fieldError("confirm-err", "Passwords do not match");
    valid = false;
  }
  if (!valid) return;

  setLoading(true);
  try {
    await api.post("/reset-password", { token, newPassword: password });
    form.classList.add("hidden");
    donePanel.classList.remove("hidden");
  } catch (err) {
    setLoading(false);
    if (err instanceof ApiError && err.status === 400) {
      form.classList.add("hidden");
      invalidPanel.classList.remove("hidden");
    } else {
      showError(describeError(err));
    }
  }
});
