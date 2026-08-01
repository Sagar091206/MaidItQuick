-- Run once on existing MySQL databases before deploying the booking timeline and
-- extended booking statuses (ACCEPTED, ARRIVED) change.
-- New databases are handled by Hibernate from the BookingEvent entity.
-- The bookings.status column is a VARCHAR already; no ALTER is required for the
-- two new enum values.

CREATE TABLE IF NOT EXISTS booking_events (
    id         BIGINT NOT NULL AUTO_INCREMENT,
    booking_id BIGINT NOT NULL,
    status     VARCHAR(255) NOT NULL,
    note       VARCHAR(500),
    created_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_booking_events_booking
        FOREIGN KEY (booking_id) REFERENCES bookings (id)
) ENGINE = InnoDB;

SET @idx_timeline := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'booking_events'
      AND INDEX_NAME = 'idx_booking_events_booking'
);
SET @add_index_sql := IF(
    @idx_timeline = 0,
    'ALTER TABLE booking_events ADD INDEX idx_booking_events_booking (booking_id)',
    'SELECT 1'
);
PREPARE idx_stmt FROM @add_index_sql;
EXECUTE idx_stmt;
DEALLOCATE PREPARE idx_stmt;
