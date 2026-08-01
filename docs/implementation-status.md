# Implementation status

All modules are implemented against real REST APIs backed by JPA repositories and MySQL, with a vanilla HTML/CSS/JS frontend (no frameworks, no build step):

* Login (US 1.1: JWT + rotating refresh cookie, silent session restore, remember-me, account lockout, error contract 401/403/429/422)
* Forgot password (US 1.2: public generic 200, 64-char SecureRandom token stored SHA-256 hashed with 15-min expiry, previous tokens invalidated, SMTP email via JavaMailSender, 5/hour per email+IP rate limit, no account enumeration, audited)
* Reset password (US 1.3: token redemption page, single-use token, BCrypt re-hash, all refresh sessions revoked on change, lock cleared, generic 400 for invalid/expired/used tokens, audit trail)
* Dashboard (live summary metrics, revenue/status charts, recent bookings, activity timeline)
* Users (search, create, edit, delete, status)
* Roles (CRUD + permission assignment via permission matrix)
* Admins (CRUD + status, self-protection and last-SUPER_ADMIN guards)
* Customers (CRUD + status)
* Services (CRUD with category linking)
* Categories (CRUD)
* Bookings (CRUD + status workflow)
* Payments (CRUD + status, revenue tracking)
* Reviews (CRUD + moderation)
* Notifications (send, read state, delete, unread badge polling)
* Settings (key/value CRUD)
* Reports (bookings by status, revenue by month, top services, totals, CSV export)
* Audit logs (read-only, server-side paginated trail of admin actions)
* Partner KYC & onboarding (`#/partners`): segmented PENDING/APPROVED/REJECTED tabs with live counts + sidebar badge, KYC detail modal with identity/address document preview + inline upload, bank-details review grid, approve (audit + partner-app notification + approval timestamp) and reject (mandatory reason, inline validation, partner feedback), partner CRUD with phone-uniqueness checks
* Customer verification (`#/customer-verification`): overview table with booking counts, kyc/flagged filters, manual verify (audited override) / flag with required reason / clear flag
* Live operations (`#/live-ops`): Leaflet map with green (available partner) / blue (on booking) / red (live request) pins + fitBounds, live feed with 4-stage tracker and ticking elapsed timers, 20s polling, booking escalation modal with emergency-support flow (audited, partner notified)
* Bookings ledger (`#/ledger`): commission split (configurable `platform_commission_pct` setting, default 18%) and net payout per row, totals chips, status/date-range/customer/partner filters, reset, CSV export of the filtered dataset

Schema management is delegated to Hibernate (`ddl-auto=update`); Flyway has been fully removed. All endpoints were verified against MySQL 9 with automated CRUD checks (62/62 passing E2E script covering CORS preflight, cookie rotation, every module CRUD sweep, and 401/logout semantics). US 1.1 was verified end-to-end (32/32 `verify-us11.mjs`); US 1.2 was verified end-to-end (25/25 `verify-us12.mjs` covering generic 200, real SMTP delivery to a local sink, hashed 15-min token storage, token invalidation, no-enumeration, 422 validation, 5/hour rate limiting, and audit entries). US 1.3 was verified end-to-end (22/22 `verify-us13.mjs` covering token redemption, single-use replay rejection, old/new password behaviour, pre-reset session revocation, expired/unknown/malformed tokens, validation, DB state and audit entries). The Operations feature set (KYC workflow, customer verification, live ops, ledger) was verified against the live backend (41/41 `verify-ops.mjs` covering approve/reject/re-reject, reason-required 422, document upload + static serving, overview filters, manual verify/flag/clear, live bookings with coordinates and timestamps, 18% commission math, filters, audit events and cleanup) and in a real headless-Edge browser via CDP (46/46 `verify-ops-ui.mjs` covering login, all four tabs, modal flows, toasts, map pins, timers, escalation, ledger filters + CSV export, plus form-created/edited/deleted partners, upload, re-approval of rejected partners, and customer kyc/flagged filters). The browser and API suites self-provision fixtures (fresh customer when the pending pool is exhausted) and self-clean on success or crash, so repeated runs leave zero residue; the full matrix is 234/234 across the seven suites (`verify-us11`, `verify-us12`, `verify-us13`, `verify-ops`, `verify-frontend`, `verify-ops-ui`, `verify-journey`).

Demo data (one-shot seed on first boot when the partners table is empty): 8 partners (3 PENDING with SVG identity/address proofs, 3 APPROVED, 2 REJECTED with reasons), 6 live bookings with lat/lng, `platform_commission_pct=18`, and 2 flagged customers — see `config/DemoDataSeeder.java`.

New permissions: `PARTNERS_READ`, `PARTNERS_WRITE` (registered in `BootstrapAdmin`, granted to SUPER_ADMIN and VIEWER roles). Partner documents are uploaded under `backend/uploads/partners/` and served at `/uploads/**` (public read; writable dir configured via `app.uploads-dir`).
