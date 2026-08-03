-- ============================================================
-- MaidItQuick Admin Management System — reference schema (US 1.1)
-- ============================================================
-- NOTE: This file is a documentation snapshot generated from the
-- live MySQL database. Hibernate (spring.jpa.hibernate.ddl-auto=update)
-- remains the source of truth and creates/updates tables on startup;
-- no migration tool is used (Flyway/Liquibase intentionally absent).
-- US 1.1 login tables: `admins` (incl. last_login) + `admin_refresh_tokens`.
-- US 1.2: `password_reset_tokens`.
-- This snapshot covers only the identity/RBAC boundary; business tables
-- (users, customers, services, categories, bookings, payments, reviews,
-- notifications, settings, partners) are Hibernate-managed on startup.

CREATE TABLE `admin_roles` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `code` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UK_role_code` (`code`)
) ENGINE=InnoDB;

CREATE TABLE `admins` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `email` varchar(255) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `display_name` varchar(255) NOT NULL,
  `enabled` bit(1) NOT NULL,
  `locked_until` datetime(6) DEFAULT NULL,
  `failed_attempts` int NOT NULL,
  `last_login` datetime(6) DEFAULT NULL,
  `role_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UK_admin_email` (`email`),
  KEY `FK_admin_role` (`role_id`),
  CONSTRAINT `FK_admin_role` FOREIGN KEY (`role_id`) REFERENCES `admin_roles` (`id`)
) ENGINE=InnoDB;

CREATE TABLE `admin_refresh_tokens` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `token_hash` varchar(255) DEFAULT NULL,     -- SHA-256 digest, never the raw token
  `expires_at` datetime(6) DEFAULT NULL,       -- 7 days
  `revoked_at` datetime(6) DEFAULT NULL,       -- set on rotation / logout
  `ip_address` varchar(255) DEFAULT NULL,
  `user_agent` varchar(255) DEFAULT NULL,
  `admin_id` bigint DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FK_refresh_admin` (`admin_id`),
  CONSTRAINT `FK_refresh_admin` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`)
) ENGINE=InnoDB;

CREATE TABLE `password_reset_tokens` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) NOT NULL,
  `expires_at` datetime(6) NOT NULL,   -- 15 minutes after creation
  `token_hash` varchar(255) NOT NULL,  -- SHA-256 digest, never the raw token
  `used` bit(1) NOT NULL,              -- set when invalidated / consumed
  `admin_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UK_prt_token_hash` (`token_hash`),
  KEY `idx_prt_admin_id` (`admin_id`),
  KEY `idx_prt_token_hash` (`token_hash`),
  KEY `idx_prt_expires_at` (`expires_at`),
  CONSTRAINT `FK_prt_admin` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`)
) ENGINE=InnoDB;
