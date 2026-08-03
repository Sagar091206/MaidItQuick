-- Adds Instant Maid lifecycle statuses to installations where bookings.status is an existing MySQL ENUM.
ALTER TABLE bookings MODIFY COLUMN status ENUM('SEARCHING','REQUESTED','ASSIGNED','ACCEPTED','ON_THE_WAY','ARRIVED','IN_PROGRESS','COMPLETED','CANCELLED','EXPIRED','NO_PARTNER_FOUND') NOT NULL;
