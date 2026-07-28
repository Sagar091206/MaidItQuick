package com.makeitquick.worker;

import com.makeitquick.security.Role;
import com.makeitquick.security.Session;
import com.makeitquick.security.SessionRepository;
import com.makeitquick.security.UserAccount;
import com.makeitquick.operations.AvailabilityStatus;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.List;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/workers")
@CrossOrigin(origins = "*")
public class WorkerSafetyController {
    private static final Set<String> ACCEPTED_TYPES = Set.of("application/pdf", "image/jpeg", "image/png");

    private final WorkerProfileRepository profiles;
    private final SessionRepository sessions;
    private final Path uploadDirectory;

    WorkerSafetyController(
            WorkerProfileRepository profiles,
            SessionRepository sessions,
            @Value("${app.uploads.directory:uploads/kyc}") String uploadDirectory) {
        this.profiles = profiles;
        this.sessions = sessions;
        this.uploadDirectory = Path.of(uploadDirectory).toAbsolutePath().normalize();
    }

    @GetMapping("/me")
    public Map<String, Object> myProfile(@RequestHeader(value = "Authorization", required = false) String authorization) {
        return view(profileForWorker(requireUser(authorization)));
    }

    @PostMapping(value = "/me/kyc", consumes = "multipart/form-data")
    public Map<String, Object> uploadKyc(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @RequestPart("document") MultipartFile document) {
        WorkerProfile profile = profileForWorker(requireUser(authorization));
        if (document.isEmpty() || !ACCEPTED_TYPES.contains(document.getContentType())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Upload a PDF, JPG, or PNG identity document");
        }
        try {
            Files.createDirectories(uploadDirectory);
            String extension = document.getContentType().equals("application/pdf") ? ".pdf"
                    : document.getContentType().equals("image/png") ? ".png" : ".jpg";
            String fileName = UUID.randomUUID() + extension;
            Files.copy(document.getInputStream(), uploadDirectory.resolve(fileName), StandardCopyOption.REPLACE_EXISTING);
            profile.submitKyc(fileName);
            return view(profiles.save(profile));
        } catch (IOException exception) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Document could not be stored");
        }
    }

    @PostMapping("/me/payout-details")
    public Map<String, Object> savePayoutDetails(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @Valid @RequestBody PayoutInput input) {
        WorkerProfile profile = profileForWorker(requireUser(authorization));
        profile.setPayout(input.accountLast4(), input.ifsc().toUpperCase());
        return view(profiles.save(profile));
    }

    @PostMapping("/me/availability")
    public Map<String, Object> setAvailability(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @Valid @RequestBody AvailabilityInput input) {
        WorkerProfile profile = profileForWorker(requireUser(authorization));
        if (input.status() == AvailabilityStatus.AVAILABLE && profile.getKycStatus() != VerificationStatus.APPROVED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Approved KYC is required before going available");
        }
        profile.setAvailability(input.status());
        return view(profiles.save(profile));
    }

    @PostMapping("/me/location")
    public Map<String, Object> updateLocation(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @Valid @RequestBody LocationInput input) {
        WorkerProfile profile = profileForWorker(requireUser(authorization));
        profile.updateLocation(input.latitude(), input.longitude());
        return view(profiles.save(profile));
    }

    @GetMapping
    public List<Map<String, Object>> listWorkers(
            @RequestHeader(value = "Authorization", required = false) String authorization) {
        requireAdmin(authorization);
        return profiles.findAll().stream().map(this::view).toList();
    }

    @PostMapping("/{id}/approve")
    public Map<String, Object> approve(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @PathVariable Long id) {
        requireAdmin(authorization);
        WorkerProfile profile = getProfile(id);
        if (profile.getKycStatus() != VerificationStatus.PENDING) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Only pending KYC can be approved");
        }
        profile.approve();
        return view(profiles.save(profile));
    }

    @PostMapping("/{id}/reject")
    public Map<String, Object> reject(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @PathVariable Long id) {
        requireAdmin(authorization);
        WorkerProfile profile = getProfile(id);
        if (profile.getKycStatus() != VerificationStatus.PENDING) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Only pending KYC can be rejected");
        }
        profile.reject();
        return view(profiles.save(profile));
    }

    private UserAccount requireUser(String authorization) {
        String token = authorization == null ? "" : authorization.replaceFirst("(?i)^Bearer\\s+", "");
        return sessions.findByToken(token).filter(Session::valid).map(Session::getUser)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Please sign in"));
    }

    private WorkerProfile profileForWorker(UserAccount user) {
        if (user.getRole() != Role.WORKER) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Worker access required");
        }
        return profiles.findByUser(user).orElseGet(() -> profiles.save(new WorkerProfile(user)));
    }

    private void requireAdmin(String authorization) {
        if (requireUser(authorization).getRole() != Role.ADMIN) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Admin access required");
        }
    }

    private WorkerProfile getProfile(Long id) {
        return profiles.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Worker profile not found"));
    }

    private Map<String, Object> view(WorkerProfile profile) {
        Map<String, Object> view = new HashMap<>();
        view.put("id", profile.getId()); view.put("userId", profile.getUser().getId());
        view.put("name", profile.getUser().getName()); view.put("email", profile.getUser().getEmail());
        view.put("kycStatus", profile.getKycStatus()); view.put("backgroundCheckStatus", profile.getBackgroundCheckStatus());
        view.put("availability", profile.getAvailability()); view.put("payoutDetailsVerified", profile.isPayoutDetailsVerified());
        view.put("latitude", profile.getLastLatitude()); view.put("longitude", profile.getLastLongitude());
        view.put("locationUpdatedAt", profile.getLocationUpdatedAt());
        return view;
    }

    record PayoutInput(@NotBlank String accountLast4, @NotBlank String ifsc) {
        PayoutInput {
            if (!accountLast4.matches("\\d{4}")) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Enter only the final four account digits");
            }
            if (!ifsc.matches("^[A-Za-z]{4}0[A-Za-z0-9]{6}$")) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Enter a valid IFSC code");
            }
        }
    }
    record AvailabilityInput(AvailabilityStatus status) {}
    record LocationInput(@jakarta.validation.constraints.DecimalMin("-90.0") @jakarta.validation.constraints.DecimalMax("90.0") double latitude,
                         @jakarta.validation.constraints.DecimalMin("-180.0") @jakarta.validation.constraints.DecimalMax("180.0") double longitude) {}
}
