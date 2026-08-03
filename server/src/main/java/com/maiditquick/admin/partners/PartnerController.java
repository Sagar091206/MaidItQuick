package com.maiditquick.admin.partners;

import com.maiditquick.admin.audit.AuditService;
import com.maiditquick.admin.common.ApiResponse;
import com.maiditquick.admin.common.NotFoundException;
import com.maiditquick.admin.common.PageResponse;
import com.maiditquick.admin.notifications.Notification;
import com.maiditquick.admin.notifications.NotificationRepository;
import jakarta.persistence.criteria.Predicate;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

@RestController
@RequestMapping("/api/v1/admin/partners")
public class PartnerController {

  private final PartnerRepository partners;
  private final AuditService audit;
  private final NotificationRepository notifications;
  private final Path uploadDir;

  public PartnerController(PartnerRepository partners, AuditService audit,
                           NotificationRepository notifications,
                           @Value("${app.uploads-dir:uploads}") String uploadsDir) {
    this.partners = partners;
    this.audit = audit;
    this.notifications = notifications;
    this.uploadDir = Paths.get(uploadsDir).toAbsolutePath().normalize();
  }

  @GetMapping("/pending-count")
  @PreAuthorize("hasAuthority('PARTNERS_READ')")
  public ApiResponse<Long> pendingCount() {
    return ApiResponse.ok(partners.countByKycStatusAndDeletedAtIsNull("PENDING"));
  }

