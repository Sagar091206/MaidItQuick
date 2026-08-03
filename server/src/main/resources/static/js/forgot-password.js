/* ============================================================
   MaidItQuick Admin — forgot-password.js (US 1.2)
   Validate email -> POST /api/v1/admin/forgot-password.
   Server always answers 200 with a generic message (no account
   enumeration); failures show a generic error panel.
   ============================================================ */

import { api, ApiError, errorMessage } from "./api.js";

const form = document.getElementById("forgot-form");
const emailInput = document.getElementById("email");
const errorBox = document.getElementById("forgot-error");
const btn = document.getElementById("forgot-btn");
const btnLabel = document.getElementById("forgot-btn-label");
const sentPanel = document.getElementById("reset-sent");

/* Status -> user-facing message (US 1.2 error contract). */
const STATUS_MESSAGES = {
  429: "Too many password reset requests. Please wait a while and try again.",
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

function setLoading(loading) {
  btn.disabled = loading;
  if (loading) {
    btnLabel.innerHTML = '<span class="spinner-inline"></span> Sending Reset Link…';
  } else {
    btnLabel.textContent = "Send Reset Link";
  }
}

form.addEventListener("submit", async (e) => {
  e.preventDefault();
  hideError();
  fieldError("email-err", "");

  const email = emailInput.value.trim().toLowerCase();

  /* Client-side validation — never call the API on invalid input. */
  if (!email) {
    fieldError("email-err", "Email is required");
    return;
  }
  if (email.length > 254) {
    fieldError("email-err", "Email must be at most 254 characters");
    return;
  }
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    fieldError("email-err", "Enter a valid email address");
    return;
  }

  setLoading(true);
  try {
    await api.post("/forgot-password", { email });
    form.classList.add("hidden");
    sentPanel.classList.remove("hidden");
  } catch (err) {
    setLoading(false);
    showError(describeError(err));
  }
});
