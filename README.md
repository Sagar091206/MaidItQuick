# MaidItQuick Admin Management System

Standalone enterprise administration application for the MaidItQuick ecosystem. Vanilla HTML5/CSS3/JavaScript client (no build step, no frameworks), Spring Boot 3.5 REST API (Java 21, Spring Security + JWT, Spring Data JPA/Hibernate), MySQL storage, Swagger/OpenAPI documentation.

## Local development

1. Ensure MySQL is running and create the database: `CREATE DATABASE maiditquick;`
2. Configure the connection in `backend/src/main/resources/application.yml` (defaults: `localhost:3306`, database `maiditquick`, user `root`, password `1234`; all values can be overridden with `DB_URL`, `DB_USERNAME`, `DB_PASSWORD`, `JWT_SECRET`, `CORS_ORIGIN`, `ADMIN_BOOTSTRAP_EMAIL`, `ADMIN_BOOTSTRAP_PASSWORD` env vars).
3. For password reset emails, point the mail settings at an SMTP server (`MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_SMTP_AUTH`, `MAIL_STARTTLS`, `MAIL_SSL`; default `localhost:1025`, e.g. `python -m aiosmtpd -n -c aiosmtpd.handlers.Debugging -l localhost:1025` for local testing) and set `RESET_URL` to the frontend origin. The reset link points to `reset-password.html?token=<token>`, which lets the admin choose a new password (tokens are single-use, expire after 15 minutes and revoke all existing sessions).
4. Run `mvn clean install` and `mvn spring-boot:run` from `backend/`.
5. Serve the frontend with `python -m http.server 5173 --bind 0.0.0.0 --directory frontend`.
6. Open `http://localhost:5173` and sign in with the bootstrap administrator from `app.bootstrap.email` / `app.bootstrap.password` (created automatically on first start; a hint is shown on the login card).

Schema management is done entirely by Hibernate (`spring.jpa.hibernate.ddl-auto=update`) — no Flyway. All tables (`admin_roles`, `admins`, `audit_logs`, `users`, `customers`, `services`, `categories`, `bookings`, `payments`, `reviews`, `notifications`, `settings`, `partners`) are created and updated automatically on startup. On first boot a `DemoDataSeeder` populates demo partners (pending/approved/rejected with KYC document proofs), live bookings with coordinates, a `platform_commission_pct` setting (18%) and flagged customers so the Operations tabs are immediately demonstrable.

## Modules

Login, Forgot/Reset password, Dashboard, Users, Roles, Admins, Customers, Services, Categories, Bookings, Payments, Reviews, Notifications, Settings, Reports and Audit logs — every page calls real REST APIs backed by JPA repositories. Details in [docs/architecture.md](docs/architecture.md).

## Operations modules

* **Partner KYC & onboarding** — segmented pending/approved/rejected workflow with KYC document upload/preview, bank-details review, approve/reject (mandatory reason) flows that audit and notify the partner app.
* **Customer verification & oversight** — KYC overview with booking counts, manual verify / flag (with reason) / clear-flag controls.
* **Live operations** — Leaflet map (available/on-booking/live-request pins), live feed with stage tracker + elapsed timers, and a booking escalation modal for emergency support.
* **Bookings ledger** — commission split (configurable `platform_commission_pct`) and net payout per booking, advanced filters, totals chips and CSV export.

New permissions: `PARTNERS_READ`, `PARTNERS_WRITE`. Partner documents are uploaded to `backend/uploads/partners/` and served at `/uploads/**`. Automated verification: 234/234 across seven suites — 32/32 login, 25/25 forgot-password, 22/22 reset-password, 62/62 frontend regression, 41/41 Operations API, 46/46 headless-browser UI smoke, 6/6 browser journey (see `AGENTS.md`).