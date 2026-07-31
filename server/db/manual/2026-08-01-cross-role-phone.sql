-- Run once on existing MySQL databases before deploying the cross-role change
-- that lets the same phone number be registered as BOTH a customer and a
-- partner (separate role-scoped accounts). The old unique index on phone is
-- replaced by a unique index on (phone, role).
-- New databases are handled by Hibernate from the UserAccount entity.
-- Safe to run multiple times: every statement is guarded by an INFORMATION_SCHEMA check.

-- 1. Drop the old phone-wide unique indexes. This covers the manually created
--    uq_users_phone as well as any unique index created automatically by
--    Hibernate from the earlier unique=true annotation on the phone column
--    (name like UK<hash>). Both would block the second role.
SET @old_phone_uniques := (
    SELECT GROUP_CONCAT(CONCAT('ALTER TABLE users DROP INDEX `', INDEX_NAME, '`') SEPARATOR ';')
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'users'
      AND NON_UNIQUE = 0
      AND COLUMN_NAME = 'phone'
      AND INDEX_NAME <> 'PRIMARY'
      AND INDEX_NAME <> 'uq_users_phone_role'
      AND NOT EXISTS (
          SELECT 1
          FROM INFORMATION_SCHEMA.STATISTICS multi
          WHERE multi.TABLE_SCHEMA = INFORMATION_SCHEMA.STATISTICS.TABLE_SCHEMA
            AND multi.TABLE_NAME = INFORMATION_SCHEMA.STATISTICS.TABLE_NAME
            AND multi.INDEX_NAME = INFORMATION_SCHEMA.STATISTICS.INDEX_NAME
            AND multi.COLUMN_NAME <> 'phone'
      )
);
SET @drop_old_phone_uniques_sql := IF(@old_phone_uniques IS NULL, 'SELECT 1', @old_phone_uniques);
PREPARE drop_old_phone_uniques_stmt FROM @drop_old_phone_uniques_sql;
EXECUTE drop_old_phone_uniques_stmt;
DEALLOCATE PREPARE drop_old_phone_uniques_stmt;

-- 2. Enforce uniqueness per (phone, role) so one number can own both a
--    customer and a partner account, but never two accounts of the same role.
SET @phone_role_unique := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'users'
      AND INDEX_NAME = 'uq_users_phone_role'
);
SET @add_phone_role_unique_sql := IF(
    @phone_role_unique = 0,
    'ALTER TABLE users ADD UNIQUE INDEX uq_users_phone_role (phone, role)',
    'SELECT 1'
);
PREPARE phone_role_unique_stmt FROM @add_phone_role_unique_sql;
EXECUTE phone_role_unique_stmt;
DEALLOCATE PREPARE phone_role_unique_stmt;
