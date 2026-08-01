-- 2026-07-31-revoked-tokens.sql
-- Adds the revoked_tokens table used by JwtService for token revocation
-- (logout) and hourly purge. Mirrors the RevokedToken JPA entity so that
-- existing databases do not depend on Hibernate ddl-auto.
-- Idempotent: safe to run more than once.

CREATE TABLE IF NOT EXISTS revoked_tokens (
    id         BIGINT       NOT NULL AUTO_INCREMENT,
    token_hash VARCHAR(64)  NOT NULL,
    expires_at DATETIME(6)  NULL,
    created_at DATETIME(6)  NULL,
    PRIMARY KEY (id)
) ENGINE = InnoDB;

-- Lookup by token hash must be unique: a token can only be revoked once.
SET @idx := (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'revoked_tokens'
      AND index_name = 'uk_revoked_tokens_token_hash'
);
SET @sql := IF(@idx = 0,
    'CREATE UNIQUE INDEX uk_revoked_tokens_token_hash ON revoked_tokens (token_hash)',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Hourly purge of expired entries is served by this index.
SET @idx := (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'revoked_tokens'
      AND index_name = 'idx_revoked_tokens_expires_at'
);
SET @sql := IF(@idx = 0,
    'CREATE INDEX idx_revoked_tokens_expires_at ON revoked_tokens (expires_at)',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
