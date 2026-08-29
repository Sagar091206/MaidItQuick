package com.makeitquick.booking;

import com.makeitquick.catalog.ServiceItem;
import com.makeitquick.catalog.ServiceItemRepository;
import com.makeitquick.security.Role;
import com.makeitquick.security.SessionResolver;
import com.makeitquick.security.UserAccount;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/booking")
@CrossOrigin(origins = "*")
@Validated
public class BookingPlanningController {
    private static final List<LocalTime> SLOTS = List.of(
            LocalTime.of(8, 0),
            LocalTime.of(10, 0),
            LocalTime.of(12, 0),
            LocalTime.of(14, 0),
            LocalTime.of(16, 0),
            LocalTime.of(18, 0));

    private final ServiceItemRepository services;
    private final SessionResolver resolver;
    private final BookingPricingService pricing;

    BookingPlanningController(ServiceItemRepository services, SessionResolver resolver,
                              BookingPricingService pricing) {
        this.services = services;
        this.resolver = resolver;
        this.pricing = pricing;
    }

    @GetMapping("/slots")
    public List<Map<String, Object>> slots(
            @RequestParam @Pattern(regexp = "\\d{6}") String pinCode,
            @RequestParam(required = false) String date) {
        LocalDate selectedDate;
        if (date == null || date.isBlank()) {
            selectedDate = LocalDate.now();
        } else {
            try {
                selectedDate = LocalDate.parse(date);
            } catch (java.time.format.DateTimeParseException e) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid date. Use the YYYY-MM-DD format.");
            }
        }
        LocalDate today = LocalDate.now();
        LocalTime now = LocalTime.now();
        return SLOTS.stream()
                .map(slot -> Map.<String, Object>of(
                        "time", slot.toString(),
                        "available", selectedDate.isAfter(today) || (selectedDate.isEqual(today) && slot.isAfter(now)),
                        "pinCode", pinCode))
                .toList();
    }

    @PostMapping("/calculate-duration")
    public Map<String, Object> calculateDuration(@Valid @RequestBody DurationInput input) {
        List<String> names = input.services() == null ? List.of() : input.services().stream()
                .filter(service -> service != null && !service.isBlank())
                .map(String::trim)
                .toList();
        if (names.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Choose at least one service");
        }
        int minutes = 0;
        for (String name : names) {
            ServiceItem item = services.findByEnabledTrueAndNameIgnoreCase(name).orElse(null);
            minutes += item == null ? 60 : Math.max(30, item.getDefaultDurationMinutes());
        }
        return Map.of("durationMinutes", minutes, "serviceCount", names.size());
    }

    /**
     * Server-authoritative itemised quote for the booking summary.
     * Each task contributes pricePaise x (durationMinutes / 60), with a
     * minimum of one hour per task. Discounts come from validated promo codes;
     * GST and the convenience fee are added by {@link BookingPricingService}.
     */
    @GetMapping("/quote")
    public Map<String, Object> quote(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @RequestParam("services") List<String> servicesParam,
            @RequestParam @Min(30) @Max(480) int durationMinutes,
            @RequestParam(required = false) @Pattern(regexp = "\\d{6}") String pinCode,
            @RequestParam(required = false) String promoCode) {
        requireCustomer(authorization);
        List<String> names = servicesParam.stream()
                .map(String::trim).filter(name -> !name.isBlank()).distinct().toList();
        if (names.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Choose at least one service");
        }
        return pricing.quote(names, durationMinutes, promoCode, pinCode);
    }

    private void requireCustomer(String authorization) {
        UserAccount user = resolver.fromBearer(authorization)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Please sign in"));
        if (user.getRole() != Role.CUSTOMER) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Customer access required");
        }
    }

    record DurationInput(List<@NotBlank String> services) {}
}
