package com.makeitquick.promo;

import com.makeitquick.admin.settings.Setting;
import com.makeitquick.admin.settings.SettingRepository;
import com.makeitquick.booking.Booking;
import com.makeitquick.booking.BookingRepository;
import com.makeitquick.booking.BookingStatus;
import com.makeitquick.payment.PaymentStatus;
import com.makeitquick.security.Role;
import com.makeitquick.security.UserAccount;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.List;

@Service
public class PromotionService {

    public static final String FIRST_ORDER_DISCOUNT_KEY = "FIRST_ORDER_DISCOUNT_PCT";
    public static final int DEFAULT_FIRST_ORDER_DISCOUNT_PCT = 20;

    private final PromoCodeRepository promoCodes;
    private final SettingRepository settings;
    private final BookingRepository bookings;

    public PromotionService(PromoCodeRepository promoCodes, SettingRepository settings, BookingRepository bookings) {
        this.promoCodes = promoCodes;
        this.settings = settings;
        this.bookings = bookings;
    }

    /**
     * Retrieves the current admin-configured first-order discount percentage.
     * Defaults to 20% if not configured.
     */
    public int getFirstOrderDiscountPercentage() {
        return settings.findBySettingKey(FIRST_ORDER_DISCOUNT_KEY)
                .or(() -> settings.findBySettingKey("first_order_discount_pct"))
                .map(Setting::getSettingValue)
                .map(val -> {
                    try {
                        int pct = Integer.parseInt(val.trim());
                        return (pct >= 0 && pct <= 100) ? pct : DEFAULT_FIRST_ORDER_DISCOUNT_PCT;
                    } catch (NumberFormatException e) {
                        return DEFAULT_FIRST_ORDER_DISCOUNT_PCT;
                    }
                })
                .orElse(DEFAULT_FIRST_ORDER_DISCOUNT_PCT);
    }

    /**
     * Updates the first-order discount percentage in the settings table.
     */
    @Transactional
    public Setting setFirstOrderDiscountPercentage(int percentage) {
        if (percentage < 0 || percentage > 100) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Discount percentage must be between 0 and 100");
        }
        Setting setting = settings.findBySettingKey(FIRST_ORDER_DISCOUNT_KEY)
                .or(() -> settings.findBySettingKey("first_order_discount_pct"))
                .orElseGet(() -> {
                    Setting s = new Setting();
                    s.setSettingKey(FIRST_ORDER_DISCOUNT_KEY);
                    s.setDescription("First-order discount percentage for newly registered customers");
                    return s;
                });
        setting.setSettingValue(String.valueOf(percentage));
        setting.setUpdatedAt(Instant.now());
        return settings.save(setting);
    }

    /**
     * Checks whether the customer is eligible for a first-order discount.
     * Eligible if the customer has never had a successful (paid & uncancelled, or completed) booking.
     * Failed payments, unpaid bookings, or cancelled bookings do not consume eligibility.
     */
    public boolean isEligibleForFirstOrderDiscount(UserAccount customer) {
        if (customer == null || customer.getRole() != Role.CUSTOMER) {
            return false;
        }
        List<Booking> customerBookings = bookings.findByCustomerIdOrderByIdDesc(customer.getId());
        for (Booking b : customerBookings) {
            boolean isCompleted = b.getStatus() == BookingStatus.COMPLETED;
            boolean isPaidAndNotCancelled = b.getPaymentStatus() == PaymentStatus.PAID
                    && b.getStatus() != BookingStatus.CANCELLED;
            if (isCompleted || isPaidAndNotCancelled) {
                return false;
            }
        }
        return true;
    }

    /**
     * Validates and returns an active promo code.
     * Throws 400 Bad Request if promo does not exist or is inactive.
     */
    public PromoCode validatePromoCode(String code) {
        if (code == null || code.trim().isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Promo code cannot be empty");
        }
        String normalized = code.trim().toUpperCase();
        PromoCode promo = promoCodes.findByCodeIgnoreCase(normalized)
                .or(() -> {
                    if ("WELCOME50".equals(normalized)) {
                        return java.util.Optional.of(new PromoCode("WELCOME50", 0, 5000, true, "Flat Rs 50 off"));
                    }
                    if ("MAKEITQUICK100".equals(normalized)) {
                        return java.util.Optional.of(new PromoCode("MAKEITQUICK100", 0, 10000, true, "Flat Rs 100 off"));
                    }
                    return java.util.Optional.empty();
                })
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Promo code is invalid"));

        if (!promo.isEnabled()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Promo code is inactive");
        }
        return promo;
    }

    /**
     * Server-authoritative discount calculation enforcing the V1 Stacking Rule:
     * 1. If promo code is explicitly provided, validate and apply it.
     * 2. Otherwise, if customer is eligible for first-order discount and configured % > 0, apply first-order discount.
     * 3. Do not combine discounts.
     */
    public DiscountResult calculateDiscount(UserAccount customer, long subtotalPaise, String promoCode) {
        if (subtotalPaise <= 0) {
            return DiscountResult.none();
        }

        // Rule 1: Explicit promo code takes precedence
        if (promoCode != null && !promoCode.trim().isBlank()) {
            PromoCode promo = validatePromoCode(promoCode);
            int discountPaise;
            int percentage = promo.getDiscountPercentage();
            if (promo.getFixedDiscountPaise() != null && promo.getFixedDiscountPaise() > 0) {
                discountPaise = promo.getFixedDiscountPaise();
                if (subtotalPaise > 0) {
                    percentage = (int) Math.round(((double) discountPaise / subtotalPaise) * 100);
                }
            } else {
                discountPaise = (int) Math.round(subtotalPaise * (percentage / 100.0));
            }
            discountPaise = Math.min((int) subtotalPaise, discountPaise);
            return DiscountResult.promo(promo.getCode(), percentage, discountPaise);
        }

        // Rule 2: Automatic first-order discount if eligible
        int firstOrderPct = getFirstOrderDiscountPercentage();
        if (firstOrderPct > 0 && isEligibleForFirstOrderDiscount(customer)) {
            int discountPaise = (int) Math.round(subtotalPaise * (firstOrderPct / 100.0));
            discountPaise = Math.min((int) subtotalPaise, discountPaise);
            return DiscountResult.firstOrder(firstOrderPct, discountPaise);
        }

        return DiscountResult.none();
    }
}
