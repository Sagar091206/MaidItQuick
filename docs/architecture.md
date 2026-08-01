# Architecture and database boundary

The Admin Management System is deployed as an independent Spring Boot 3.5 application (Java 21) with a vanilla HTML/CSS/JS single-page client (no build step, served statically). Authentication is not shared with customer or partner applications: only `admin_*` tables and `audit_logs` are owned by the identity layer.

## Technology

* Java 21, Spring Boot 3.5, Maven
* Spring Security + JWT (jjwt 0.12), stateless sessions, refresh-token rotation in `admin_refresh_tokens`
* Spring Data JPA / Hibernate 6 for all persistence
* MySQL (Connector/J) — schema managed by Hibernate `ddl-auto=update`, no Flyway
* Springdoc OpenAPI at `/swagger-ui.html` and `/v3/api-docs`
* Spring Validation on every request DTO; global `@RestControllerAdvice` error mapping

## Schema management

Hibernate creates and updates every table on startup:

* Identity/RBAC: `admin_roles`, `admin_permissions`, `admin_role_permissions`, `admins`, `admin_refresh_tokens`
* Audit: `audit_logs` (JSON columns for before/after values)
* Business modules owned by this application: `users`, `customers`, `services`, `categories`, `bookings`, `payments`, `reviews`, `notifications`, `settings`, `partners`

Bootstrap seeding (permissions, `SUPER_ADMIN`/`ADMIN`/`VIEWER` roles, initial administrator) runs once on startup via `BootstrapAdmin` and is idempotent. A one-shot `DemoDataSeeder` (`@Order(30)`, runs only when the partners table is empty) seeds 8 demo partners (3 PENDING with SVG identity/address proofs, 3 APPROVED, 2 REJECTED with reasons), 6 live bookings with coordinates, the `platform_commission_pct=18` setting, and 2 flagged customers.

## API layout

| Prefix | Module |
|---|---|
| `/api/v1/admin/login` | US 1.1 canonical login (email + password) |
| `/api/v1/admin/refresh-token` | US 1.1 canonical refresh-token rotation |
| `/api/v1/admin/forgot-password` | US 1.2 public password reset request (email) |
| `/api/v1/admin/reset-password` | US 1.3 public token redemption (new password) |
| `/api/v1/admin/auth` | legacy login / refresh / logout / current profile (`/me`) |
| `/api/v1/admin/dashboard` | summary metrics, recent bookings |
| `/api/v1/admin/users` | user accounts CRUD + status |
| `/api/v1/admin/roles` | role CRUD + permission assignment |
| `/api/v1/admin/admins` | administrator CRUD + status |
| `/api/v1/admin/customers` | customer CRUD + status |
| `/api/v1/admin/services` | service CRUD |
| `/api/v1/admin/categories` | category CRUD |
| `/api/v1/admin/bookings` | booking CRUD + status |
| `/api/v1/admin/payments` | payment CRUD + status |
| `/api/v1/admin/reviews` | review CRUD + moderation |
| `/api/v1/admin/notifications` | notifications + read state |
| `/api/v1/admin/settings` | key/value settings CRUD |
| `/api/v1/admin/reports` | aggregations (status counts, revenue, top services) |
| `/api/v1/admin/audit` | audit trail |
| `/api/v1/admin/partners` | partner CRUD + KYC workflow (`POST /{id}/approve`, `POST /{id}/reject` with required reason, `POST /{id}/documents` multipart upload, `GET /pending-count`) |
| `/api/v1/admin/customers/overview` | customers with booking counts + kyc/flagged filters; `PATCH /{id}/verification` with `VERIFY`/`FLAG`/`CLEAR_FLAG` actions |
| `/api/v1/admin/bookings/live` | active bookings (PENDING/CONFIRMED/IN_PROGRESS) with partner + coordinates; `POST /{id}/escalate` for emergency support |
| `/api/v1/admin/bookings/ledger` | financial ledger with status/date-range/customer/partner filters; commission split from `platform_commission_pct` (default 18%) → `commission` + `netPayout` per booking |
| `/uploads/**` | partner KYC documents (identity/address proofs), served statically from `app.uploads-dir` (default `backend/uploads`) |

Every endpoint returns the envelope `{success, message, data, timestamp}` and is permission-gated (`@PreAuthorize` authorities seeded into `admin_roles`). Exceptions: `POST /login`, `POST /auth/login` and both refresh endpoints return the raw token payload `{accessToken, refreshToken, expiresIn, name, permissions, admin:{id,name,email,role}}` (not envelope-wrapped), `DELETE` returns HTTP 204, and `/audit` returns the raw Spring `Page` shape (`content`, `totalElements`, `number`, `size`, `totalPages`).

## Login security (US 1.1)

* Login flow: find admin → enabled? → locked? → BCrypt verify → JWT (HS256, 15 min) + refresh token (random UUID pair, SHA-256 hashed at rest, stored in `admin_refresh_tokens`, rotated on use, revocable via logout). `last_login` is recorded on every successful login.
* Error contract: 401 `Invalid email or password` for unknown email or wrong password (account enumeration is prevented), 403 for disabled accounts, 429 + `Retry-After` after 5 failed attempts within 15 minutes, 422 for DTO validation (email format, password 8–128 chars).
* Refresh cookie `admin_refresh` is HttpOnly, SameSite=Strict, scoped to `/api/v1/admin`; "remember me" persists it 7 days, otherwise it is a session-only cookie. Access tokens live only in client memory.
* Layered brute-force protection: per-account lockout in `AuthService` (5 failures / 15 min → 429) plus a per-IP window in `RateLimitFilter` (20 auth POSTs/min).

