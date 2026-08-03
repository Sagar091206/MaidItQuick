-- Run once on existing MySQL databases before deploying the customer profile completion feature.
-- New databases are handled by Hibernate from the UserAccount entity.
-- Safe to run multiple times: every statement is guarded by an INFORMATION_SCHEMA check.

-- Add the four profile columns idempotently (one guarded ALTER per column:
-- MySQL 8 plain scripts cannot use WHILE loops, so no procedural SQL here).
SET @col_exists := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'users'
      AND COLUMN_NAME = 'gender'
);
SET @add_sql := IF(
    @col_exists = 0,
    'ALTER TABLE users ADD COLUMN gender VARCHAR(20) NULL',
    'SELECT 1'
);
PREPARE add_stmt FROM @add_sql;
EXECUTE add_stmt;
DEALLOCATE PREPARE add_stmt;

SET @col_exists := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'users'
      AND COLUMN_NAME = 'dob'
);
SET @add_sql := IF(
    @col_exists = 0,
    'ALTER TABLE users ADD COLUMN dob DATE NULL',
    'SELECT 1'
);
PREPARE add_stmt FROM @add_sql;
EXECUTE add_stmt;
DEALLOCATE PREPARE add_stmt;

SET @col_exists := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'users'
      AND COLUMN_NAME = 'profile_image'
);
SET @add_sql := IF(
    @col_exists = 0,
    'ALTER TABLE users ADD COLUMN profile_image VARCHAR(1000) NULL',
    'SELECT 1'
);
PREPARE add_stmt FROM @add_sql;
EXECUTE add_stmt;
DEALLOCATE PREPARE add_stmt;

SET @col_exists := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'users'
      AND COLUMN_NAME = 'profile_completed'
);
SET @add_sql := IF(
    @col_exists = 0,
    'ALTER TABLE users ADD COLUMN profile_completed BIT(1) NULL',
    'SELECT 1'
);
PREPARE add_stmt FROM @add_sql;
EXECUTE add_stmt;
DEALLOCATE PREPARE add_stmt;

-- Existing customers with a name are already complete; never lose that state.
UPDATE users
SET profile_completed = 1
WHERE role = 'CUSTOMER'
  AND profile_completed IS NULL
  AND name IS NOT NULL
  AND TRIM(name) <> '';

-- Lookup indexes for the booking lists used by the dashboard, history and worker job screens.
SET @idx_customer := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'bookings'
      AND INDEX_NAME = 'idx_bookings_customer'
);
SET @idx_worker := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'bookings'
      AND INDEX_NAME = 'idx_bookings_worker'
);
SET @idx_saved_address := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'saved_addresses'
      AND INDEX_NAME = 'idx_saved_addresses_customer'
);
SET @idx_otp := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'partner_otps'
      AND INDEX_NAME = 'idx_partner_otps_phone_purpose'
);
SET @add_index_sql := IF(
    @idx_customer = 0,
    'ALTER TABLE bookings ADD INDEX idx_bookings_customer (customer_id)',
    'SELECT 1'
);
PREPARE idx_stmt FROM @add_index_sql;
EXECUTE idx_stmt;
DEALLOCATE PREPARE idx_stmt;

SET @add_index_sql := IF(
    @idx_worker = 0,
    'ALTER TABLE bookings ADD INDEX idx_bookings_worker (worker_id)',
    'SELECT 1'
);
PREPARE idx_stmt FROM @add_index_sql;
EXECUTE idx_stmt;
DEALLOCATE PREPARE idx_stmt;

SET @add_index_sql := IF(
    @idx_saved_address = 0,
    'ALTER TABLE saved_addresses ADD INDEX idx_saved_addresses_customer (customer_id)',
    'SELECT 1'
);
PREPARE idx_stmt FROM @add_index_sql;
EXECUTE idx_stmt;
DEALLOCATE PREPARE idx_stmt;

SET @add_index_sql := IF(
    @idx_otp = 0,
    'ALTER TABLE partner_otps ADD INDEX idx_partner_otps_phone_purpose (phone, purpose)',
    'SELECT 1'
);
PREPARE idx_stmt FROM @add_index_sql;
EXECUTE idx_stmt;
DEALLOCATE PREPARE idx_stmt;
