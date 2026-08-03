# MaidItQuick Admin Management System

Enterprise administration application for the MaidItQuick ecosystem, served as part of the merged monolith. Vanilla HTML5/CSS3/JavaScript client (no build step, no frameworks) embedded in the jar, Spring Boot 3.5 REST API (Java 21, Spring Security + JWT, Spring Data JPA/Hibernate), MySQL storage, Swagger/OpenAPI documentation. One process serves both the mobile API and the admin UI/API on `:8080`.

## Local development

1. Ensure MySQL is running and create the database: `CREATE DATABASE makeitquick;`
2. Configure the connection in `server/src/main/resources/application.yml` (defaults: `localhost:3306`, database `makeitquick`, user `root`; all values can be overridden with `MYSQL_URL`, `MYSQL_USER`, `MYSQL_PASSWORD`, `JWT_SECRET`, `CORS_ORIGIN`, `ADMIN_BOOTSTRAP_EMAIL`, `ADMIN_BOOTSTRAP_PASSWORD` env vars).
3. For password reset emails, point the mail settings at an SMTP server (`MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD`; default `localhost:1025`, e.g. `python -m aiosmtpd -n -c aiosmtpd.handlers.Debugging -l localhost:1025` for local testing) and set `RESET_URL` to the frontend origin. The reset link points to `reset-password.html?token=<token>` (tokens are single-use, expire after 15 minutes and revoke all existing sessions).
4. Build the jar: `mvn clean package` from `server/` (runs the full test suite). To refresh the embedded admin SPA first run `server/scripts/sync-admin-frontend.sh` after editing `frontend/`.
5. Run `java -jar server/target/makeitquick-server-0.1.0.jar`.
6. Open `http://localhost:8080/login.html` and sign in with the bootstrap administrator from `app.bootstrap.email` / `app.bootstrap.password` (created automatically on first start; a hint is shown on the login card).

Schema management is done entirely by Hibernate (`spring.jpa.hibernate.ddl-auto=update`) — no Flyway. Identity is unified: administrators are `Role.ADMIN` rows on the `users` table. On first boot a `DemoDataSeeder` populates demo partners (pending/approved/rejected with KYC document proofs), live bookings with coordinates, a `platform_commission_pct` setting (18%) and flagged customers so the Operations tabs are immediately demonstrable.

## Modules

Login, Forgot/Reset password, Dashboard, Users, Roles, Admins, Customers, Services, Categories, Bookings, Payments, Reviews, Notifications, Settings, Reports and Audit logs — every page calls real REST APIs backed by JPA repositories. Details in [docs/architecture.md](docs/architecture.md).

## Operations modules

* **Partner KYC & onboarding** — segmented pending/approved/rejected workflow with KYC document upload/preview, bank-details review, approve/reject (mandatory reason) flows that audit and notify the partner app.
* **Customer verification & oversight** — KYC overview with booking counts, manual verify / flag (with reason) / clear-flag controls.
* **Live operations** — Leaflet map (available/on-booking/live-request pins), live feed with stage tracker + elapsed timers, and a booking escalation modal for emergency support.
* **Bookings ledger** — commission split (configurable `platform_commission_pct`) and net payout per booking, advanced filters, totals chips and CSV export.

New permissions: `PARTNERS_READ`, `PARTNERS_WRITE`. Partner documents are uploaded to `server/uploads/partners/` (`app.uploads-dir`) and served at `/uploads/**`. Automated verification: the merged server suite (54 integration tests) covers the admin contract, auth flows, bookings, payments and service discovery (see `AGENTS.md`).