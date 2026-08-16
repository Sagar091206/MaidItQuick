package com.makeitquick.worker;

import com.makeitquick.operations.AvailabilityStatus;
import com.makeitquick.security.Role;
import com.makeitquick.security.SessionResolver;
import com.makeitquick.security.UserAccount;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/workers")
@CrossOrigin(origins = "*")
@Validated
public class WorkerSafetyController {
    private static final long MAX_UPLOAD_BYTES = 5L * 1024 * 1024;
    private static final Set<String> DOCUMENT_TYPES = Set.of("application/pdf", "image/jpeg", "image/png");
    private static final Set<String> IMAGE_TYPES = Set.of("image/jpeg", "image/png");

    private final WorkerProfileRepository profiles;
    private final SessionResolver resolver;
    private final Path uploadDirectory;

    WorkerSafetyController(
            WorkerProfileRepository profiles,
            SessionResolver resolver,
            @Value("${app.uploads.directory:uploads/kyc}") String uploadDirectory) {
        this.profiles = profiles;
        this.resolver = resolver;
        this.uploadDirectory = Path.of(uploadDirectory).toAbsolutePath().normalize();
    }

    @GetMapping("/me")
    public Map<String, Object> myProfile(@RequestHeader(value = "Authorization", required = false) String authorization) {
        return view(profileForWorker(requireUser(authorization)));
    }

    @PostMapping("/me/consent")
    public Map<String, Object> acceptConsent(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @Valid @RequestBody ConsentInput input) {
        WorkerProfile profile = profileForWorker(requireUser(authorization));
        if (!input.accepted()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Consent must be accepted before onboarding");
        }
        profile.acceptConsent();
        return view(profiles.save(profile));
    }

    @PostMapping(value = "/me/kyc", consumes = "multipart/form-data")
    public Map<String, Object> uploadKyc(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @RequestPart("document") MultipartFile document) {
        return uploadIdentityDocument(authorization, document);
    }

    @PostMapping(value = "/me/identity-document", consumes = "multipart/form-data")
    public Map<String, Object> uploadIdentityDocument(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @RequestPart("document") MultipartFile document) {
        WorkerProfile profile = profileForWorker(requireUser(authorization));
        profile.submitKyc(store(document, DOCUMENT_TYPES, "Upload a PDF, JPG, or PNG identity document"));
        return view(profiles.save(profile));
    }

    @PostMapping(value = "/me/pan", consumes = "multipart/form-data")
    public Map<String, Object> uploadPan(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @RequestParam("panNumber") @Pattern(regexp = "^[A-Za-z]{5}[0-9]{4}[A-Za-z]$") String panNumber,
            @RequestParam("panName") @NotBlank String panName,
            @RequestPart("document") MultipartFile document) {
        WorkerProfile profile = profileForWorker(requireUser(authorization));
        profile.submitPan(
                panNumber.trim().toUpperCase(),
                panName.trim(),
                store(document, DOCUMENT_TYPES, "Upload a PDF, JPG, or PNG PAN document"));
        return view(profiles.save(profile));
    }

    @PostMapping(value = "/me/profile-photo", consumes = "multipart/form-data")
    public Map<String, Object> uploadProfilePhoto(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @RequestPart("document") MultipartFile document) {
        WorkerProfile profile = profileForWorker(requireUser(authorization));
        profile.submitSelfie(store(document, IMAGE_TYPES, "Upload a JPG or PNG profile photo"));
        return view(profiles.save(profile));
    }

    @PostMapping("/me/address")
    public Map<String, Object> saveAddress(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @Valid @RequestBody AddressInput input) {
        WorkerProfile profile = profileForWorker(requireUser(authorization));
        profile.submitAddress(
                input.currentAddress().trim(),
                input.permanentAddress().trim(),
                input.city().trim(),
                input.state().trim(),
                input.pinCode().trim(),
                null);
        return view(profiles.save(profile));
    }

    @PostMapping(value = "/me/address-proof", consumes = "multipart/form-data")
    public Map<String, Object> uploadAddressProof(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @RequestPart("document") MultipartFile document) {
        WorkerProfile profile = profileForWorker(requireUser(authorization));
        profile.submitAddressProof(store(document, DOCUMENT_TYPES, "Upload a PDF, JPG, or PNG address proof"));
        return view(profiles.save(profile));
    }

    @PostMapping(value = "/me/police-verification", consumes = "multipart/form-data")
    public Map<String, Object> uploadPoliceVerification(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @RequestPart("document") MultipartFile document) {
        WorkerProfile profile = profileForWorker(requireUser(authorization));
        profile.submitPoliceVerification(store(document, DOCUMENT_TYPES, "Upload a PDF, JPG, or PNG police verification document"));
        return view(profiles.save(profile));
    }

