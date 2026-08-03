package com.makeitquick.admin.support;

import com.makeitquick.admin.audit.AuditService;
import com.makeitquick.admin.common.ApiResponse;
import com.makeitquick.admin.common.NotFoundException;
import com.makeitquick.admin.common.PageResponse;
import jakarta.persistence.criteria.Predicate;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

@RestController
@RequestMapping("/api/v1/admin/support-requests")
public class AdminSupportController {

  private final SupportRepository support;
  private final AuditService audit;

  public AdminSupportController(SupportRepository support, AuditService audit) {
    this.support = support;
    this.audit = audit;
  }

  @GetMapping
  @PreAuthorize("hasAuthority('DISPUTES_READ')")
  public ApiResponse<PageResponse<SupportRequest>> list(
      @RequestParam(defaultValue = "") String status,
      @RequestParam(defaultValue = "") String category,
      @RequestParam(defaultValue = "") String query,
      @RequestParam(defaultValue = "0") @Min(0) int page,
      @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
    PageRequest pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "id"));
    Specification<SupportRequest> spec = (root, q, cb) -> {
      List<Predicate> ands = new ArrayList<>();
      if (!status.isBlank()) ands.add(cb.equal(root.get("status"), status));
      if (!category.isBlank()) ands.add(cb.equal(root.get("category"), category));
      if (!query.isBlank()) {
        String like = "%" + query.trim().toLowerCase() + "%";
        ands.add(cb.or(
            cb.like(cb.lower(root.get("subject")), like),
            cb.like(cb.lower(root.get("message")), like),
            cb.like(cb.lower(root.get("customerName")), like)));
      }
      return cb.and(ands.toArray(new Predicate[0]));
    };
    return ApiResponse.ok(PageResponse.from(support.findAll(spec, pageable)));
  }

  @GetMapping("/open-count")
  @PreAuthorize("hasAuthority('DISPUTES_READ')")
  public ApiResponse<Long> openCount() {
    return ApiResponse.ok(support.countByStatus("OPEN"));
  }

  @GetMapping("/{id}")
  @PreAuthorize("hasAuthority('DISPUTES_READ')")
  public ApiResponse<SupportRequest> get(@PathVariable long id) {
    return ApiResponse.ok(find(id));
  }

  @PostMapping
  @PreAuthorize("hasAuthority('DISPUTES_WRITE')")
  public ApiResponse<SupportRequest> create(@Valid @RequestBody Upsert body, HttpServletRequest req) {
    SupportRequest s = new SupportRequest();
    s.setCustomerId(body.customerId());
    s.setCustomerName(body.customerName());
    s.setSubject(body.subject().trim());
    s.setMessage(body.message().trim());
    s.setPriority(body.priority() == null ? "MEDIUM" : body.priority());
    s.setCategory(body.category() == null ? "SUPPORT" : body.category());
    SupportRequest saved = support.save(s);
    audit.record("SUPPORT_REQUEST_CREATED", "SUPPORT_REQUESTS", String.valueOf(saved.getId()), null,
        "{\"subject\":\"" + saved.getSubject() + "\"}", req);
    return ApiResponse.created(saved);
  }

  @PatchMapping("/{id}/status")
  @PreAuthorize("hasAuthority('DISPUTES_WRITE')")
  public ApiResponse<SupportRequest> changeStatus(@PathVariable long id, @Valid @RequestBody StatusChange input, HttpServletRequest req) {
    SupportRequest s = find(id);
    List<String> allowed = switch (s.getStatus()) {
      case "OPEN" -> List.of("IN_PROGRESS", "RESOLVED", "CLOSED");
      case "IN_PROGRESS" -> List.of("RESOLVED", "CLOSED");
      case "RESOLVED" -> List.of("CLOSED", "OPEN");
      case "CLOSED" -> List.of("OPEN");
      default -> List.of();
    };
    if (!allowed.contains(input.status())) {
      throw new IllegalArgumentException(
          "A " + s.getStatus() + " request can only transition to " + allowed + ", not " + input.status());
    }
    if ("RESOLVED".equals(input.status()) || "CLOSED".equals(input.status())) {
      s.setResolvedAt(Instant.now());
      if (input.reply() != null && !input.reply().isBlank()) {
        s.setAdminReply(input.reply().trim());
      }
    }
    s.setStatus(input.status());
    s.setUpdatedAt(Instant.now());
    SupportRequest saved = support.save(s);
    audit.record("SUPPORT_REQUEST_STATUS_CHANGED", "SUPPORT_REQUESTS", String.valueOf(id), null,
        "{\"status\":\"" + saved.getStatus() + "\"}", req);
    return ApiResponse.ok(saved);
  }

  @DeleteMapping("/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @PreAuthorize("hasAuthority('DISPUTES_WRITE')")
  public void delete(@PathVariable long id, HttpServletRequest req) {
    support.delete(find(id));
    audit.record("SUPPORT_REQUEST_DELETED", "SUPPORT_REQUESTS", String.valueOf(id), null, null, req);
  }

  private SupportRequest find(long id) {
    return support.findById(id).orElseThrow(() -> NotFoundException.of("SupportRequest", id));
  }

  public record Upsert(
      Long customerId,
      @Size(max = 160) String customerName,
      @NotBlank @Size(max = 200) String subject,
      @NotBlank @Size(max = 2000) String message,
      @Pattern(regexp = "LOW|MEDIUM|HIGH") String priority,
      @Pattern(regexp = "SUPPORT|BOOKING|PAYMENT|PARTNER|ACCOUNT|FEATURE") String category) {
  }

  public record StatusChange(
      @NotBlank @Pattern(regexp = "OPEN|IN_PROGRESS|RESOLVED|CLOSED") String status,
      @Size(max = 2000) String reply) {
  }
}
