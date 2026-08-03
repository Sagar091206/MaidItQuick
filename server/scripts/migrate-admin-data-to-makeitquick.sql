-- One-shot Phase 2 migration: copy admin-only tables (and their data) from the
-- legacy admin database (maiditquick) into the canonical mobile database
-- (makeitquick), which is now the single database of the merged monolith.
--
-- Only tables that actually hold data are copied here. The empty admin tables
-- (categories, customers, services, disputes, notifications, payout_records,
-- return_requests, reviews, audit_logs) and the renamed admin_* tables
-- (admin_users, admin_bookings, admin_payments, admin_password_reset_tokens)
-- are created fresh by Hibernate ddl-auto=update on first boot.
--
-- Run with:  mysql -u root -p < server/scripts/migrate-admin-data-to-makeitquick.sql

USE makeitquick;

-- CREATE TABLE ... LIKE copies the exact schema (columns, indexes, FKs) that
-- Hibernate generated for the same entities in the maiditquick database.
-- Referenced tables must exist first, so order matters (admin_roles before
-- admins, etc.).
CREATE TABLE IF NOT EXISTS admin_roles            LIKE maiditquick.admin_roles;
CREATE TABLE IF NOT EXISTS admin_permissions      LIKE maiditquick.admin_permissions;
CREATE TABLE IF NOT EXISTS admins                 LIKE maiditquick.admins;
CREATE TABLE IF NOT EXISTS admin_role_permissions LIKE maiditquick.admin_role_permissions;
CREATE TABLE IF NOT EXISTS admin_refresh_tokens   LIKE maiditquick.admin_refresh_tokens;
CREATE TABLE IF NOT EXISTS partners               LIKE maiditquick.partners;
CREATE TABLE IF NOT EXISTS settings               LIKE maiditquick.settings;
CREATE TABLE IF NOT EXISTS support_requests       LIKE maiditquick.support_requests;

-- Copy the rows, preserving ids so the FK relationships stay intact.
INSERT IGNORE INTO admin_roles            SELECT * FROM maiditquick.admin_roles;
INSERT IGNORE INTO admin_permissions      SELECT * FROM maiditquick.admin_permissions;
INSERT IGNORE INTO admins                 SELECT * FROM maiditquick.admins;
INSERT IGNORE INTO admin_role_permissions SELECT * FROM maiditquick.admin_role_permissions;
INSERT IGNORE INTO admin_refresh_tokens   SELECT * FROM maiditquick.admin_refresh_tokens;
INSERT IGNORE INTO partners               SELECT * FROM maiditquick.partners;
INSERT IGNORE INTO settings               SELECT * FROM maiditquick.settings;
INSERT IGNORE INTO support_requests       SELECT * FROM maiditquick.support_requests;