## Password reset (US 1.2)

* `POST /api/v1/admin/forgot-password` is public and takes only `{email}` (validated: not blank, well-formed, ≤ 254 chars). It always returns 200 with the generic message `If an account exists, a password reset link has been sent.` — unknown emails and disabled accounts get the same response, so the endpoint cannot be used to enumerate accounts.
* Flow: email normalized (trim + lowercase) → if an enabled admin exists, generate a 64-character Base64url token (SecureRandom, 48 bytes / 384 bits), store only its SHA-256 hash in `password_reset_tokens` with a 15-minute expiry, mark every previous token for that admin as used, then send the reset link by email (`spring-boot-starter-mail` + JavaMailSender, `spring.mail.*` configuration with `MAIL_HOST`/`MAIL_PORT`/`MAIL_SMTP_AUTH`/`MAIL_STARTTLS`/`MAIL_SSL`/`RESET_URL` env overrides; default sink localhost:1025).
* Email body: `Reset Your MaidItQuick Admin Password`, links to `<RESET_URL>/reset-password.html?token=<64-char token>`, notes the 15-minute expiry. Mail-send failure returns 500 and records an audit entry; the raw token is never persisted or logged.
* Rate limiting: per email+IP window of 5 requests per hour → 429 `Too many password reset requests...` (the filter reads the body via `CachedBodyHttpServletRequest`, so a different email from the same IP is not blocked).
* Every request is audited (`FORGOT_PASSWORD_REQUESTED` with `EMAIL_SENT` / `NO_EMAIL_SENT` outcome).

## Password reset (US 1.3)

* `POST /api/v1/admin/reset-password` is public and takes `{token, newPassword}` (token must be exactly 64 chars; password 8–128). The token is looked up by SHA-256 hash and must be unused and unexpired — otherwise a generic 400 `This password reset link is invalid or has expired.` (unknown, used, expired tokens and disabled accounts are indistinguishable).
* On success: the password is re-hashed with BCrypt, the token is marked used (single use), every live refresh session of the admin is revoked (`admin_refresh_tokens` bulk update) so all devices must sign in again, and the account lock (`failed_attempts` / `locked_until`) is cleared.
* Audit: `PASSWORD_RESET_COMPLETED` (with email) on success; `PASSWORD_RESET_FAILED` (reason) on failures. Audit entries are written with `REQUIRES_NEW` so failed attempts survive the rollback of the failing transaction.
* Rate limiting: covered by the same per-IP window as the other public POSTs (20/min).

## Security baseline

Admin cookies are `HttpOnly`, `Secure` in production, `SameSite=Strict`; access JWTs are returned in the response body and held only in client memory. Passwords use BCrypt(12). Refresh tokens are random, hashed at rest, rotated on use, and revocable. RBAC permissions use Spring Security authorities; login and refresh are rate limited. Every state-changing admin request is written to `audit_logs`. CSRF is disabled because the API is stateless and bearer-token based. Partner documents under `/uploads/**` are publicly readable (they are only referenced by pre-signed-style DB paths); uploaded files are sanitized (original names stripped, random UUID filenames, extension allow-list).

## Operations modules (KYC, verification, live ops, ledger)

* **Partner KYC** (`partners` package): `POST /partners` enforces phone uniqueness and bank/UPI/address validation; `POST /{id}/approve` records `approvedAt`, clears any rejection reason, sends a SUCCESS notification to the partner app and audits `PARTNER_APPROVED`; `POST /{id}/reject` requires a non-blank reason (≤ 1000 chars, 422 otherwise), sends an ERROR notification and audits `PARTNER_REJECTED`; documents are uploaded via multipart and stored under `uploads/partners/<id>-<uuid>.<ext>` with the path persisted on the partner row. Re-uploading a document replaces the previous file and deleting a partner removes its files (`deleteFile` on both paths).
* **Customer verification**: `GET /customers/overview` (JPA Specification filters for query/kyc/flagged, `size` capped at 100 per page) returns `CustomerOverview` DTOs including `bookingCount`; `PATCH /customers/{id}/verification` accepts `{action, reason}` where `FLAG` requires a reason, and creates notifications + audit entries for each action.
* **Live operations**: `GET /bookings/live` returns non-terminal bookings with partner + lat/lng, `startedAt`/`completedAt` set by `PATCH /bookings/{id}/status` state machine; `POST /bookings/{id}/escalate` creates an ERROR notification + `BOOKING_ESCALATED` audit.
* **Ledger**: `GET /bookings/ledger` supports `from`, `to` (dates), `status`, `customerQ`, `partnerQ` (Specification), and computes `commissionPct` (from `platform_commission_pct` setting, default 18%), `commission` and `netPayout` per booking in a stream-safe way; totals are client-side aggregates.
* Frontend: every route is lazy-loaded (`import(\`./<hash>.js\`)` + `registerModule`); `api.upload()` posts multipart with the shared refresh-once interceptor; `API_ORIGIN` exposes the API base for `/uploads/**` URLs; the ledger and customer pages use `fetchAllPages` (server `size` cap is 100).
