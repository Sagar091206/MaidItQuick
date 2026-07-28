package com.makeitquick.customer;

import com.makeitquick.security.Role;
import com.makeitquick.security.Session;
import com.makeitquick.security.SessionRepository;
import com.makeitquick.security.UserAccount;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/customer")
@CrossOrigin(origins = "*")
public class CustomerExperienceController {
    private final SavedAddressRepository addresses;
    private final SessionRepository sessions;

    CustomerExperienceController(SavedAddressRepository addresses, SessionRepository sessions) {
        this.addresses = addresses;
        this.sessions = sessions;
    }

    @GetMapping("/addresses")
    public List<SavedAddress> listAddresses(@RequestHeader(value = "Authorization", required = false) String authorization) {
        return addresses.findByCustomerOrderByIdDesc(requireCustomer(authorization));
    }

    @PostMapping("/addresses")
    public SavedAddress addAddress(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @Valid @RequestBody AddressInput input) {
        return addresses.save(new SavedAddress(
                requireCustomer(authorization), input.label().trim(), input.address().trim(), input.pinCode()));
    }

    @DeleteMapping("/addresses/{id}")
    public Map<String, String> deleteAddress(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @PathVariable Long id) {
        SavedAddress address = addresses.findByIdAndCustomer(id, requireCustomer(authorization))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Address not found"));
        addresses.delete(address);
        return Map.of("message", "Address removed");
    }

    @PostMapping("/promos/validate")
    public Map<String, Object> validatePromo(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @Valid @RequestBody PromoInput input) {
        requireCustomer(authorization);
        String code = input.code().toUpperCase();
        return switch (code) {
            case "WELCOME50" -> Map.of("valid", true, "code", code, "discountPaise", 5000, "message", "Rs 50 off");
            case "MAKEITQUICK100" -> Map.of("valid", true, "code", code, "discountPaise", 10000, "message", "Rs 100 off");
            default -> throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Promo code is invalid");
        };
    }

    @GetMapping("/referral")
    public Map<String, String> referral(@RequestHeader(value = "Authorization", required = false) String authorization) {
        UserAccount customer = requireCustomer(authorization);
        return Map.of("code", "MIQ" + String.format("%06d", customer.getId()), "message", "Share this code with friends.");
    }

    private UserAccount requireCustomer(String authorization) {
        String token = authorization == null ? "" : authorization.replaceFirst("(?i)^Bearer\\s+", "");
        UserAccount user = sessions.findByToken(token).filter(Session::valid).map(Session::getUser)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Please sign in"));
        if (user.getRole() != Role.CUSTOMER) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Customer access required");
        }
        return user;
    }

    record AddressInput(@NotBlank String label, @NotBlank String address,
                        @Pattern(regexp = "\\d{6}", message = "PIN code must have six digits") String pinCode) {}
    record PromoInput(@NotBlank String code) {}
}
