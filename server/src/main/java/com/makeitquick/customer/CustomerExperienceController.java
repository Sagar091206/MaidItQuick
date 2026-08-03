package com.makeitquick.customer;

import com.makeitquick.security.Role;
import com.makeitquick.security.SessionResolver;
import com.makeitquick.security.UserAccount;
import com.makeitquick.security.UserRepository;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import com.makeitquick.booking.Booking;
import com.makeitquick.booking.BookingRepository;
import com.makeitquick.booking.BookingStatus;
import com.makeitquick.catalog.ServiceItem;
import com.makeitquick.catalog.ServiceItemRepository;
import java.time.LocalDate;
import java.util.EnumSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
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
    private final SessionResolver resolver;
    private final UserRepository users;
    private final BookingRepository bookings;
    private final ServiceItemRepository services;

    CustomerExperienceController(
            SavedAddressRepository addresses,
            SessionResolver resolver,
            UserRepository users,
            BookingRepository bookings,
            ServiceItemRepository services) {
        this.addresses = addresses;
        this.resolver = resolver;
        this.users = users;
        this.bookings = bookings;
        this.services = services;
    }

    @GetMapping("/me")
    public Map<String, Object> profile(
            @RequestHeader(value = "Authorization", required = false) String authorization) {
        return profileView(requireCustomer(authorization));
    }

    @GetMapping("/profile")
    public Map<String, Object> customerProfile(
            @RequestHeader(value = "Authorization", required = false) String authorization) {
        return profileView(requireCustomer(authorization));
    }

    @PutMapping("/me")
    public Map<String, Object> updateProfile(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @Valid @RequestBody ProfileInput input) {
        return saveProfile(authorization, input);
    }

    @PutMapping("/profile")
    public Map<String, Object> updateCustomerProfile(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @Valid @RequestBody ProfileInput input) {
        return saveProfile(authorization, input);
    }

    private Map<String, Object> saveProfile(String authorization, ProfileInput input) {
        UserAccount customer = requireCustomer(authorization);
        customer.setName(input.name().trim());
        if (input.email() != null && !input.email().isBlank()) {
            customer.setEmail(input.email().trim().toLowerCase());
        } else {
            customer.setEmail("");
        }
        if (input.gender() != null && !input.gender().isBlank()) {
            customer.setGender(normalizeGender(input.gender()));
        } else {
            customer.setGender(null);
        }
        customer.setDob(parseDob(input.dob()));
        customer.setProfileImage(normalizePhoto(input.profileImage()));
        customer.setProfileCompleted(customer.getName() != null && !customer.getName().isBlank());
        return profileView(users.save(customer));
    }

    private static String normalizePhoto(String profileImage) {
        try {
            return com.makeitquick.common.ProfilePhotos.normalize(profileImage);
        } catch (IllegalArgumentException e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, e.getMessage());
        }
    }

    @GetMapping("/dashboard")
    public Map<String, Object> dashboard(
            @RequestHeader(value = "Authorization", required = false) String authorization) {
        UserAccount customer = requireCustomer(authorization);
        List<SavedAddress> savedAddresses = addresses.findByCustomerOrderByIdDesc(customer);
        List<Map<String, Object>> serviceCategories = services.findByEnabledTrueOrderByNameAsc().stream()
                .map(this::serviceView)
                .toList();
        List<Booking> customerBookings = bookings.findByCustomerIdOrderByIdDesc(customer.getId());
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("welcomeName", customer.getName());
        payload.put("addresses", savedAddresses);
        payload.put("services", serviceCategories);
        payload.put("activeBooking", customerBookings.stream()
                .filter(this::isActiveBooking)
                .findFirst()
                .map(this::bookingView)
                .orElse(null));
        payload.put("recentBooking", customerBookings.stream()
                .filter(booking -> booking.getStatus() == BookingStatus.COMPLETED)
                .findFirst()
                .map(this::bookingView)
                .orElse(null));
        return payload;
    }

    @GetMapping("/addresses")
    public List<SavedAddress> listAddresses(@RequestHeader(value = "Authorization", required = false) String authorization) {
        return addresses.findByCustomerOrderByIdDesc(requireCustomer(authorization));
    }

    @GetMapping("/address")
    public List<SavedAddress> listAddressAlias(@RequestHeader(value = "Authorization", required = false) String authorization) {
        return listAddresses(authorization);
    }

    @PostMapping("/addresses")
    public SavedAddress addAddress(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @Valid @RequestBody AddressInput input) {
        UserAccount customer = requireCustomer(authorization);
        SavedAddress saved = addresses.save(new SavedAddress(customer, toDetails(input)));
        if (addresses.countByCustomer(customer) == 1 || input.defaultAddress()) {
            setDefaultAddress(customer, saved);
            return addresses.findById(saved.getId()).orElse(saved);
        }
        return saved;
    }

    @PostMapping("/address")
    public SavedAddress addAddressAlias(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @Valid @RequestBody AddressInput input) {
        return addAddress(authorization, input);
    }

    @PutMapping("/addresses/{id}")
    public SavedAddress updateAddress(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @PathVariable Long id,
            @Valid @RequestBody AddressInput input) {
        UserAccount customer = requireCustomer(authorization);
        SavedAddress address = getAddress(customer, id);
        address.apply(toDetails(input));
        SavedAddress saved = addresses.save(address);
        if (input.defaultAddress()) {
            setDefaultAddress(customer, saved);
            return addresses.findById(saved.getId()).orElse(saved);
        }
        return saved;
    }

    @PutMapping("/address/{id}")
    public SavedAddress updateAddressAlias(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @PathVariable Long id,
            @Valid @RequestBody AddressInput input) {
        return updateAddress(authorization, id, input);
    }

    @PutMapping("/addresses/{id}/default")
    public SavedAddress defaultAddress(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @PathVariable Long id) {
        UserAccount customer = requireCustomer(authorization);
        SavedAddress address = getAddress(customer, id);
        setDefaultAddress(customer, address);
        return addresses.findById(address.getId()).orElse(address);
    }

    @DeleteMapping("/addresses/{id}")
    public Map<String, String> deleteAddress(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @PathVariable Long id) {
        UserAccount customer = requireCustomer(authorization);
        SavedAddress address = getAddress(customer, id);
        if (addresses.countByCustomer(customer) <= 1
                && bookings.existsByCustomerIdAndStatusIn(
                        customer.getId(),
                        EnumSet.of(
                                BookingStatus.REQUESTED,
                                BookingStatus.ASSIGNED,
                                BookingStatus.ACCEPTED,
                                BookingStatus.ON_THE_WAY,
                                BookingStatus.ARRIVED,
                                BookingStatus.IN_PROGRESS))) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT,
                    "Cannot remove your only address while you have an active booking.");
        }
        addresses.delete(address);
        if (address.isDefaultAddress()) {
            addresses.findByCustomerOrderByIdDesc(customer).stream()
                    .findFirst()
                    .ifPresent(next -> setDefaultAddress(customer, next));
        }
        return Map.of("message", "Address removed");
    }

    @DeleteMapping("/address/{id}")
    public Map<String, String> deleteAddressAlias(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @PathVariable Long id) {
        return deleteAddress(authorization, id);
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
        UserAccount user = resolver.fromBearer(authorization)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Please sign in"));
        if (user.getRole() != Role.CUSTOMER) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Customer access required");
        }
        return user;
    }

    private Map<String, Object> profileView(UserAccount customer) {
        return Map.of(
                "name", customer.getName(),
                "phone", customer.getPhone(),
                "email", customer.getEmail(),
                "gender", customer.getGender(),
                "dob", customer.getDob() == null ? "" : customer.getDob().toString(),
                "profileImage", customer.getProfileImage(),
                "profileComplete", customer.profileComplete());
    }

    private LocalDate parseDob(String raw) {
        if (raw == null || raw.isBlank()) return null;
        try {
            return LocalDate.parse(raw.trim());
        } catch (RuntimeException error) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Enter date of birth as YYYY-MM-DD.");
        }
    }

    private String normalizeGender(String raw) {
        String value = raw.trim().toUpperCase();
        if (!value.matches("MALE|FEMALE|OTHER|PREFER_NOT_TO_SAY")) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Choose a valid gender option.");
        }
        return value;
    }

    private SavedAddress getAddress(UserAccount customer, Long id) {
        return addresses.findByIdAndCustomer(id, customer)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Address not found"));
    }

    private void setDefaultAddress(UserAccount customer, SavedAddress selected) {
        addresses.findByCustomerOrderByIdDesc(customer).forEach(entry -> {
            if (entry.isDefaultAddress()) {
                entry.setDefaultAddress(false);
                addresses.save(entry);
            }
        });
        selected.setDefaultAddress(true);
        addresses.save(selected);
    }

    private AddressDetails toDetails(AddressInput input) {
        return new AddressDetails(
                input.label(),
                input.houseNumber(),
                input.building(),
                input.street(),
                input.area(),
                input.landmark(),
                input.city(),
                input.state(),
                input.pinCode(),
                input.latitude(),
                input.longitude());
    }

    private boolean isActiveBooking(Booking booking) {
        return EnumSet.of(
                        BookingStatus.REQUESTED,
                        BookingStatus.ASSIGNED,
                        BookingStatus.ACCEPTED,
                        BookingStatus.ON_THE_WAY,
                        BookingStatus.ARRIVED,
                        BookingStatus.IN_PROGRESS)
                .contains(booking.getStatus());
    }

    private Map<String, Object> bookingView(Booking booking) {
        Map<String, Object> view = new LinkedHashMap<>();
        view.put("id", booking.getId());
        view.put("service", booking.getService());
        view.put("address", booking.getAddress());
        view.put("pinCode", booking.getPinCode());
        view.put("scheduledFor", booking.getScheduledFor());
        view.put("durationMinutes", booking.getDurationMinutes());
        view.put("specialInstructions", booking.getSpecialInstructions());
        view.put("status", booking.getStatus());
        view.put("worker", booking.getWorker() == null ? "Unassigned" : booking.getWorker().getName());
        return view;
    }

    private Map<String, Object> serviceView(ServiceItem service) {
        Map<String, Object> view = new LinkedHashMap<>();
        view.put("id", service.getId());
        view.put("name", service.getName());
        view.put("pricePaise", service.getPricePaise());
        view.put("description", service.getDescription());
        view.put("emoji", service.getEmoji());
        view.put("defaultDurationMinutes", service.getDefaultDurationMinutes());
        view.put("enabled", service.isEnabled());
        return view;
    }

    record AddressInput(
            @NotBlank String label,
            @NotBlank String houseNumber,
            String building,
            @NotBlank String street,
            @NotBlank String area,
            String landmark,
            @NotBlank String city,
            @NotBlank String state,
            @Pattern(regexp = "\\d{6}", message = "PIN code must have six digits") String pinCode,
            Double latitude,
            Double longitude,
            boolean defaultAddress) {}
    record PromoInput(@NotBlank String code) {}
    record ProfileInput(
            @NotBlank String name,
            @Email(message = "Enter a valid email address") String email,
            @Pattern(regexp = "MALE|FEMALE|OTHER|PREFER_NOT_TO_SAY", flags = Pattern.Flag.CASE_INSENSITIVE)
                    String gender,
            String dob,
            @jakarta.validation.constraints.Size(max = 2_900_000, message = "The photo is too large.")
            String profileImage) {}
}
