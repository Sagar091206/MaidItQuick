-- Legacy schema alignment: drop leftover columns from an older bookings /
-- payments schema that the current Booking and Payment entities no longer map.
-- The columns are dead (no code writes or reads them) but are NOT NULL without
-- a default, so every INSERT of a new booking or payment failed with a 500
-- ("Something went wrong. Try again later.").

-- bookings.amount_paise / add_on_label belonged to an old add-on schema.
-- amount_paise is NOT NULL -> block inserts. add_on_label is nullable and
-- harmless, but both are dead; only the blocking column is removed.

SET @c := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bookings' AND COLUMN_NAME = 'amount_paise');
SET @sql := IF(@c > 0, 'ALTER TABLE bookings DROP COLUMN amount_paise', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- payments table: the current Payment entity maps id, booking_id, reference,
-- method, amount_paise, status, gateway_response, created_at, completed_at.
-- The old schema left extra NOT NULL columns (with an FK to users for
-- customer_id) that block payment inserts.

SET @fk := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payments' AND CONSTRAINT_NAME = 'FKd1qot1f3alweegm6ledjow6nj');
SET @sql := IF(@fk > 0,
    'ALTER TABLE payments DROP FOREIGN KEY FKd1qot1f3alweegm6ledjow6nj', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @c := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payments' AND COLUMN_NAME = 'customer_id');
SET @sql := IF(@c > 0, 'ALTER TABLE payments DROP COLUMN customer_id', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @c := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payments' AND COLUMN_NAME = 'invoice_number');
SET @sql := IF(@c > 0, 'ALTER TABLE payments DROP COLUMN invoice_number', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @c := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payments' AND COLUMN_NAME = 'subtotal_paise');
SET @sql := IF(@c > 0, 'ALTER TABLE payments DROP COLUMN subtotal_paise', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @c := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payments' AND COLUMN_NAME = 'total_paise');
SET @sql := IF(@c > 0, 'ALTER TABLE payments DROP COLUMN total_paise', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @c := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payments' AND COLUMN_NAME = 'gst_paise');
SET @sql := IF(@c > 0, 'ALTER TABLE payments DROP COLUMN gst_paise', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @c := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payments' AND COLUMN_NAME = 'discount_paise');
SET @sql := IF(@c > 0, 'ALTER TABLE payments DROP COLUMN discount_paise', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @c := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payments' AND COLUMN_NAME = 'convenience_paise');
SET @sql := IF(@c > 0, 'ALTER TABLE payments DROP COLUMN convenience_paise', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @c := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payments' AND COLUMN_NAME = 'wallet_paise');
SET @sql := IF(@c > 0, 'ALTER TABLE payments DROP COLUMN wallet_paise', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- Legacy data alignment: rows written by an older flow carry enum values that
-- no longer exist (BookingStatus.PENDING_PAYMENT, NotificationType.PAYMENT).
-- Reading them throws "No enum constant" -> 500 on the booking list and the
-- notifications feed. Map them onto the current enum values.

UPDATE booking_events SET status = 'REQUESTED' WHERE status = 'PENDING_PAYMENT';

UPDATE app_notifications SET type = 'BOOKING' WHERE type = 'PAYMENT';
