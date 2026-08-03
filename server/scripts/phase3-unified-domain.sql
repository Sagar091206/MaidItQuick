-- Phase 3: unified domain model
-- Retires the admin CRM overlay tables (admin_users, admin_bookings, admin_payments,
-- customers) in favour of the canonical mobile tables (users, bookings, payments).
-- Re-points the reviews / disputes / payout_records foreign keys to those tables.
-- Run against the 'makeitquick' database:  mysql -u root -proot makeitquick < phase3-unified-domain.sql
-- All affected tables are empty, so this is a safe one-shot migration. After running,
-- restart the backend so Hibernate (ddl-auto=update) recreates the re-pointed FKs.

USE makeitquick;

-- Drop every FK constraint that references the tables being retired.
DROP PROCEDURE IF EXISTS drop_retired_fks;
DELIMITER $$
CREATE PROCEDURE drop_retired_fks()
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE sql_stmt TEXT;
  DECLARE cur CURSOR FOR
    SELECT CONCAT('ALTER TABLE `', TABLE_NAME, '` DROP FOREIGN KEY `', CONSTRAINT_NAME, '`')
    FROM information_schema.KEY_COLUMN_USAGE
    WHERE TABLE_SCHEMA = DATABASE()
      AND REFERENCED_TABLE_SCHEMA = DATABASE()
      AND REFERENCED_TABLE_NAME IN ('admin_users', 'admin_bookings', 'admin_payments', 'customers');
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
  OPEN cur;
  read_loop: LOOP
    FETCH cur INTO sql_stmt;
    IF done THEN LEAVE read_loop; END IF;
    SET @s = sql_stmt;
    PREPARE stmt FROM @s;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END LOOP;
  CLOSE cur;
END$$
DELIMITER ;
CALL drop_retired_fks();
DROP PROCEDURE drop_retired_fks;

-- Drop the payout_records -> partners FK and the partner column.
DROP PROCEDURE IF EXISTS drop_payout_partner_fk;
DELIMITER $$
CREATE PROCEDURE drop_payout_partner_fk()
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE sql_stmt TEXT;
  DECLARE cur CURSOR FOR
    SELECT CONCAT('ALTER TABLE `payout_records` DROP FOREIGN KEY `', CONSTRAINT_NAME, '`')
    FROM information_schema.KEY_COLUMN_USAGE
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'payout_records'
      AND COLUMN_NAME = 'partner_id';
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
  OPEN cur;
  read_loop: LOOP
    FETCH cur INTO sql_stmt;
    IF done THEN LEAVE read_loop; END IF;
    SET @s = sql_stmt;
    PREPARE stmt FROM @s;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END LOOP;
  CLOSE cur;
END$$
DELIMITER ;
CALL drop_payout_partner_fk();
DROP PROCEDURE drop_payout_partner_fk;

ALTER TABLE payout_records DROP COLUMN partner_id;

-- Drop the retired tables (all empty).
DROP TABLE IF EXISTS admin_users;
DROP TABLE IF EXISTS admin_bookings;
DROP TABLE IF EXISTS admin_payments;
DROP TABLE IF EXISTS customers;

-- Summary of what Hibernate will recreate on next boot:
--   reviews.customer_id  -> users.id
--   reviews.booking_id   -> bookings.id
--   disputes.booking_id  -> bookings.id
--   payout_records.worker_id -> users.id (column re-added by ddl-auto=update)
