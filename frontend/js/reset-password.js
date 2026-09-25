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

const SPECIAL_CHARS = /[!@#$%^&*]/;

function evaluatePassword(pwd) {
  return {
    len: pwd.length >= 8 && pwd.length <= 128,
    upper: /[A-Z]/.test(pwd),
    lower: /[a-z]/.test(pwd),
    num: /\d/.test(pwd),
    special: SPECIAL_CHARS.test(pwd),
  };
}

function updateRequirements() {
  const pwd = passInput.value || "";
  const conf = confirmInput.value || "";
  const reqs = evaluatePassword(pwd);

  function setReq(id, ok) {
    const el = document.getElementById(id);
    if (!el) return;
    el.classList.toggle("satisfied", ok);
    el.classList.toggle("not-satisfied", !ok);
    const icon = el.querySelector(".req-icon");
    if (icon) icon.textContent = ok ? "✓" : "✗";
  }

  setReq("req-len", reqs.len);
  setReq("req-upper", reqs.upper);
  setReq("req-lower", reqs.lower);
  setReq("req-num", reqs.num);
  setReq("req-special", reqs.special);

  const allReqsMet = reqs.len && reqs.upper && reqs.lower && reqs.num && reqs.special;
  const match = conf.length > 0 && conf === pwd;

  if (conf.length > 0 && !match) {
    fieldError("confirm-err", "Passwords do not match");
  } else {
    fieldError("confirm-err", "");
  }

  btn.disabled = !(allReqsMet && match);
}

passInput.addEventListener("input", updateRequirements);
confirmInput.addEventListener("input", updateRequirements);

// Run initially to ensure proper state on load
updateRequirements();

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
  const reqs = evaluatePassword(password);
  const allReqsMet = reqs.len && reqs.upper && reqs.lower && reqs.num && reqs.special;

  if (!allReqsMet) {
    fieldError("pass-err", "Please meet all password requirements");
    return;
  }
  if (!confirm) {
    fieldError("confirm-err", "Please repeat the password");
    return;
  }
  if (confirm !== password) {
    fieldError("confirm-err", "Passwords do not match");
    return;
  }

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
