-- Booking payments: payment columns on bookings + payments ledger table.
-- Run once on existing databases; fresh databases get the schema from the
-- Booking and Payment entities via Hibernate.

SET @c := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bookings' AND COLUMN_NAME = 'payment_status');
SET @sql := IF(@c = 0,
    "ALTER TABLE bookings ADD COLUMN payment_status VARCHAR(32) NOT NULL DEFAULT 'UNPAID'",
    'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @c := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bookings' AND COLUMN_NAME = 'payment_method');
SET @sql := IF(@c = 0,
    'ALTER TABLE bookings ADD COLUMN payment_method VARCHAR(32) NULL',
    'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @c := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bookings' AND COLUMN_NAME = 'payment_amount_paise');
SET @sql := IF(@c = 0,
    'ALTER TABLE bookings ADD COLUMN payment_amount_paise INT NULL',
    'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @c := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bookings' AND COLUMN_NAME = 'paid_at');
SET @sql := IF(@c = 0,
    'ALTER TABLE bookings ADD COLUMN paid_at DATETIME(6) NULL',
    'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

CREATE TABLE IF NOT EXISTS payments (
    id              BIGINT NOT NULL AUTO_INCREMENT,
    booking_id      BIGINT NOT NULL,
    reference       VARCHAR(64) NOT NULL,
    method          VARCHAR(32) NOT NULL,
    amount_paise    INT NOT NULL,
    status          VARCHAR(32) NOT NULL,
    gateway_response VARCHAR(500),
    created_at      DATETIME(6) NOT NULL,
    completed_at    DATETIME(6) NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_payments_booking FOREIGN KEY (booking_id) REFERENCES bookings (id)
) ENGINE = InnoDB;

SET @idx := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payments' AND INDEX_NAME = 'idx_payments_booking');
SET @add_idx := IF(@idx = 0,
    'ALTER TABLE payments ADD INDEX idx_payments_booking (booking_id)',
    'SELECT 1');
PREPARE s FROM @add_idx; EXECUTE s; DEALLOCATE PREPARE s;
