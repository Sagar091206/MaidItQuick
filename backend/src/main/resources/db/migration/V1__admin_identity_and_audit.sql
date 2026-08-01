CREATE TABLE IF NOT EXISTS admin_roles (
    id BIGINT NOT NULL AUTO_INCREMENT,
    code VARCHAR(80) NOT NULL,
    name VARCHAR(120) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_admin_roles_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS admin_permissions (
    id BIGINT NOT NULL AUTO_INCREMENT,
    code VARCHAR(120) NOT NULL,
    description VARCHAR(255),
    PRIMARY KEY (id),
    UNIQUE KEY uk_admin_permissions_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS admins (
    id BIGINT NOT NULL AUTO_INCREMENT,
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    display_name VARCHAR(160) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    locked_until DATETIME NULL,
    failed_attempts INT NOT NULL DEFAULT 0,
    role_id BIGINT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),
    UNIQUE KEY uk_admin_email (email),
    KEY idx_admin_role (role_id),

    CONSTRAINT fk_admin_role
        FOREIGN KEY (role_id)
        REFERENCES admin_roles(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS admin_permissions (
    id BIGINT NOT NULL AUTO_INCREMENT,
    code VARCHAR(120) NOT NULL,
    description VARCHAR(255),
    PRIMARY KEY (id),
    UNIQUE KEY uk_permission_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS admin_role_permissions (
    role_id BIGINT NOT NULL,
    permission_id BIGINT NOT NULL,

    PRIMARY KEY (role_id, permission_id),

    KEY idx_role(role_id),
    KEY idx_permission(permission_id),

    CONSTRAINT fk_role_permission_role
        FOREIGN KEY (role_id)
        REFERENCES admin_roles(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_role_permission_permission
        FOREIGN KEY (permission_id)
        REFERENCES admin_permissions(id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS admin_refresh_tokens (
    id BIGINT NOT NULL AUTO_INCREMENT,
    admin_id BIGINT NOT NULL,
    token_hash VARCHAR(128) NOT NULL,
    expires_at DATETIME NOT NULL,
    revoked_at DATETIME NULL,
    ip_address VARCHAR(64),
    user_agent VARCHAR(512),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY(id),
    UNIQUE KEY uk_token_hash(token_hash),
    KEY idx_refresh_admin(admin_id),

    CONSTRAINT fk_refresh_admin
        FOREIGN KEY(admin_id)
        REFERENCES admins(id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS audit_logs (
    id BIGINT NOT NULL AUTO_INCREMENT,
    admin_id BIGINT NULL,
    occurred_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address VARCHAR(64),
    browser VARCHAR(512),
    action VARCHAR(120) NOT NULL,
    module VARCHAR(100) NOT NULL,
    record_id VARCHAR(128),
    previous_value JSON,
    new_value JSON,

    PRIMARY KEY(id),
    KEY idx_audit_admin(admin_id),

    CONSTRAINT fk_audit_admin
        FOREIGN KEY(admin_id)
        REFERENCES admins(id)
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO admin_roles(code,name)
VALUES
('SUPER_ADMIN','Super Administrator');

INSERT IGNORE INTO admin_permissions(code,description)
VALUES
('DASHBOARD_VIEW','View dashboard'),
('USERS_READ','View users'),
('USERS_WRITE','Manage user state'),
('BOOKINGS_READ','View bookings'),
('PARTNERS_READ','View partners'),
('PAYMENTS_READ','View payments'),
('AUDIT_READ','View audit logs'),
('ADMINS_MANAGE','Manage administrators');

INSERT IGNORE INTO admin_role_permissions(role_id,permission_id)
SELECT
    r.id,
    p.id
FROM admin_roles r
CROSS JOIN admin_permissions p
WHERE r.code='SUPER_ADMIN';