-- Service details: description, emoji and default duration for the customer
-- service-details screen (CUS-US-001). Run once on existing databases; fresh
-- databases get these columns from the ServiceItem entity via Hibernate.

SET @description_col := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'service_catalog' AND COLUMN_NAME = 'description');
SET @sql1 := IF(@description_col = 0,
    'ALTER TABLE service_catalog ADD COLUMN description TEXT NULL',
    'SELECT 1');
PREPARE stmt1 FROM @sql1; EXECUTE stmt1; DEALLOCATE PREPARE stmt1;

SET @emoji_col := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'service_catalog' AND COLUMN_NAME = 'emoji');
SET @sql2 := IF(@emoji_col = 0,
    "ALTER TABLE service_catalog ADD COLUMN emoji VARCHAR(8) NULL",
    'SELECT 1');
PREPARE stmt2 FROM @sql2; EXECUTE stmt2; DEALLOCATE PREPARE stmt2;

SET @duration_col := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'service_catalog' AND COLUMN_NAME = 'default_duration_minutes');
SET @sql3 := IF(@duration_col = 0,
    'ALTER TABLE service_catalog ADD COLUMN default_duration_minutes INT NOT NULL DEFAULT 60',
    'SELECT 1');
PREPARE stmt3 FROM @sql3; EXECUTE stmt3; DEALLOCATE PREPARE stmt3;

-- Seed the presentation fields for the seeded catalog (idempotent: only rows
-- that still carry empty values are touched).
UPDATE service_catalog
   SET emoji = '🛁',
       description = 'Deep cleaning of sinks, taps, mirrors, tiles and WC using the supplies you provide at home.'
 WHERE (emoji IS NULL OR emoji = '') AND name LIKE '%bath%';

UPDATE service_catalog
   SET emoji = '🍳',
       description = 'Degreasing of the hob, chimney, countertops, sink and cabinets using the supplies you provide at home.'
 WHERE (emoji IS NULL OR emoji = '') AND name LIKE '%kitchen%';

UPDATE service_catalog
   SET emoji = '🛏️',
       description = 'Bed-making, dusting of furniture and fixtures, and floor care for the bedrooms.'
 WHERE (emoji IS NULL OR emoji = '') AND name LIKE '%bed%';

UPDATE service_catalog
   SET emoji = '🪴',
       description = 'Sweeping, mopping and dusting of the balcony area with the supplies you provide at home.'
 WHERE (emoji IS NULL OR emoji = '') AND name LIKE '%balcony%';

UPDATE service_catalog
   SET emoji = '🛋️',
       description = 'Full dusting, sofa and floor care for the living room using the supplies you provide at home.'
 WHERE (emoji IS NULL OR emoji = '') AND name LIKE '%living%';

-- Backfill the default duration (drives /api/booking/calculate-duration and
-- the quote amount). Idempotent: rows already carrying the seed value are
-- skipped, so this can be re-run safely.
UPDATE service_catalog SET default_duration_minutes = 60
 WHERE name LIKE '%bath%' AND default_duration_minutes = 0;

UPDATE service_catalog SET default_duration_minutes = 90
 WHERE name LIKE '%kitchen%' AND default_duration_minutes = 0;

UPDATE service_catalog SET default_duration_minutes = 60
 WHERE name LIKE '%bed%' AND default_duration_minutes = 0;

UPDATE service_catalog SET default_duration_minutes = 45
 WHERE name LIKE '%balcony%' AND default_duration_minutes = 0;

UPDATE service_catalog SET default_duration_minutes = 60
 WHERE name LIKE '%living%' AND default_duration_minutes = 0;
