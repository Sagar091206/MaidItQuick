# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project layout

- `server/` — Spring Boot 3.5 (Java 21), Maven, Spring Security + JWT, JPA/Hibernate, MySQL. The merged monolith serving both the mobile API and the admin API from one process and one database. The admin SPA lives in `server/src/main/resources/static/` (synced from `frontend/` via `server/scripts/sync-admin-frontend.sh`).
- `frontend/` — vanilla HTML/CSS/JS admin SPA (no build step, no frameworks), embedded in the jar and also served statically.

## Commands

- Build server: `mvn clean package -DskipTests` from `server/` (jar: `server/target/makeitquick-server-0.1.0.jar`).
- Run server: `java -jar server/target/makeitquick-server-0.1.0.jar` (binds `localhost:8080`; admin UI + API same origin).
- Sync admin frontend into the jar: `server/scripts/sync-admin-frontend.sh`.
- Run frontend dev server: `python -m http.server 5173 --bind 0.0.0.0 --directory frontend`.
- Local SMTP sink (for password-reset emails): `python -u -m aiosmtpd -n -c aiosmtpd.handlers.Debugging -l localhost:1025` (unbuffered `-u` so the log file updates live).
- MySQL CLI used for DB checks: `"C:\Program Files\MySQL\MySQL Workbench 8.0 CE\mysql.exe" -h localhost -P 3306 -u root -p1234 maiditquick -e "<sql>"`.

## Verification scripts (in `C:\Users\Admin\AppData\Local\Temp\opencode\`)

All target the live backend on 8080 and self-clean their fixtures. Run with `node <file>`.

- `verify-us11.mjs` — US 1.1 login (JWT, refresh rotation, remember-me, lockout 429, error contract). 32 assertions.
- `verify-us12.mjs` — US 1.2 forgot password (generic 200, SMTP capture, hashed 15-min tokens, invalidation, rate limit 5/hr, audits). 25 assertions.
- `verify-us13.mjs` — US 1.3 reset password (redemption, single-use, session revocation, expiry, audits). 22 assertions.
- `verify-frontend.mjs` — E2E regression over every module incl. CORS preflight and logout. 62 assertions.
- `verify-journey.mjs` — real headless-Edge (CDP) journey: login → forgot → reset → login. 6 assertions. Needs the local SMTP sink (port 1025) running and, like `verify-ops-ui.mjs`, `undici` installed in the temp dir (Node 20.20.2 has no global `WebSocket`).
- `verify-ops.mjs` — Operations API suite: partner KYC approve/reject workflow, document upload + `/uploads/**` serving, partner suspend/activate/restore, customer soft-delete/restore, live bookings with coords/timestamps, ledger commission math (18%), filters, audit events. 36 assertions.
- `verify-ops-ui.mjs` — real headless-Edge (CDP) smoke test of the Operations tabs (partners KYC, customers, live ops with Leaflet map + timers, ledger with filters + CSV export). 41 assertions, self-provisions fresh partners if needed and self-cleans all fixtures. Uses `undici`'s `WebSocket` (global `WebSocket` is NOT defined in Node 20.20.2) — run from the temp dir where `undici` is installed.
- `verify-m9m10.mjs` — Returns + User Requests API suite: seeded counts, pending/open-count, create, approve/reject/refund with transition guards, issue-type category filters, replies, deletes, audit events. 29 assertions.
- `verify-modules-ui.mjs` — real headless-Edge (CDP) smoke test of the dashboard cards (Total Revenue, Total Bookings, Paid Bookings, Pending Refunds, Open User Requests — live counts) and the Returns / User Requests pages incl. detail modals. 18 assertions.
- `verify-m5-ui.mjs` — M5 partner-lifecycle UI suite: tab counts, KYC details modal (docs/bank), approve flow, suspend/activate badge toggle, soft-delete → Deleted tab → restore, and the KYC queue page review modal. 17 assertions, self-provisions and hard-deletes a scratch partner.
- `sweep-all.mjs` — opens ALL 23 registered routes in headless Edge, asserts each renders (no "Module unavailable"/"Something went wrong"/"No access"), screenshots every page into `screenshots/`. Run after any frontend refactor.
- `check-imports.mjs` — static cross-check of every `import {...} from "./x.js"` against the actual exports in each file (catches ES-module link failures that the router surfaces as "Module unavailable").

## Module map (master prompt)

