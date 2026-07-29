-- Run once on existing MySQL databases before deploying the Partner phone-first login change.
-- New databases are handled by Hibernate from the UserAccount entity.

SET @email_unique_index := (
    SELECT INDEX_NAME
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'users'
      AND COLUMN_NAME = 'email'
      AND NON_UNIQUE = 0
      AND INDEX_NAME <> 'PRIMARY'
    LIMIT 1
);

SET @drop_email_unique_sql := IF(
    @email_unique_index IS NULL,
    'SELECT 1',
    CONCAT('ALTER TABLE users DROP INDEX `', @email_unique_index, '`')
);
PREPARE drop_email_unique_stmt FROM @drop_email_unique_sql;
EXECUTE drop_email_unique_stmt;
DEALLOCATE PREPARE drop_email_unique_stmt;

UPDATE users
SET phone = CONCAT('UNSET-', id)
WHERE phone IS NULL OR TRIM(phone) = '';

UPDATE users
SET email = ''
WHERE role = 'WORKER'
  AND email LIKE 'partner+%@phone.maiditquick.local';

ALTER TABLE users MODIFY email VARCHAR(255) NOT NULL;
ALTER TABLE users MODIFY phone VARCHAR(255) NOT NULL;

SET @phone_unique_index := (
    SELECT INDEX_NAME
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'users'
      AND COLUMN_NAME = 'phone'
      AND NON_UNIQUE = 0
      AND INDEX_NAME <> 'PRIMARY'
    LIMIT 1
);

SET @create_phone_unique_sql := IF(
    @phone_unique_index IS NULL,
    'CREATE UNIQUE INDEX uk_users_phone ON users (phone)',
    'SELECT 1'
);
PREPARE create_phone_unique_stmt FROM @create_phone_unique_sql;
EXECUTE create_phone_unique_stmt;
DEALLOCATE PREPARE create_phone_unique_stmt;
