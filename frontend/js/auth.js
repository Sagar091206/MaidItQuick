/* ============================================================
   MaidItQuick Admin — auth.js
   - Access JWT kept in memory only (never persisted to storage)
   - Sessions restored silently via the httpOnly refresh cookie
   - On any session loss the app redirects to login.html
   ============================================================ */

import { api, unwrap, setAccessToken, getAccessToken, API_BASE } from "./api.js";

let profile = null; // { id, email, name, role:{code,name}, permissions[] }
let authReady = null;

export function getProfile() {
  return profile;
}

export function getPermissions() {
  return profile?.permissions || [];
}

export function hasPermission(code) {
  return getPermissions().includes(code);
}

export function isAuthenticated() {
  return Boolean(getAccessToken());
}

/* ---- restore session on page load (silent) ---- */
export async function restoreSession() {
  if (authReady) return authReady;
  authReady = (async () => {
    // Already authenticated in this tab?
    if (getAccessToken()) {
      try {
        await loadProfile();
        return;
      } catch {
        /* fall through to cookie refresh */
      }
    }
    const response = await fetch(`${API_BASE}/refresh-token`, {
      method: "POST",
      credentials: "include",
      headers: { Accept: "application/json" },
    });
    if (!response.ok) throw new Error("Session expired");
    const tokens = await response.json();
    setAccessToken(tokens.accessToken);
    await loadProfile();
  })();
  return authReady;
}

export async function loadProfile() {
  const payload = await api.get("/auth/me");
  profile = unwrap(payload);
  return profile;
}

/* ---- login ---- */
export async function login(email, password, rememberMe = false) {
  const tokens = await api.post("/login", { email: email.trim(), password, rememberMe });
  setAccessToken(tokens.accessToken);
  profile = null;
  await loadProfile();
  return tokens;
}

/* ---- logout ---- */
export async function logout() {
  try {
    await api.post("/auth/logout");
  } catch {
    /* server session already gone — ignore */
  }
  setAccessToken(null);
  profile = null;
}

/* ---- avatar initial from profile ---- */
export function currentInitials() {
  if (!profile) return "?";
  return profile.name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0].toUpperCase())
    .join("");
}
