/* ============================================================
   MaidItQuick Admin — api.js
   Single Fetch API wrapper: GET / POST / PUT / PATCH / DELETE.
   - Attaches the JWT automatically
   - On 401: silent refresh once, then retry the request
   - If refresh fails: dispatches `app:session-expired` (app.js
     listens and redirects to login)
   ============================================================ */

// Backend base: if the page is served from the Vite-like dev origin (5173),
// target the API on 8083; otherwise assume same-origin hosting.
const DEV_ORIGIN = "http://localhost:5173";
export const API_BASE =
  window.location.origin === DEV_ORIGIN || window.location.hostname === "localhost"
    ? "http://localhost:8083/api/v1/admin"
    : "/api/v1/admin";

// Origin of the backend (for /uploads/... document images).
export const API_ORIGIN = API_BASE.replace(/\/api\/v1\/admin$/, "");

let accessToken = null;

export function setAccessToken(token) {
  accessToken = token || null;
}

export function getAccessToken() {
  return accessToken;
}

export class ApiError extends Error {
  constructor(status, message, errors = null) {
    super(message || `Request failed (${status})`);
    this.name = "ApiError";
    this.status = status;
    this.errors = errors || null;
  }
}

/* ---- low level request ---- */
const REQUEST_TIMEOUT_MS = 15000;

async function rawRequest(method, path, body, token) {
  const headers = { Accept: "application/json" };
  if (body !== undefined) headers["Content-Type"] = "application/json";
  if (token) headers["Authorization"] = `Bearer ${token}`;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  let response;
  try {
    response = await fetch(`${API_BASE}${path}`, {
      method,
      headers,
      body: body !== undefined ? JSON.stringify(body) : undefined,
      credentials: "include",
      signal: controller.signal,
    });
  } catch (err) {
    throw new TypeError(`Request timed out or failed (${path})`);
  } finally {
    clearTimeout(timer);
  }

  if (response.status === 204) return null;

  let payload = null;
  const text = await response.text();
  if (text) {
    try {
      payload = JSON.parse(text);
    } catch {
      payload = null;
    }
  }

  if (!response.ok) {
    const message = payload?.message || `Request failed (${response.status})`;
    const errors = payload?.errors || null;
    throw new ApiError(response.status, message, errors);
  }

  return payload;
}

let refreshing = null;

// Auth endpoints must never trigger the silent-refresh retry loop.
const AUTH_ENDPOINTS = new Set([
  "/auth/login",
  "/auth/refresh",
  "/auth/logout",
  "/login",
  "/refresh-token",
]);

async function refreshToken() {
  // POST /refresh-token reads the httpOnly cookie automatically.
  const response = await fetch(`${API_BASE}/refresh-token`, {
    method: "POST",
    credentials: "include",
    headers: { Accept: "application/json" },
  });
  if (!response.ok) throw new ApiError(response.status, "Session expired");
  return response.json();
}

async function request(method, path, body) {
  try {
    const payload = await rawRequest(method, path, body, accessToken);
    // Login/refresh endpoints are not envelope-wrapped; modules unwrap explicitly.
    return payload;
  } catch (err) {
    if (err instanceof ApiError && err.status === 401 && !AUTH_ENDPOINTS.has(path)) {
      if (!refreshing) {
        refreshing = refreshToken()
          .then((tokens) => {
            setAccessToken(tokens.accessToken);
            window.dispatchEvent(new CustomEvent("app:token-refreshed", { detail: tokens }));
            return tokens;
          })
          .finally(() => {
            refreshing = null;
          });
      }
      try {
        await refreshing;
        return await rawRequest(method, path, body, accessToken);
      } catch (refreshErr) {
        setAccessToken(null);
        window.dispatchEvent(new CustomEvent("app:session-expired"));
        throw refreshErr;
      }
    }
    throw err;
  }
}

/* ---- public API ---- */
export const api = {
  get: (path) => request("GET", path),
  post: (path, body) => request("POST", path, body),
  put: (path, body) => request("PUT", path, body),
  patch: (path, body) => request("PATCH", path, body),
  delete: (path) => request("DELETE", path),
  // Multipart upload: { identity, address, identityDocType } — FormData from caller.
  upload: (path, formData) => uploadRequest(path, formData),
};

/* ---- multipart request with token + one silent refresh ---- */
async function uploadRequest(path, formData) {
  const doFetch = (token) =>
    fetch(`${API_BASE}${path}`, {
      method: "POST",
      headers: token ? { Authorization: `Bearer ${token}` } : {},
      body: formData,
      credentials: "include",
    });
  let response = await doFetch(accessToken);
  if (response.status === 401) {
    try {
      await refreshToken().then((t) => setAccessToken(t.accessToken));
    } catch {
      setAccessToken(null);
      window.dispatchEvent(new CustomEvent("app:session-expired"));
      throw new ApiError(401, "Session expired");
    }
    response = await doFetch(accessToken);
  }
  const text = await response.text();
  const payload = text ? JSON.parse(text) : null;
  if (!response.ok) {
    throw new ApiError(response.status, payload?.message || `Request failed (${response.status})`, payload?.errors || null);
  }
  return payload;
}

/* ---- unwrap helpers ---- */
// Standard envelope: { success, message, data, timestamp }
export function unwrap(payload) {
  return payload ? payload.data : undefined;
}

// Raw Spring Page for /audit: { content, totalElements, number, size, totalPages }
export function pageOf(payload) {
  if (!payload) return { items: [], page: 0, size: 20, total: 0, totalPages: 0 };
  return {
    items: payload.content || payload.items || [],
    page: payload.number ?? payload.page ?? 0,
    size: payload.size ?? 20,
    total: payload.totalElements ?? payload.total ?? 0,
    totalPages: payload.totalPages ?? 0,
  };
}

export function errorMessage(err) {
  if (err instanceof ApiError) {
    if (err.errors && typeof err.errors === "object") {
      const first = Object.values(err.errors)[0];
      return `${err.message}: ${first}`;
    }
    return err.message;
  }
  if (err instanceof TypeError) return "Unable to connect to the server";
  return err?.message || "Unexpected error";
}