- M1 design system + horizontal nav · M2 operational dashboard · M3 customer-KYC removal · M4 customer lifecycle (soft delete/restore) · M5 partner lifecycle (suspend/activate/restore) · M6 bookings (cancel/reschedule/escalate) · M7 payments (transactions/refunds/export) · M8 RBAC · M9 returns (REQUESTED→APPROVED|REJECTED→REFUNDED) · M10 user requests (categories SUPPORT/BOOKING/PAYMENT/PARTNER/ACCOUNT/FEATURE) · M11 audits · M12 settings · M13 admin profile · M14 regression · M15 report.

## Conventions & gotchas

- No React/TS/Tailwind/Bootstrap; no Flyway/Liquibase — Hibernate `ddl-auto=update` is the schema source of truth.
- Public auth endpoints (`/login`, `/refresh-token`, `/forgot-password`, `/reset-password`) return raw payloads; all other endpoints use the `{success, message, data, timestamp}` envelope; `/audit` returns the raw Spring Page.
- List endpoints cap `size` at 100 — frontends must use `fetchAllPages` (in `app.js`) instead of requesting `size=1000` (that 500s with `HandlerMethodValidationException`).
- `exportCsvFile`/`printReport`/`icon`/`fetchAllPages` live in `app.js` (NOT `utils.js`) — `utils.js` only has `escapeHtml`, `fmtDate`, `fmtDateTime`, `money`, `number`, `timeAgo`, `stars`, `qs`, `debounce`, `initials`, `badgeClass`, `parseId`, `compareValues`, `downloadJson`, `exportCsv`, `printView`. A module importing a name from the wrong file fails ES-module linking and the router shows "Module unavailable" (blank page) — check with `node check-imports.mjs` after refactors.
- `utils.qs` is a QUERY-STRING builder (`qs({a:1})` → `?a=1`) — NOT a DOM selector. Only `ledger.js`/`returns.js`/`user-requests.js`/`partners.js` use it correctly. `settlements.js`/`escalations.js` define their own local `const qs = (sel) => document.querySelector(sel)`; keep that pattern for new pages instead of importing `qs` for DOM work.
- Full-route UI sweep: `node sweep-all.mjs` opens all 23 routes in headless Edge, asserts each renders (no "Module unavailable"/"Something went wrong"), and writes screenshots to `screenshots/` — run it after any frontend refactor. `check-imports.mjs` cross-checks every import statement against actual exports.
- Modals: `openModal`/`confirmDialog` in `app.js`; the close machinery (`overlay._close`, `closeTopModal`) is set up by `openModal` itself — callers only bind extra button handlers. `confirmDialog` resolves via its own `done()`.
- Partner KYC documents: uploaded via `POST /partners/{id}/documents` (multipart `identity`/`address`), stored under `server/uploads/partners/` (`app.uploads-dir`), served publicly at `/uploads/**`.
- Passwords: BCrypt(12). Admin refresh tokens stored only as SHA-256 hashes (`user_refresh_tokens`); password-reset tokens are single-use rows in `password_reset_tokens`.
- `AuditService.record` runs `REQUIRES_NEW` — failure audits must survive business-transaction rollbacks.
- MySQL `bit(1)` columns render as raw NUL bytes via CLI — use `IF(col=1,1,0)` in SQL checks.
- Fixtures that log in leave `user_refresh_tokens` rows; deleting such users requires deleting those rows first (FK).
- Identity is unified: admins are `Role.ADMIN` rows on the `users` table; there is a single admin role carrying every permission (see `AdminPermissions`). The old `admins`/`admin_roles`/`admin_permissions` tables are retired.
- The `RateLimitFilter` windows are per-IP (20 auth POSTs/min) and per email+IP (5 forgot-password/hour) — repeated test runs against the same email within an hour get 429; use fresh temp admins per run.
- Backend boot takes ~30 s; the PID reported by `Start-Process` may differ from the real java process — verify via port 8080 listener.
- Demo data is seeded once (when the partners table is empty) by `DemoDataSeeder` — deleting ALL partners and restarting the backend re-seeds it. This includes `seedPayments()` (PAID/PENDING/FAILED per booking) and support requests with categories — but the guard means an existing DB does NOT get payments; on an already-seeded DB, create demo payments via `POST /payments` (bookingId `NULL` rows are orphans and should be deleted).
- Return status is a strict state machine (REQUESTED→APPROVED|REJECTED, APPROVED→REFUNDED|REJECTED); support requests likewise (OPEN→IN_PROGRESS|RESOLVED|CLOSED, IN_PROGRESS→RESOLVED|CLOSED, RESOLVED→CLOSED|OPEN, CLOSED→OPEN) — transitions outside these throw 4xx, so tests must follow legal chains.
