-- MaidItQuick — auth profile photo storage
-- Date: 2026-07-31
-- Widens users.profile_image so customer avatar data URIs (base64 JPG/PNG/WebP)
-- can be stored. Hibernate's ddl-auto=update will not alter an existing
-- VARCHAR(1000) column, so run this once against existing databases.
-- Safe to run repeatedly; the statement is idempotent.
ALTER TABLE users MODIFY profile_image LONGTEXT NULL;
