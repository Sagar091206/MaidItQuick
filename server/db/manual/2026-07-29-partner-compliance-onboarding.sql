-- Run on existing MySQL databases before deploying expanded Partner onboarding.
-- New databases are handled by Hibernate from the WorkerProfile entity.
-- Idempotent: every ADD COLUMN is guarded by an INFORMATION_SCHEMA check.

ALTER TABLE worker_profiles
    MODIFY kyc_status ENUM('NOT_SUBMITTED','PENDING','APPROVED','REJECTED','EXPIRED') DEFAULT 'NOT_SUBMITTED',
    MODIFY background_check_status ENUM('NOT_SUBMITTED','PENDING','APPROVED','REJECTED','EXPIRED') DEFAULT 'NOT_SUBMITTED';

-- Guarded single-column ALTERs (MySQL 8 has no ADD COLUMN IF NOT EXISTS).
SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'worker_profiles' AND COLUMN_NAME = 'pan_status');
SET @add_sql := IF(@col_exists = 0, "ALTER TABLE worker_profiles ADD COLUMN pan_status ENUM('NOT_SUBMITTED','PENDING','APPROVED','REJECTED','EXPIRED') DEFAULT 'NOT_SUBMITTED'", 'SELECT 1');
PREPARE add_stmt FROM @add_sql; EXECUTE add_stmt; DEALLOCATE PREPARE add_stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'worker_profiles' AND COLUMN_NAME = 'selfie_status');
SET @add_sql := IF(@col_exists = 0, "ALTER TABLE worker_profiles ADD COLUMN selfie_status ENUM('NOT_SUBMITTED','PENDING','APPROVED','REJECTED','EXPIRED') DEFAULT 'NOT_SUBMITTED'", 'SELECT 1');
PREPARE add_stmt FROM @add_sql; EXECUTE add_stmt; DEALLOCATE PREPARE add_stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'worker_profiles' AND COLUMN_NAME = 'address_status');
SET @add_sql := IF(@col_exists = 0, "ALTER TABLE worker_profiles ADD COLUMN address_status ENUM('NOT_SUBMITTED','PENDING','APPROVED','REJECTED','EXPIRED') DEFAULT 'NOT_SUBMITTED'", 'SELECT 1');
PREPARE add_stmt FROM @add_sql; EXECUTE add_stmt; DEALLOCATE PREPARE add_stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'worker_profiles' AND COLUMN_NAME = 'consent_accepted');
SET @add_sql := IF(@col_exists = 0, 'ALTER TABLE worker_profiles ADD COLUMN consent_accepted BIT(1) NOT NULL DEFAULT b''0''', 'SELECT 1');
PREPARE add_stmt FROM @add_sql; EXECUTE add_stmt; DEALLOCATE PREPARE add_stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'worker_profiles' AND COLUMN_NAME = 'consent_accepted_at');
SET @add_sql := IF(@col_exists = 0, 'ALTER TABLE worker_profiles ADD COLUMN consent_accepted_at DATETIME(6) NULL', 'SELECT 1');
PREPARE add_stmt FROM @add_sql; EXECUTE add_stmt; DEALLOCATE PREPARE add_stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'worker_profiles' AND COLUMN_NAME = 'pan_number');
SET @add_sql := IF(@col_exists = 0, 'ALTER TABLE worker_profiles ADD COLUMN pan_number VARCHAR(255) NULL', 'SELECT 1');
PREPARE add_stmt FROM @add_sql; EXECUTE add_stmt; DEALLOCATE PREPARE add_stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'worker_profiles' AND COLUMN_NAME = 'pan_name');
SET @add_sql := IF(@col_exists = 0, 'ALTER TABLE worker_profiles ADD COLUMN pan_name VARCHAR(255) NULL', 'SELECT 1');
PREPARE add_stmt FROM @add_sql; EXECUTE add_stmt; DEALLOCATE PREPARE add_stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'worker_profiles' AND COLUMN_NAME = 'pan_document_ref');
SET @add_sql := IF(@col_exists = 0, 'ALTER TABLE worker_profiles ADD COLUMN pan_document_ref VARCHAR(255) NULL', 'SELECT 1');
PREPARE add_stmt FROM @add_sql; EXECUTE add_stmt; DEALLOCATE PREPARE add_stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'worker_profiles' AND COLUMN_NAME = 'profile_photo_ref');
SET @add_sql := IF(@col_exists = 0, 'ALTER TABLE worker_profiles ADD COLUMN profile_photo_ref VARCHAR(255) NULL', 'SELECT 1');
PREPARE add_stmt FROM @add_sql; EXECUTE add_stmt; DEALLOCATE PREPARE add_stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'worker_profiles' AND COLUMN_NAME = 'current_address');
SET @add_sql := IF(@col_exists = 0, 'ALTER TABLE worker_profiles ADD COLUMN current_address VARCHAR(255) NULL', 'SELECT 1');
PREPARE add_stmt FROM @add_sql; EXECUTE add_stmt; DEALLOCATE PREPARE add_stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'worker_profiles' AND COLUMN_NAME = 'permanent_address');
SET @add_sql := IF(@col_exists = 0, 'ALTER TABLE worker_profiles ADD COLUMN permanent_address VARCHAR(255) NULL', 'SELECT 1');
PREPARE add_stmt FROM @add_sql; EXECUTE add_stmt; DEALLOCATE PREPARE add_stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'worker_profiles' AND COLUMN_NAME = 'city');
SET @add_sql := IF(@col_exists = 0, 'ALTER TABLE worker_profiles ADD COLUMN city VARCHAR(255) NULL', 'SELECT 1');
PREPARE add_stmt FROM @add_sql; EXECUTE add_stmt; DEALLOCATE PREPARE add_stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'worker_profiles' AND COLUMN_NAME = 'state');
SET @add_sql := IF(@col_exists = 0, 'ALTER TABLE worker_profiles ADD COLUMN state VARCHAR(255) NULL', 'SELECT 1');
PREPARE add_stmt FROM @add_sql; EXECUTE add_stmt; DEALLOCATE PREPARE add_stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'worker_profiles' AND COLUMN_NAME = 'pin_code');
SET @add_sql := IF(@col_exists = 0, 'ALTER TABLE worker_profiles ADD COLUMN pin_code VARCHAR(255) NULL', 'SELECT 1');
PREPARE add_stmt FROM @add_sql; EXECUTE add_stmt; DEALLOCATE PREPARE add_stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'worker_profiles' AND COLUMN_NAME = 'address_document_ref');
SET @add_sql := IF(@col_exists = 0, 'ALTER TABLE worker_profiles ADD COLUMN address_document_ref VARCHAR(255) NULL', 'SELECT 1');
PREPARE add_stmt FROM @add_sql; EXECUTE add_stmt; DEALLOCATE PREPARE add_stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'worker_profiles' AND COLUMN_NAME = 'police_verification_ref');
SET @add_sql := IF(@col_exists = 0, 'ALTER TABLE worker_profiles ADD COLUMN police_verification_ref VARCHAR(255) NULL', 'SELECT 1');
PREPARE add_stmt FROM @add_sql; EXECUTE add_stmt; DEALLOCATE PREPARE add_stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'worker_profiles' AND COLUMN_NAME = 'payout_method');
SET @add_sql := IF(@col_exists = 0, 'ALTER TABLE worker_profiles ADD COLUMN payout_method VARCHAR(255) NULL', 'SELECT 1');
PREPARE add_stmt FROM @add_sql; EXECUTE add_stmt; DEALLOCATE PREPARE add_stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'worker_profiles' AND COLUMN_NAME = 'payout_account_holder_name');
SET @add_sql := IF(@col_exists = 0, 'ALTER TABLE worker_profiles ADD COLUMN payout_account_holder_name VARCHAR(255) NULL', 'SELECT 1');
PREPARE add_stmt FROM @add_sql; EXECUTE add_stmt; DEALLOCATE PREPARE add_stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'worker_profiles' AND COLUMN_NAME = 'upi_id');
SET @add_sql := IF(@col_exists = 0, 'ALTER TABLE worker_profiles ADD COLUMN upi_id VARCHAR(255) NULL', 'SELECT 1');
PREPARE add_stmt FROM @add_sql; EXECUTE add_stmt; DEALLOCATE PREPARE add_stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'worker_profiles' AND COLUMN_NAME = 'service_categories');
SET @add_sql := IF(@col_exists = 0, 'ALTER TABLE worker_profiles ADD COLUMN service_categories VARCHAR(255) NULL', 'SELECT 1');
PREPARE add_stmt FROM @add_sql; EXECUTE add_stmt; DEALLOCATE PREPARE add_stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'worker_profiles' AND COLUMN_NAME = 'work_locations');
SET @add_sql := IF(@col_exists = 0, 'ALTER TABLE worker_profiles ADD COLUMN work_locations VARCHAR(255) NULL', 'SELECT 1');
PREPARE add_stmt FROM @add_sql; EXECUTE add_stmt; DEALLOCATE PREPARE add_stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'worker_profiles' AND COLUMN_NAME = 'experience_summary');
SET @add_sql := IF(@col_exists = 0, 'ALTER TABLE worker_profiles ADD COLUMN experience_summary VARCHAR(255) NULL', 'SELECT 1');
PREPARE add_stmt FROM @add_sql; EXECUTE add_stmt; DEALLOCATE PREPARE add_stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'worker_profiles' AND COLUMN_NAME = 'availability_summary');
SET @add_sql := IF(@col_exists = 0, 'ALTER TABLE worker_profiles ADD COLUMN availability_summary VARCHAR(255) NULL', 'SELECT 1');
PREPARE add_stmt FROM @add_sql; EXECUTE add_stmt; DEALLOCATE PREPARE add_stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'worker_profiles' AND COLUMN_NAME = 'partner_code_accepted');
SET @add_sql := IF(@col_exists = 0, 'ALTER TABLE worker_profiles ADD COLUMN partner_code_accepted BIT(1) NOT NULL DEFAULT b''0''', 'SELECT 1');
PREPARE add_stmt FROM @add_sql; EXECUTE add_stmt; DEALLOCATE PREPARE add_stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'worker_profiles' AND COLUMN_NAME = 'service_readiness_submitted_at');
SET @add_sql := IF(@col_exists = 0, 'ALTER TABLE worker_profiles ADD COLUMN service_readiness_submitted_at DATETIME(6) NULL', 'SELECT 1');
PREPARE add_stmt FROM @add_sql; EXECUTE add_stmt; DEALLOCATE PREPARE add_stmt;
