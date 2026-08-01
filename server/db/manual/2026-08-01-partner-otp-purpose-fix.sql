-- Run once on existing MySQL databases where partner_otps.purpose was created
-- as enum('LOGIN','SIGNUP','CUSTOMER_LOGIN'). That old type rejects the newer
-- CUSTOMER_AUTH / CUSTOMER_SIGNUP values with "Data truncated for column
-- 'purpose'" (HTTP 500) on every customer OTP send, which breaks customer login.
-- Fresh databases are handled by Hibernate from the PartnerOtp entity.
-- Safe to run multiple times: guarded by an INFORMATION_SCHEMA check.

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