  @GetMapping
  @PreAuthorize("hasAuthority('PARTNERS_READ')")
  public ApiResponse<PageResponse<Partner>> list(
      @RequestParam(defaultValue = "") String query,
      @RequestParam(defaultValue = "") String status,
      @RequestParam(defaultValue = "") String deleted,
      @RequestParam(defaultValue = "0") @Min(0) int page,
      @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
    PageRequest pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "id"));
    Page<Partner> result = partners.findAll(listSpec(query, status, deleted), pageable);
    return ApiResponse.ok(PageResponse.from(result));
  }

  private Specification<Partner> listSpec(String query, String status, String deleted) {
    return (root, q, cb) -> {
      List<Predicate> ands = new ArrayList<>();
      boolean showDeleted = "true".equalsIgnoreCase(deleted);
      ands.add(showDeleted ? cb.isNotNull(root.get("deletedAt")) : cb.isNull(root.get("deletedAt")));
      if (!status.isBlank()) ands.add(cb.equal(root.get("kycStatus"), status));
      if (!query.isBlank()) {
        String like = "%" + query.trim().toLowerCase() + "%";
        ands.add(cb.or(
            cb.like(cb.lower(root.get("name")), like),
            cb.like(cb.lower(root.get("phone")), like),
            cb.like(cb.lower(root.get("email")), like)));
      }
      return cb.and(ands.toArray(new Predicate[0]));
    };
  }

  @GetMapping("/{id}")
  @PreAuthorize("hasAuthority('PARTNERS_READ')")
  public ApiResponse<Partner> get(@PathVariable long id) {
    return ApiResponse.ok(find(id));
  }

  @PostMapping
  @PreAuthorize("hasAuthority('PARTNERS_WRITE')")
  public ApiResponse<Partner> create(@Valid @RequestBody Upsert body, HttpServletRequest req) {
    if (partners.existsByPhone(body.phone().trim())) {
      throw new IllegalArgumentException("A partner with this phone number already exists");
    }
    Partner p = new Partner();
    apply(p, body);
    Partner saved = partners.save(p);
    audit.record("PARTNER_CREATED", "PARTNERS", String.valueOf(saved.getId()), null,
        "{\"name\":\"" + saved.getName() + "\",\"phone\":\"" + saved.getPhone() + "\",\"kycStatus\":\"" + saved.getKycStatus() + "\"}", req);
    return ApiResponse.created(saved);
  }

  @PutMapping("/{id}")
  @PreAuthorize("hasAuthority('PARTNERS_WRITE')")
  public ApiResponse<Partner> update(@PathVariable long id, @Valid @RequestBody Upsert body, HttpServletRequest req) {
    if (partners.existsByPhoneAndIdNot(body.phone().trim(), id)) {
      throw new IllegalArgumentException("A partner with this phone number already exists");
    }
    Partner p = find(id);
    apply(p, body);
    p.setUpdatedAt(Instant.now());
    Partner saved = partners.save(p);
    audit.record("PARTNER_UPDATED", "PARTNERS", String.valueOf(id), null,
        "{\"name\":\"" + saved.getName() + "\",\"phone\":\"" + saved.getPhone() + "\"}", req);
    return ApiResponse.ok(saved);
  }

  @PostMapping("/{id}/approve")
  @PreAuthorize("hasAuthority('PARTNERS_WRITE')")
  public ApiResponse<Partner> approve(@PathVariable long id, HttpServletRequest req) {
    Partner p = find(id);
    p.setKycStatus("APPROVED");
    p.setApprovedAt(Instant.now());
    p.setRejectionReason(null);
    p.setUpdatedAt(Instant.now());
    Partner saved = partners.save(p);
    notify("Profile approved — " + saved.getName(),
        saved.getName() + " can now start receiving service requests. A push notification was sent to the partner app.",
        "SUCCESS");
    audit.record("PARTNER_APPROVED", "PARTNERS", String.valueOf(id), null,
        "{\"kycStatus\":\"APPROVED\",\"approvedAt\":\"" + saved.getApprovedAt() + "\"}", req);
    return ApiResponse.ok("Partner profile approved and partner app notified", saved);
  }

  @PostMapping("/{id}/reject")
  @PreAuthorize("hasAuthority('PARTNERS_WRITE')")
  public ApiResponse<Partner> reject(@PathVariable long id, @Valid @RequestBody RejectInput input, HttpServletRequest req) {
    Partner p = find(id);
    p.setKycStatus("REJECTED");
    p.setRejectionReason(input.reason().trim());
    p.setApprovedAt(null);
    p.setUpdatedAt(Instant.now());
    Partner saved = partners.save(p);
    notify("Profile rejected — " + saved.getName(),
        "Feedback was sent to the partner app: " + saved.getRejectionReason(), "ERROR");
    audit.record("PARTNER_REJECTED", "PARTNERS", String.valueOf(id), null,
        "{\"kycStatus\":\"REJECTED\",\"reason\":\"" + saved.getRejectionReason() + "\"}", req);
    return ApiResponse.ok("Partner profile rejected and feedback sent to partner app", saved);
  }

  @PostMapping("/{id}/documents")
  @PreAuthorize("hasAuthority('PARTNERS_WRITE')")
  public ApiResponse<Partner> uploadDocuments(
      @PathVariable long id,
      @RequestParam(value = "identity", required = false) MultipartFile identity,
      @RequestParam(value = "address", required = false) MultipartFile address,
      @RequestParam(value = "identityDocType", required = false) String identityDocType,
      HttpServletRequest req) {
    Partner p = find(id);
    if (identityDocType != null && !identityDocType.isBlank()) {
      p.setIdentityDocType(identityDocType);
    }
    if (identity != null && !identity.isEmpty()) {
      deleteFile(p.getIdentityDocPath());
      p.setIdentityDocPath(saveFile(identity, id + "-identity"));
    }
    if (address != null && !address.isEmpty()) {
      deleteFile(p.getAddressDocPath());
      p.setAddressDocPath(saveFile(address, id + "-address"));
    }
    p.setUpdatedAt(Instant.now());
    Partner saved = partners.save(p);
    audit.record("PARTNER_DOCUMENTS_UPDATED", "PARTNERS", String.valueOf(id), null,
        "{\"identityDocPath\":\"" + saved.getIdentityDocPath() + "\",\"addressDocPath\":\"" + saved.getAddressDocPath() + "\"}", req);
    return ApiResponse.ok("Documents uploaded", saved);
  }

  @PostMapping("/{id}/suspend")
  @PreAuthorize("hasAuthority('PARTNERS_WRITE')")
  public ApiResponse<Partner> suspend(@PathVariable long id, HttpServletRequest req) {
    Partner p = find(id);
    if (p.getDeletedAt() != null) throw new IllegalArgumentException("Partner is deleted");
    if ("SUSPENDED".equals(p.getAccountStatus())) throw new IllegalArgumentException("Partner is already suspended");
    p.setAccountStatus("SUSPENDED");
    p.setSuspendedAt(Instant.now());
    p.setUpdatedAt(Instant.now());
    Partner saved = partners.save(p);
    notify("Account suspended — " + saved.getName(),
        saved.getName() + " will not receive new service requests until reactivated.", "ERROR");
    audit.record("PARTNER_SUSPENDED", "PARTNERS", String.valueOf(id), null,
        "{\"accountStatus\":\"SUSPENDED\",\"name\":\"" + saved.getName() + "\"}", req);
    return ApiResponse.ok("Partner account suspended", saved);
  }

  @PostMapping("/{id}/activate")
  @PreAuthorize("hasAuthority('PARTNERS_WRITE')")
  public ApiResponse<Partner> activate(@PathVariable long id, HttpServletRequest req) {
    Partner p = find(id);
    if (p.getDeletedAt() != null) throw new IllegalArgumentException("Partner is deleted");
    if ("ACTIVE".equals(p.getAccountStatus())) throw new IllegalArgumentException("Partner account is already active");
    p.setAccountStatus("ACTIVE");
    p.setSuspendedAt(null);
    p.setUpdatedAt(Instant.now());
    Partner saved = partners.save(p);
    notify("Account reactivated — " + saved.getName(),
        saved.getName() + " can receive service requests again.", "SUCCESS");
    audit.record("PARTNER_ACTIVATED", "PARTNERS", String.valueOf(id), null,
        "{\"accountStatus\":\"ACTIVE\",\"name\":\"" + saved.getName() + "\"}", req);
    return ApiResponse.ok("Partner account activated", saved);
  }

  @DeleteMapping("/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @PreAuthorize("hasAuthority('PARTNERS_WRITE')")
  public void delete(@PathVariable long id, HttpServletRequest req) {
    Partner p = find(id);
    if (p.getDeletedAt() != null) throw new IllegalArgumentException("Partner is already deleted");
    p.setDeletedAt(Instant.now());
    p.setUpdatedAt(Instant.now());
    partners.save(p);
    audit.record("PARTNER_DELETED", "PARTNERS", String.valueOf(id), null,
        "{\"softDelete\":true,\"name\":\"" + p.getName() + "\"}", req);
  }

  @PostMapping("/{id}/restore")
  @PreAuthorize("hasAuthority('PARTNERS_WRITE')")
  public ApiResponse<Partner> restore(@PathVariable long id, HttpServletRequest req) {
    Partner p = find(id);
    if (p.getDeletedAt() == null) throw new IllegalArgumentException("Partner is not deleted");
    p.setDeletedAt(null);
    p.setUpdatedAt(Instant.now());
    Partner saved = partners.save(p);
    audit.record("PARTNER_RESTORED", "PARTNERS", String.valueOf(id), null,
        "{\"name\":\"" + saved.getName() + "\"}", req);
    return ApiResponse.ok("Partner restored", saved);
  }

  private void deleteFile(String urlPath) {
    if (urlPath == null || urlPath.isBlank()) return;
    try {
      Files.deleteIfExists(uploadDir.resolve(Paths.get(urlPath.replace("/uploads/", "")).getFileName().toString()));
    } catch (IOException ignored) {
    }
  }

  private void apply(Partner p, Upsert body) {
    p.setName(body.name().trim());
    p.setPhone(body.phone().trim());
    p.setEmail(body.email() == null ? null : body.email().trim());
    p.setAddress(body.address());
    p.setIdentityDocType(body.identityDocType() == null ? "AADHAAR" : body.identityDocType());
    p.setBankAccountHolder(body.bankAccountHolder());
    p.setBankAccountNumber(body.bankAccountNumber());
    p.setBankIfsc(body.bankIfsc());
    p.setUpiId(body.upiId());
    p.setLatitude(body.latitude());
    p.setLongitude(body.longitude());
  }

  private Partner find(long id) {
    return partners.findById(id).orElseThrow(() -> NotFoundException.of("Partner", id));
  }

  private void notify(String title, String message, String type) {
    Notification n = new Notification();
    n.setTitle(title);
    n.setMessage(message);
    n.setType(type);
    notifications.save(n);
  }

  private String saveFile(MultipartFile file, String prefix) {
    try {
      String original = file.getOriginalFilename() == null ? "file" : file.getOriginalFilename();
      String ext = original.contains(".")
          ? original.substring(original.lastIndexOf('.')).toLowerCase()
          : ".bin";
      if (ext.length() > 10) ext = ".bin";
      Files.createDirectories(uploadDir.resolve("partners"));
      String name = prefix + "-" + System.currentTimeMillis() + ext;
      Path target = uploadDir.resolve("partners").resolve(name);
      file.transferTo(target);
      return "/uploads/partners/" + name;
    } catch (IOException e) {
      throw new IllegalArgumentException("Could not store uploaded document: " + e.getMessage());
    }
  }

  public record Upsert(
      @NotBlank @Size(max = 160) String name,
      @NotBlank @Size(max = 40) String phone,
      @Email @Size(max = 255) String email,
      @Size(max = 500) String address,
      @Pattern(regexp = "GOVT_ID|AADHAAR|DRIVING_LICENSE") String identityDocType,
      @Size(max = 160) String bankAccountHolder,
      @Size(max = 40) String bankAccountNumber,
      @Size(max = 20) String bankIfsc,
      @Size(max = 80) String upiId,
      @DecimalMin("-90") @DecimalMax("90") Double latitude,
      @DecimalMin("-180") @DecimalMax("180") Double longitude) {
  }

  public record RejectInput(
      @NotBlank @Size(max = 1000) String reason) {
  }
}