    @PostMapping("/me/service-readiness")
    public Map<String, Object> saveServiceReadiness(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @Valid @RequestBody ServiceReadinessInput input) {
        WorkerProfile profile = profileForWorker(requireUser(authorization));
        profile.submitServiceReadiness(
                input.serviceCategories().trim(),
                input.workLocations().trim(),
                input.experienceSummary().trim(),
                input.availabilitySummary().trim(),
                input.partnerCodeAccepted());
        return view(profiles.save(profile));
    }

    @PostMapping("/me/payout-details")
    public Map<String, Object> savePayoutDetails(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @Valid @RequestBody PayoutInput input) {
        WorkerProfile profile = profileForWorker(requireUser(authorization));
        profile.setPayout(
                input.method().trim().toUpperCase(),
                input.accountHolderName().trim(),
                blankToNull(input.accountLast4()),
                blankToNull(input.ifsc()) == null ? null : input.ifsc().trim().toUpperCase(),
                blankToNull(input.upiId()));
        return view(profiles.save(profile));
    }

    @PostMapping("/me/availability")
    public Map<String, Object> setAvailability(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @Valid @RequestBody AvailabilityInput input) {
        WorkerProfile profile = profileForWorker(requireUser(authorization));
        if (input.status() == AvailabilityStatus.AVAILABLE && !profile.isReadyForJobs()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "All compliance and payout checks must be approved before going available");
        }
        profile.setAvailability(input.status());
        return view(profiles.save(profile));
    }

    @PostMapping("/me/service-areas")
    public Map<String, Object> setServiceAreas(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @Valid @RequestBody ServiceAreasInput input) {
        WorkerProfile profile = profileForWorker(requireUser(authorization));
        profile.setWorkLocations(input.locations().trim());
        return view(profiles.save(profile));
    }

    @PostMapping("/me/working-hours")
    public Map<String, Object> setWorkingHours(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @Valid @RequestBody WorkingHoursInput input) {
        WorkerProfile profile = profileForWorker(requireUser(authorization));
        profile.setWorkingHours(input.days().trim(), input.startTime(), input.endTime());
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
        if (!profile.hasSubmittedApprovalPack()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "All required partner onboarding items must be submitted before approval");
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
        profile.reject();
        return view(profiles.save(profile));
    }

    private String store(MultipartFile file, Set<String> acceptedTypes, String message) {
        if (file.isEmpty() || file.getSize() > MAX_UPLOAD_BYTES || !acceptedTypes.contains(file.getContentType())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, message);
        }
        try {
            Files.createDirectories(uploadDirectory);
            String extension = extensionFor(file.getContentType());
            String fileName = UUID.randomUUID() + extension;
            Files.copy(file.getInputStream(), uploadDirectory.resolve(fileName), StandardCopyOption.REPLACE_EXISTING);
            return fileName;
        } catch (IOException exception) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Document could not be stored");
        }
    }

    private String extensionFor(String contentType) {
        if ("application/pdf".equals(contentType)) return ".pdf";
        if ("image/png".equals(contentType)) return ".png";
        return ".jpg";
    }

    private UserAccount requireUser(String authorization) {
        return resolver.fromBearer(authorization)
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
        view.put("id", profile.getId());
        view.put("userId", profile.getUser().getId());
        view.put("name", profile.getUser().getName());
        view.put("email", profile.getUser().getEmail());
        view.put("phone", profile.getUser().getPhone());
        view.put("gender", profile.getUser().getGender());
        view.put("dob", profile.getUser().getDob() == null ? "" : profile.getUser().getDob().toString());
        view.put("profileImage", profile.getUser().getProfileImage());
        view.put("consentAccepted", profile.isConsentAccepted());
        view.put("consentAcceptedAt", profile.getConsentAcceptedAt());
        view.put("kycStatus", profile.getKycStatus());
        view.put("identityStatus", profile.getKycStatus());
        view.put("panStatus", profile.getPanStatus());
        view.put("panLast4", last4(profile.getPanNumber()));
        view.put("panName", profile.getPanName());
        view.put("selfieStatus", profile.getSelfieStatus());
        view.put("addressStatus", profile.getAddressStatus());
        view.put("addressProofSubmitted", profile.hasAddressProof());
        view.put("backgroundCheckStatus", profile.getBackgroundCheckStatus());
        view.put("availability", profile.getAvailability());
        view.put("payoutMethod", profile.getPayoutMethod());
        view.put("payoutAccountHolderName", profile.getPayoutAccountHolderName());
        view.put("bankAccountLast4", profile.getBankAccountLast4());
        view.put("bankIfsc", profile.getBankIfsc());
        view.put("upiId", profile.getUpiId());
        view.put("payoutDetailsVerified", profile.isPayoutDetailsVerified());
        view.put("payoutStatus", !profile.hasPayoutDetails() ? "NOT_SUBMITTED"
                : profile.isPayoutDetailsVerified() ? "APPROVED" : "PENDING");
        view.put("serviceReadinessComplete", profile.isPartnerCodeAccepted());
        view.put("serviceCategories", profile.getServiceCategories());
        view.put("workLocations", profile.getWorkLocations());
        view.put("experienceSummary", profile.getExperienceSummary());
        view.put("availabilitySummary", profile.getAvailabilitySummary());
        view.put("workingDays", profile.getWorkingDays());
        view.put("workingStartTime", profile.getWorkingStartTime());
        view.put("workingEndTime", profile.getWorkingEndTime());
        view.put("readyForJobs", profile.isReadyForJobs());
        String applicationStatus = profile.isReadyForJobs() ? "APPROVED"
                : profile.hasRejectedChecks() ? "REJECTED"
                : profile.hasSubmittedApprovalPack() ? "UNDER_REVIEW" : "INCOMPLETE";
        int stageIndex = profile.isReadyForJobs() ? 6
                : profile.hasPayoutDetails() ? 4
                : profile.hasAddressDetails() ? 2
                : profile.isConsentAccepted() ? 1 : 0;
        view.put("applicationStatus", applicationStatus);
        view.put("outcome", applicationStatus);
        if (profile.hasRejectedChecks()) {
            view.put("rejectionReason",
                    "One or more KYC checks were rejected. Replace the rejected details and resubmit them for review.");
            view.put("correctionSection", firstRejectedSection(profile));
        }
        view.put("stageIndex", stageIndex);
        view.put("lastUpdatedAt", profile.getServiceReadinessSubmittedAt() != null
                ? profile.getServiceReadinessSubmittedAt() : profile.getConsentAcceptedAt());
        view.put("latitude", profile.getLastLatitude());
        view.put("longitude", profile.getLastLongitude());
        view.put("locationUpdatedAt", profile.getLocationUpdatedAt());
        return view;
    }

    private String firstRejectedSection(WorkerProfile profile) {
        if (profile.getAddressStatus() == VerificationStatus.REJECTED) return "address";
        if (profile.getKycStatus() == VerificationStatus.REJECTED
                || profile.getPanStatus() == VerificationStatus.REJECTED
                || profile.getSelfieStatus() == VerificationStatus.REJECTED
                || profile.getBackgroundCheckStatus() == VerificationStatus.REJECTED) {
            return "identity";
        }
        return "payout";
    }

    private String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    private String last4(String value) {
        if (value == null || value.length() < 4) return null;
        return value.substring(value.length() - 4);
    }

    record ConsentInput(boolean accepted) {}
    record AddressInput(@NotBlank String currentAddress, @NotBlank String permanentAddress,
                        @NotBlank String city, @NotBlank String state,
                        @Pattern(regexp = "^\\d{6}$") String pinCode) {}
    record ServiceReadinessInput(@NotBlank String serviceCategories, @NotBlank String workLocations,
                                 @NotBlank String experienceSummary, @NotBlank String availabilitySummary,
                                 boolean partnerCodeAccepted) {
        ServiceReadinessInput {
            if (!partnerCodeAccepted) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Accept the Partner code of conduct to continue");
            }
        }
    }
    record PayoutInput(@NotBlank String method, @NotBlank String accountHolderName,
                       String accountLast4, String ifsc, String upiId) {
        PayoutInput {
            String normalized = method == null ? "" : method.trim().toUpperCase();
            if (!normalized.equals("BANK") && !normalized.equals("UPI")) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Choose BANK or UPI payout");
            }
            if (normalized.equals("BANK")) {
                if (accountLast4 == null || !accountLast4.matches("\\d{4}")) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Enter only the final four account digits");
                }
                if (ifsc == null || !ifsc.matches("^[A-Za-z]{4}0[A-Za-z0-9]{6}$")) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Enter a valid IFSC code");
                }
            }
            if (normalized.equals("UPI") && (upiId == null || !upiId.matches("^[A-Za-z0-9._-]{2,}@[A-Za-z]{2,}$"))) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Enter a valid UPI ID");
            }
        }
    }
    record AvailabilityInput(AvailabilityStatus status) {}
    record ServiceAreasInput(@NotBlank String locations) {}
    record WorkingHoursInput(@NotBlank String days, @NotBlank @Pattern(regexp = "^([01]\\d|2[0-3]):[0-5]\\d$") String startTime,
                             @NotBlank @Pattern(regexp = "^([01]\\d|2[0-3]):[0-5]\\d$") String endTime) {}

    record LocationInput(@DecimalMin("-90.0") @DecimalMax("90.0") double latitude,
                         @DecimalMin("-180.0") @DecimalMax("180.0") double longitude) {}
}
