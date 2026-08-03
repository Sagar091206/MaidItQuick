package com.makeitquick.security;

import java.util.List;

/**
 * The admin permission catalog. With the identity model unified on
 * {@link UserAccount}, {@link Role#ADMIN} is the single administrator role and
 * carries every permission. The catalog is used to build the {@code permissions}
 * JWT claim, the authorities granted by the security filter and the read-only
 * roles API.
 */
public final class AdminPermissions {

    public static final List<String> ALL = List.of(
            "DASHBOARD_VIEW", "AUTH_PROFILE", "USERS_READ", "USERS_WRITE",
            "ROLES_READ", "ROLES_WRITE", "SERVICES_READ", "SERVICES_WRITE",
            "CATEGORIES_READ", "CATEGORIES_WRITE", "BOOKINGS_READ", "BOOKINGS_WRITE",
            "PARTNERS_READ", "PARTNERS_WRITE", "CUSTOMERS_READ", "CUSTOMERS_WRITE",
            "PAYMENTS_READ", "PAYMENTS_WRITE", "REVIEWS_READ", "REVIEWS_WRITE",
            "NOTIFICATIONS_READ", "NOTIFICATIONS_WRITE", "SETTINGS_READ", "SETTINGS_WRITE",
            "REPORTS_VIEW", "AUDIT_READ", "ADMINS_MANAGE",
            "SETTLEMENTS_READ", "SETTLEMENTS_WRITE", "OVERRIDES_WRITE",
            "DISPUTES_READ", "DISPUTES_WRITE");

    private AdminPermissions() {
    }
}
