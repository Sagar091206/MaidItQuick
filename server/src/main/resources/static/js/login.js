/* ============================================================
   MaidItQuick Admin — login.js (US 1.1)
   Validate the form -> POST /api/v1/admin/login -> redirect.
   ============================================================ */

import { login, restoreSession } from "./auth.js";
import { ApiError, errorMessage } from "./api.js";

const form = document.getElementById("login-form");
const emailInput = document.getElementById("email");
const passInput = document.getElementById("password");
const rememberEl = document.getElementById("remember");
const pwToggle = document.getElementById("pw-toggle");
const errorBox = document.getElementById("login-error");
const btn = document.getElementById("login-btn");
const btnLabel = document.getElementById("login-btn-label");

/* Status -> user-facing message (US 1.1 error contract). */
const STATUS_MESSAGES = {
  401: "Invalid email or password.",
  403: "Account disabled. Contact an administrator.",
  404: "Admin not found.",
  429: "Too many login attempts. Please wait a few minutes and try again.",
  500: "Server error. Please try again later.",
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

/* Show / hide the password (eye toggle). */
let passwordVisible = false;
pwToggle.addEventListener("click", () => {
  passwordVisible = !passwordVisible;
  passInput.type = passwordVisible ? "text" : "password";
  pwToggle.setAttribute("aria-label", passwordVisible ? "Hide password" : "Show password");
  pwToggle.classList.toggle("active", passwordVisible);
});

function setLoading(loading) {
  btn.disabled = loading;
  if (loading) {
    btnLabel.innerHTML = '<span class="spinner-inline"></span> Signing in…';
  } else {
    btnLabel.textContent = "Sign in";
  }
}

form.addEventListener("submit", async (e) => {
  e.preventDefault();
  hideError();
  fieldError("email-err", "");
  fieldError("pass-err", "");

  const email = emailInput.value.trim();
  const password = passInput.value;

  /* Client-side validation — never call the API on invalid input. */
  let valid = true;
  if (!email) {
    fieldError("email-err", "Email is required");
    valid = false;
  } else if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    fieldError("email-err", "Enter a valid email address");
    valid = false;
  }
  if (!password) {
    fieldError("pass-err", "Password is required");
    valid = false;
  } else if (password.length < 8) {
    fieldError("pass-err", "Password must be at least 8 characters");
    valid = false;
  }
  if (!valid) return;

  setLoading(true);
  try {
    await login(email, password, rememberEl.checked);
    window.location.replace("dashboard.html#/dashboard");
  } catch (err) {
    setLoading(false);
    showError(describeError(err));
  }
});

// If a valid refresh cookie already exists, skip the login form.
restoreSession()
  .then(() => window.location.replace("dashboard.html#/dashboard"))
  .catch(() => {});
