package com.makeitquick.admin.categories;

import com.makeitquick.admin.audit.AuditService;
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

import java.util.List;
import java.util.Locale;

@RestController
@RequestMapping("/api/v1/admin/categories")
public class CategoryController {

  private final CategoryRepository categories;
  private final AuditService audit;

  public CategoryController(CategoryRepository categories, AuditService audit) {
    this.categories = categories;
    this.audit = audit;
  }

  @GetMapping
  @PreAuthorize("hasAuthority('CATEGORIES_READ')")
  public ApiResponse<PageResponse<Category>> list(
      @RequestParam(defaultValue = "") String query,
      @RequestParam(defaultValue = "0") @Min(0) int page,
      @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
    PageRequest pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.ASC, "name"));
    var result = query.isBlank()
        ? categories.findAll(pageable)
        : categories.findByNameContainingIgnoreCaseOrDescriptionContainingIgnoreCase(query, query, pageable);
    return ApiResponse.ok(PageResponse.from(result));
  }

  @GetMapping("/all")
  @PreAuthorize("hasAuthority('CATEGORIES_READ')")
  public ApiResponse<List<Category>> all() {
    return ApiResponse.ok(categories.findAll(Sort.by("name")));
  }

  @GetMapping("/{id}")
  @PreAuthorize("hasAuthority('CATEGORIES_READ')")
  public ApiResponse<Category> get(@PathVariable long id) {
    return ApiResponse.ok(find(id));
  }

  @PostMapping
  @PreAuthorize("hasAuthority('CATEGORIES_WRITE')")
  public ApiResponse<Category> create(@Valid @RequestBody Upsert body, HttpServletRequest req) {
    if (categories.existsByNameIgnoreCase(body.name().trim())) {
      throw new IllegalArgumentException("A category with this name already exists");
    }
    Category c = new Category();
    c.setName(body.name().trim());
    c.setSlug(slugify(body.name()));
    c.setDescription(body.description());
    c.setActive(body.active() == null || body.active());
    Category saved = categories.save(c);
    audit.record("CATEGORY_CREATED", "CATEGORIES", String.valueOf(saved.getId()), null,
        "{\"name\":\"" + saved.getName() + "\"}", req);
    return ApiResponse.created(saved);
  }

  @PutMapping("/{id}")
  @PreAuthorize("hasAuthority('CATEGORIES_WRITE')")
  public ApiResponse<Category> update(@PathVariable long id, @Valid @RequestBody Upsert body, HttpServletRequest req) {
    Category c = find(id);
    if (categories.existsByNameIgnoreCaseAndIdNot(body.name().trim(), id)) {
      throw new IllegalArgumentException("A category with this name already exists");
    }
    c.setName(body.name().trim());
    c.setSlug(slugify(body.name()));
    c.setDescription(body.description());
    if (body.active() != null) {
      c.setActive(body.active());
    }
    Category saved = categories.save(c);
    audit.record("CATEGORY_UPDATED", "CATEGORIES", String.valueOf(id), null,
        "{\"name\":\"" + saved.getName() + "\"}", req);
    return ApiResponse.ok(saved);
  }

  @DeleteMapping("/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @PreAuthorize("hasAuthority('CATEGORIES_WRITE')")
  public void delete(@PathVariable long id, HttpServletRequest req) {
    Category c = find(id);
    categories.delete(c);
    audit.record("CATEGORY_DELETED", "CATEGORIES", String.valueOf(id), null, null, req);
  }

  private Category find(long id) {
    return categories.findById(id).orElseThrow(() -> NotFoundException.of("Category", id));
  }

  static String slugify(String name) {
    return name.trim().toLowerCase(Locale.ROOT)
        .replaceAll("[^a-z0-9]+", "-")
        .replaceAll("(^-|-$)", "");
  }

  public record Upsert(
      @NotBlank @Size(max = 120) String name,
      @Size(max = 500) String description,
      Boolean active) {
  }
}
