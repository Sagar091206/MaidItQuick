-- Phase 4: unified identity & security
-- Retires the admin module's parallel identity model (admins / admin_roles /
-- admin_permissions / admin_password_reset_tokens / admin_refresh_tokens) and
-- makes users-table Role.ADMIN accounts the single identity for the admin UI.
--
-- Run AFTER booting the Phase 4 jar once so Hibernate (ddl-auto=update) has
-- added failed_attempts / locked_until / last_login to `users` and created
-- `user_refresh_tokens`. The script then:
--   1. copies existing administrators into `users` as Role.ADMIN (idempotent),
--   2. drops the retired admin tables.
--
-- MySQL. Uses prepared statements because MySQL lacks ADD/DROP ... IF EXISTS.

-- ---------------------------------------------------------------
-- 1. Ensure the users-table auth columns exist (safe if already present).
-- ---------------------------------------------------------------
SET @sql := (SELECT IF(COUNT(*) = 0,
  'ALTER TABLE users ADD COLUMN failed_attempts INT NOT NULL DEFAULT 0',
  'SELECT 1')
  FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'failed_attempts');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := (SELECT IF(COUNT(*) = 0,
  'ALTER TABLE users ADD COLUMN locked_until DATETIME(6) NULL',
  'SELECT 1')
  FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'locked_until');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := (SELECT IF(COUNT(*) = 0,
  'ALTER TABLE users ADD COLUMN last_login DATETIME(6) NULL',
  'SELECT 1')
  FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'last_login');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ---------------------------------------------------------------
-- 2. Copy existing administrators into users as Role.ADMIN.
--    Placeholder phone 'ADMIN-<id>' keeps the (phone, role) unique key happy.
-- ---------------------------------------------------------------
INSERT INTO users
  (name, email, password_hash, phone, role, enabled, email_notifications,
   created_at, failed_attempts, locked_until, last_login)
SELECT
  COALESCE(NULLIF(a.display_name, ''), CONCAT('Admin-', a.id)),
  a.email,
  a.password_hash,
  CONCAT('ADMIN-', a.id),
  'ADMIN',
  a.enabled,
  1,
  COALESCE(a.last_login, NOW()),
  a.failed_attempts,
  a.locked_until,
  a.last_login
FROM admins a
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.email = a.email);

-- ---------------------------------------------------------------
-- 3. Drop the retired admin tables (referencing tables first).
-- ---------------------------------------------------------------
DROP TABLE IF EXISTS admin_refresh_tokens;
DROP TABLE IF EXISTS admin_password_reset_tokens;
DROP TABLE IF EXISTS admins;
DROP TABLE IF EXISTS admin_role_permissions;
DROP TABLE IF EXISTS admin_roles;
DROP TABLE IF EXISTS admin_permissions;
