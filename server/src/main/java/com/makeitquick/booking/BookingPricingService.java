package com.makeitquick.booking;

import com.makeitquick.catalog.ServiceItem;
import com.makeitquick.catalog.ServiceItemRepository;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

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
    private final com.makeitquick.catalog.ServiceAreaOfferingService areaOfferings;

    BookingPricingService(ServiceItemRepository services, com.makeitquick.catalog.ServiceAreaOfferingService areaOfferings) {
        this.services = services;
        this.areaOfferings = areaOfferings;
    }

    /**
     * Builds the full itemised quote view: lines, subtotal, promo discount,
     * GST, convenience fee and the total payable amount.
     */
    public Map<String, Object> quote(List<String> names, int durationMinutes, String promoCode) {
        return quote(names, durationMinutes, promoCode, null);
    }

    public Map<String, Object> quote(List<String> names, int durationMinutes, String promoCode, String pinCode) {
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
        int discount = promoDiscount(promoCode);
        return totalsView(lines, subtotal, discount, promoCode);
    }

    /** Total payable amount in paise for the given selection (booking creation). */
    public int totalPaise(List<String> names, int durationMinutes, String promoCode) {
        Map<String, Object> quote = quote(names, durationMinutes, promoCode);
        return Math.toIntExact((long) quote.get("totalPaise"));
    }

    public int totalPaise(List<String> names, int durationMinutes, String promoCode, String pinCode) {
        return Math.toIntExact((long) quote(names, durationMinutes, promoCode, pinCode).get("totalPaise"));
    }

    /** Validated promo discount in paise (throws for unknown codes). */
    public int discountPaise(String promoCode) {
        return promoDiscount(promoCode);
    }

    private Map<String, Object> totalsView(List<Map<String, Object>> lines, long subtotal,
                                           int discount, String promoCode) {
        long discounted = Math.max(0, subtotal - discount);
        long tax = Math.round(discounted * GST_RATE);
        long total = discounted + tax + CONVENIENCE_FEE_PAISE;
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("currency", "INR");
        result.put("lines", lines);
        result.put("subtotalPaise", subtotal);
        result.put("promoCode", promoCode == null ? "" : promoCode.trim().toUpperCase());
        result.put("discountPaise", discount);
        result.put("taxPaise", tax);
        result.put("convenienceFeePaise", CONVENIENCE_FEE_PAISE);
        result.put("totalPaise", total);
        return result;
    }

    private int promoDiscount(String code) {
        if (code == null || code.isBlank()) return 0;
        return switch (code.trim().toUpperCase()) {
            case "WELCOME50" -> 5000;
            case "MAKEITQUICK100" -> 10000;
            default -> throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Promo code is invalid");
        };
    }
}
