package com.makeitquick.payment;

import com.makeitquick.booking.Booking;
import com.makeitquick.booking.BookingRepository;
import com.makeitquick.security.Role;
import com.makeitquick.security.SessionResolver;
import com.makeitquick.security.UserAccount;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

/** Customer payment endpoints: intent, pay, and latest payment status. */
@RestController
@RequestMapping("/api/bookings")
@CrossOrigin(origins = "*")
public class PaymentController {
    private final BookingRepository bookings;
    private final PaymentService payments;
    private final SessionResolver resolver;

    PaymentController(BookingRepository bookings, PaymentService payments, SessionResolver resolver) {
        this.bookings = bookings;
        this.payments = payments;
        this.resolver = resolver;
    }

    @PostMapping("/{id}/pay-intent")
    public Map<String, Object> intent(@RequestHeader("Authorization") String h,
                                      @PathVariable Long id,
                                      @Valid @RequestBody MethodInput input) {
        return payments.createIntent(ownBooking(h, id), input.method().toUpperCase());
    }

    @PostMapping("/{id}/pay")
    public Map<String, Object> pay(@RequestHeader("Authorization") String h,
                                   @PathVariable Long id,
                                   @Valid @RequestBody PayInput input) {
        return payments.pay(ownBooking(h, id), input.intentId(),
                input.method().toUpperCase(), input.upiId(), input.cardLast4(), input.bankName());
    }

    @GetMapping("/{id}/payment")
    public Map<String, Object> payment(@RequestHeader("Authorization") String h,
                                       @PathVariable Long id) {
        return payments.latest(ownBooking(h, id));
    }

    private Booking ownBooking(String header, Long id) {
        UserAccount user = resolver.fromBearer(header)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Please sign in"));
        if (user.getRole() != Role.CUSTOMER) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Customer access required");
        }
        return bookings.findById(id)
                .filter(b -> b.getCustomer().getId().equals(user.getId()))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Booking not found"));
    }

    record MethodInput(@NotBlank String method) {}
    record PayInput(@NotBlank String intentId,
                    @NotBlank String method,
                    String upiId,
                    @Pattern(regexp = "\\d{4}") String cardLast4,
                    String bankName) {}
}
