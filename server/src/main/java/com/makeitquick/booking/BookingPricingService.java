package com.makeitquick.booking;

import com.makeitquick.catalog.ServiceAreaOfferingService;
import com.makeitquick.catalog.ServiceItem;
import com.makeitquick.catalog.ServiceItemRepository;
import com.makeitquick.promo.DiscountResult;
import com.makeitquick.promo.PromotionService;
import com.makeitquick.security.UserAccount;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Server-authoritative pricing for bookings.
 *
 * <p>Each selected task contributes {@code pricePaise x (durationMinutes / 60)}
 * with a minimum of one hour per task. A GST component is computed on the
 * discounted subtotal and a convenience fee may apply. The same calculation
 * drives the quote endpoint and the amount captured on the booking at creation,
 * so the price shown before payment is authoritative for the transaction.</p>
 */
@Service
public class BookingPricingService {

    /** GST rate applied on the discounted subtotal (18%). */
    public static final double GST_RATE = 0.18;

    /** Convenience fee in paise (0 in the MVP). */
    public static final int CONVENIENCE_FEE_PAISE = 0;

    private final ServiceItemRepository services;
    private final ServiceAreaOfferingService areaOfferings;
    private final PromotionService promotionService;

    BookingPricingService(ServiceItemRepository services, ServiceAreaOfferingService areaOfferings,
                          PromotionService promotionService) {
        this.services = services;
        this.areaOfferings = areaOfferings;
        this.promotionService = promotionService;
    }

    /**
     * Builds the full itemised quote view: lines, subtotal, discount (first-order or promo),
     * GST, convenience fee and the total payable amount.
     */
    public Map<String, Object> quote(List<String> names, int durationMinutes, String promoCode) {
        return quote(names, durationMinutes, promoCode, null, null);
    }

    public Map<String, Object> quote(List<String> names, int durationMinutes, String promoCode, String pinCode) {
        return quote(names, durationMinutes, promoCode, pinCode, null);
    }

    public Map<String, Object> quote(List<String> names, int durationMinutes, String promoCode, String pinCode,
                                     UserAccount customer) {
        double hours = Math.max(1.0, durationMinutes / 60.0);
        List<Map<String, Object>> lines = new ArrayList<>();
        long subtotal = 0;
        for (String name : names) {
            ServiceItem item = services.findByEnabledTrueAndNameIgnoreCase(name)
                    .orElseThrow(() -> new ResponseStatusException(
                            HttpStatus.BAD_REQUEST, name + " is not available"));
            int unitPrice = pinCode == null || pinCode.isBlank() ? item.getPricePaise()
                    : areaOfferings.require(pinCode, item.getName()).getPricePaise();
            long amount = Math.round(unitPrice * hours);
            subtotal += amount;
            Map<String, Object> line = new LinkedHashMap<>();
            line.put("name", item.getName());
            line.put("pricePaise", unitPrice);
            line.put("amountPaise", amount);
            lines.add(line);
        }
        DiscountResult discount = promotionService.calculateDiscount(customer, subtotal, promoCode);
        return totalsView(lines, subtotal, discount);
    }

    /** Total payable amount in paise for the given selection (booking creation). */
    public int totalPaise(List<String> names, int durationMinutes, String promoCode) {
        return totalPaise(names, durationMinutes, promoCode, null, null);
    }

    public int totalPaise(List<String> names, int durationMinutes, String promoCode, String pinCode) {
        return totalPaise(names, durationMinutes, promoCode, pinCode, null);
    }

    public int totalPaise(List<String> names, int durationMinutes, String promoCode, String pinCode,
                          UserAccount customer) {
        Map<String, Object> quote = quote(names, durationMinutes, promoCode, pinCode, customer);
        return Math.toIntExact((long) quote.get("totalPaise"));
    }

    public DiscountResult calculateDiscount(UserAccount customer, long subtotalPaise, String promoCode) {
        return promotionService.calculateDiscount(customer, subtotalPaise, promoCode);
    }

    /** Validated promo discount in paise (throws for unknown codes). */
    public int discountPaise(String promoCode) {
        return discountPaise(null, 100000, promoCode);
    }

    public int discountPaise(UserAccount customer, long subtotalPaise, String promoCode) {
        return promotionService.calculateDiscount(customer, subtotalPaise, promoCode).discountPaise();
    }

    public PromotionService getPromotionService() {
        return promotionService;
    }

    private Map<String, Object> totalsView(List<Map<String, Object>> lines, long subtotal,
                                           DiscountResult discount) {
        long discounted = Math.max(0, subtotal - discount.discountPaise());
        long tax = Math.round(discounted * GST_RATE);
        long total = discounted + tax + CONVENIENCE_FEE_PAISE;
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("currency", "INR");
        result.put("lines", lines);
        result.put("subtotalPaise", subtotal);
        result.put("originalAmountPaise", subtotal);
        result.put("discountType", discount.type().name());
        result.put("discountPercentage", discount.percentage());
        result.put("discountPaise", discount.discountPaise());
        result.put("discountMessage", discount.message());
        result.put("promoCode", discount.promoCode());
        result.put("taxPaise", tax);
        result.put("convenienceFeePaise", CONVENIENCE_FEE_PAISE);
        result.put("totalPaise", total);
        result.put("finalPayableAmountPaise", total);
        return result;
    }
}
