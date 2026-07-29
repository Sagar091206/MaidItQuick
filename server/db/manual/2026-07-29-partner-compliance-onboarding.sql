-- Run once on existing MySQL databases before deploying expanded Partner onboarding.
-- New databases are handled by Hibernate from the WorkerProfile entity.

ALTER TABLE worker_profiles
    MODIFY kyc_status ENUM('NOT_SUBMITTED','PENDING','APPROVED','REJECTED','EXPIRED') DEFAULT 'NOT_SUBMITTED',
    MODIFY background_check_status ENUM('NOT_SUBMITTED','PENDING','APPROVED','REJECTED','EXPIRED') DEFAULT 'NOT_SUBMITTED';

ALTER TABLE worker_profiles
    ADD COLUMN pan_status ENUM('NOT_SUBMITTED','PENDING','APPROVED','REJECTED','EXPIRED') DEFAULT 'NOT_SUBMITTED',
    ADD COLUMN selfie_status ENUM('NOT_SUBMITTED','PENDING','APPROVED','REJECTED','EXPIRED') DEFAULT 'NOT_SUBMITTED',
    ADD COLUMN address_status ENUM('NOT_SUBMITTED','PENDING','APPROVED','REJECTED','EXPIRED') DEFAULT 'NOT_SUBMITTED',
    ADD COLUMN consent_accepted BIT(1) NOT NULL DEFAULT b'0',
    ADD COLUMN consent_accepted_at DATETIME(6) NULL,
    ADD COLUMN pan_number VARCHAR(255) NULL,
    ADD COLUMN pan_name VARCHAR(255) NULL,
    ADD COLUMN pan_document_ref VARCHAR(255) NULL,
    ADD COLUMN profile_photo_ref VARCHAR(255) NULL,
    ADD COLUMN current_address VARCHAR(255) NULL,
    ADD COLUMN permanent_address VARCHAR(255) NULL,
    ADD COLUMN city VARCHAR(255) NULL,
    ADD COLUMN state VARCHAR(255) NULL,
    ADD COLUMN pin_code VARCHAR(255) NULL,
    ADD COLUMN address_document_ref VARCHAR(255) NULL,
    ADD COLUMN police_verification_ref VARCHAR(255) NULL,
    ADD COLUMN payout_method VARCHAR(255) NULL,
    ADD COLUMN payout_account_holder_name VARCHAR(255) NULL,
    ADD COLUMN upi_id VARCHAR(255) NULL,
    ADD COLUMN service_categories VARCHAR(255) NULL,
    ADD COLUMN work_locations VARCHAR(255) NULL,
    ADD COLUMN experience_summary VARCHAR(255) NULL,
    ADD COLUMN availability_summary VARCHAR(255) NULL,
    ADD COLUMN partner_code_accepted BIT(1) NOT NULL DEFAULT b'0',
    ADD COLUMN service_readiness_submitted_at DATETIME(6) NULL;
