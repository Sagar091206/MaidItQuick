package com.makeitquick.admin.promo;

import com.makeitquick.admin.audit.AuditService;
import com.makeitquick.admin.common.ApiResponse;
import com.makeitquick.admin.common.NotFoundException;
import com.makeitquick.promo.PromoCode;
import com.makeitquick.promo.PromoCodeRepository;
import com.makeitquick.promo.PromotionService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/admin/promos")
public class AdminPromoController {

    private final PromoCodeRepository promoCodes;
    private final PromotionService promotionService;
    private final AuditService audit;

    public AdminPromoController(PromoCodeRepository promoCodes, PromotionService promotionService, AuditService audit) {
        this.promoCodes = promoCodes;
        this.promotionService = promotionService;
        this.audit = audit;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('SETTINGS_READ')")
    public ApiResponse<List<PromoCode>> list() {
        return ApiResponse.ok(promoCodes.findAllByOrderByCreatedAtDesc());
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAuthority('SETTINGS_READ')")
    public ApiResponse<PromoCode> get(@PathVariable long id) {
        return ApiResponse.ok(find(id));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAuthority('SETTINGS_WRITE')")
    public ApiResponse<PromoCode> create(@Valid @RequestBody PromoUpsert body, HttpServletRequest req) {
        String normalizedCode = body.code().trim().toUpperCase();
        if (promoCodes.existsByCodeIgnoreCase(normalizedCode)) {
            throw new IllegalArgumentException("A promo code with this code already exists");
        }
        PromoCode p = new PromoCode();
        p.setCode(normalizedCode);
        p.setDiscountPercentage(body.discountPercentage());
        p.setEnabled(body.enabled() == null || body.enabled());
        p.setDescription(body.description());
        p.setCreatedAt(Instant.now());
        PromoCode saved = promoCodes.save(p);
        audit.record("PROMO_CREATED", "PROMOTIONS", String.valueOf(saved.getId()), null,
                "{\"code\":\"" + saved.getCode() + "\",\"discountPercentage\":" + saved.getDiscountPercentage() + "}", req);
        return ApiResponse.created(saved);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('SETTINGS_WRITE')")
    public ApiResponse<PromoCode> update(@PathVariable long id, @Valid @RequestBody PromoUpsert body, HttpServletRequest req) {
        PromoCode p = find(id);
        String normalizedCode = body.code().trim().toUpperCase();
        if (promoCodes.existsByCodeIgnoreCaseAndIdNot(normalizedCode, id)) {
            throw new IllegalArgumentException("A promo code with this code already exists");
        }
        p.setCode(normalizedCode);
        p.setDiscountPercentage(body.discountPercentage());
        if (body.enabled() != null) {
            p.setEnabled(body.enabled());
        }
        p.setDescription(body.description());
        p.setUpdatedAt(Instant.now());
        PromoCode saved = promoCodes.save(p);
        audit.record("PROMO_UPDATED", "PROMOTIONS", String.valueOf(id), null,
                "{\"code\":\"" + saved.getCode() + "\",\"discountPercentage\":" + saved.getDiscountPercentage() + "}", req);
        return ApiResponse.ok(saved);
    }

    @PatchMapping("/{id}/toggle")
    @PreAuthorize("hasAuthority('SETTINGS_WRITE')")
    public ApiResponse<PromoCode> toggleStatus(@PathVariable long id, HttpServletRequest req) {
        PromoCode p = find(id);
        p.setEnabled(!p.isEnabled());
        p.setUpdatedAt(Instant.now());
        PromoCode saved = promoCodes.save(p);
        audit.record("PROMO_TOGGLED", "PROMOTIONS", String.valueOf(id), null,
                "{\"code\":\"" + saved.getCode() + "\",\"enabled\":" + saved.isEnabled() + "}", req);
        return ApiResponse.ok(saved);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasAuthority('SETTINGS_WRITE')")
    public void delete(@PathVariable long id, HttpServletRequest req) {
        PromoCode p = find(id);
        promoCodes.delete(p);
        audit.record("PROMO_DELETED", "PROMOTIONS", String.valueOf(id), null, "{\"code\":\"" + p.getCode() + "\"}", req);
    }

    @GetMapping("/first-order")
    @PreAuthorize("hasAuthority('SETTINGS_READ')")
    public ApiResponse<Map<String, Object>> getFirstOrderDiscount() {
        int percentage = promotionService.getFirstOrderDiscountPercentage();
        return ApiResponse.ok(Map.of("percentage", percentage));
    }

    @PutMapping("/first-order")
    @PreAuthorize("hasAuthority('SETTINGS_WRITE')")
    public ApiResponse<Map<String, Object>> updateFirstOrderDiscount(
            @Valid @RequestBody FirstOrderDiscountUpsert body, HttpServletRequest req) {
        promotionService.setFirstOrderDiscountPercentage(body.percentage());
        audit.record("FIRST_ORDER_DISCOUNT_UPDATED", "SETTINGS", "FIRST_ORDER_DISCOUNT_PCT", null,
                "{\"percentage\":" + body.percentage() + "}", req);
        return ApiResponse.ok(Map.of("percentage", body.percentage()));
    }

    private PromoCode find(long id) {
        return promoCodes.findById(id).orElseThrow(() -> NotFoundException.of("PromoCode", id));
    }

    public record PromoUpsert(
            @NotBlank @Size(max = 50) String code,
            @Min(1) @Max(100) int discountPercentage,
            Boolean enabled,
            @Size(max = 255) String description) {
    }

    public record FirstOrderDiscountUpsert(
            @Min(0) @Max(100) int percentage) {
    }
}
