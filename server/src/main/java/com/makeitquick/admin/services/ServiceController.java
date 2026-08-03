package com.makeitquick.admin.services;

import com.makeitquick.admin.audit.AuditService;
import com.makeitquick.admin.categories.Category;
import com.makeitquick.admin.categories.CategoryRepository;
import com.makeitquick.admin.common.ApiResponse;
import com.makeitquick.admin.common.NotFoundException;
import com.makeitquick.admin.common.PageResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;

@RestController
@RequestMapping("/api/v1/admin/services")
public class ServiceController {

  private final ServiceOfferingRepository services;
  private final CategoryRepository categories;
  private final AuditService audit;

  public ServiceController(ServiceOfferingRepository services, CategoryRepository categories, AuditService audit) {
    this.services = services;
    this.categories = categories;
    this.audit = audit;
  }

  @GetMapping
  @PreAuthorize("hasAuthority('SERVICES_READ')")
  public ApiResponse<PageResponse<ServiceOffering>> list(
      @RequestParam(defaultValue = "") String query,
      @RequestParam(defaultValue = "0") @Min(0) int page,
      @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
    PageRequest pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "id"));
    var result = query.isBlank()
        ? services.findAll(pageable)
        : services.findByNameContainingIgnoreCaseOrDescriptionContainingIgnoreCase(query, query, pageable);
    return ApiResponse.ok(PageResponse.from(result));
  }

  @GetMapping("/{id}")
  @PreAuthorize("hasAuthority('SERVICES_READ')")
  public ApiResponse<ServiceOffering> get(@PathVariable long id) {
    return ApiResponse.ok(find(id));
  }

  @PostMapping
  @PreAuthorize("hasAuthority('SERVICES_WRITE')")
  public ApiResponse<ServiceOffering> create(@Valid @RequestBody Upsert body, HttpServletRequest req) {
    if (services.existsByNameIgnoreCase(body.name().trim())) {
      throw new IllegalArgumentException("A service with this name already exists");
    }
    ServiceOffering s = new ServiceOffering();
    s.setName(body.name().trim());
    s.setDescription(body.description());
    s.setCategory(resolveCategory(body.categoryId()));
    s.setPrice(body.price());
    s.setDurationMinutes(body.durationMinutes());
    s.setActive(body.active() == null || body.active());
    ServiceOffering saved = services.save(s);
    audit.record("SERVICE_CREATED", "SERVICES", String.valueOf(saved.getId()), null,
        "{\"name\":\"" + saved.getName() + "\"}", req);
    return ApiResponse.created(saved);
  }

  @PutMapping("/{id}")
  @PreAuthorize("hasAuthority('SERVICES_WRITE')")
  public ApiResponse<ServiceOffering> update(@PathVariable long id, @Valid @RequestBody Upsert body, HttpServletRequest req) {
    ServiceOffering s = find(id);
    if (services.existsByNameIgnoreCaseAndIdNot(body.name().trim(), id)) {
      throw new IllegalArgumentException("A service with this name already exists");
    }
    s.setName(body.name().trim());
    s.setDescription(body.description());
    s.setCategory(resolveCategory(body.categoryId()));
    s.setPrice(body.price());
    s.setDurationMinutes(body.durationMinutes());
    if (body.active() != null) {
      s.setActive(body.active());
    }
    ServiceOffering saved = services.save(s);
    audit.record("SERVICE_UPDATED", "SERVICES", String.valueOf(id), null,
        "{\"name\":\"" + saved.getName() + "\"}", req);
    return ApiResponse.ok(saved);
  }

  @DeleteMapping("/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @PreAuthorize("hasAuthority('SERVICES_WRITE')")
  public void delete(@PathVariable long id, HttpServletRequest req) {
    services.delete(find(id));
    audit.record("SERVICE_DELETED", "SERVICES", String.valueOf(id), null, null, req);
  }

  private ServiceOffering find(long id) {
    return services.findById(id).orElseThrow(() -> NotFoundException.of("Service", id));
  }

  private Category resolveCategory(Long id) {
    if (id == null) {
      return null;
    }
    return categories.findById(id).orElseThrow(() -> NotFoundException.of("Category", id));
  }

  public record Upsert(
      @NotBlank @Size(max = 160) String name,
      @Size(max = 1000) String description,
      Long categoryId,
      @NotNull @DecimalMin("0.0") BigDecimal price,
      @Min(1) @Max(1440) Integer durationMinutes,
      Boolean active) {
  }
}
