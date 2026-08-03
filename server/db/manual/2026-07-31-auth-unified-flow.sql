-- Run once on existing MySQL databases before deploying the unified customer
-- authentication flow (60-second OTPs, resend cap, pending registration tokens).
-- New databases are handled by Hibernate from the entities.
-- Safe to run multiple times: every statement is guarded by an INFORMATION_SCHEMA check.

-- 1. Prevent duplicate mobile numbers at the database level.
SET @phone_unique := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'users'
      AND COLUMN_NAME = 'phone'
      AND NON_UNIQUE = 0
      AND INDEX_NAME <> 'PRIMARY'
);
SET @add_phone_unique_sql := IF(
    @phone_unique = 0,
    'ALTER TABLE users ADD UNIQUE INDEX uq_users_phone (phone)',
    'SELECT 1'
);
PREPARE phone_unique_stmt FROM @add_phone_unique_sql;
EXECUTE phone_unique_stmt;
DEALLOCATE PREPARE phone_unique_stmt;

-- 0. Expand the purpose column from the old enum to a VARCHAR so the new
--    CUSTOMER_AUTH purpose fits. Older databases created the column as
--    enum('LOGIN','SIGNUP','CUSTOMER_LOGIN') which rejects CUSTOMER_AUTH and
--    CUSTOMER_SIGNUP with a Data truncation error on every OTP insert.
SET @purpose_is_enum := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'partner_otps'
      AND COLUMN_NAME = 'purpose'
      AND DATA_TYPE = 'enum'
);
SET @fix_purpose_sql := IF(
    @purpose_is_enum > 0,
    'ALTER TABLE partner_otps MODIFY purpose VARCHAR(32) NOT NULL',
    'SELECT 1'
);
PREPARE fix_purpose_stmt FROM @fix_purpose_sql;
EXECUTE fix_purpose_stmt;
DEALLOCATE PREPARE fix_purpose_stmt;

-- 2. Index OTP lookups by phone + creation time (resend counting and rate limits).
SET @otp_idx := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'partner_otps'
      AND INDEX_NAME = 'idx_partner_otps_phone_purpose_created'
);
SET @add_otp_idx_sql := IF(
    @otp_idx = 0,
    'ALTER TABLE partner_otps ADD INDEX idx_partner_otps_phone_purpose_created (phone, purpose, created_at)',
    'SELECT 1'
);
PREPARE otp_idx_stmt FROM @add_otp_idx_sql;
EXECUTE otp_idx_stmt;
DEALLOCATE PREPARE otp_idx_stmt;

-- 3. Pending registration tokens issued after OTP verification for new customers.
CREATE TABLE IF NOT EXISTS pending_registrations (
    id         BIGINT NOT NULL AUTO_INCREMENT,
    phone      VARCHAR(255) NOT NULL,
    token      VARCHAR(128) NOT NULL,
    expires_at DATETIME(6) NOT NULL,
    used       BIT(1) NOT NULL,
    created_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_pending_registrations_token (token),
    KEY idx_pending_registrations_phone (phone)
) ENGINE = InnoDB;
