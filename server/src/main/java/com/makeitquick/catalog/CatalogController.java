package com.makeitquick.catalog;

import com.makeitquick.security.Role;
import com.makeitquick.security.SessionResolver;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/services")
public class CatalogController {
    private final ServiceItemRepository services;
    private final SessionResolver resolver;

    CatalogController(ServiceItemRepository services, SessionResolver resolver) {
        this.services = services;
        this.resolver = resolver;
    }

    @GetMapping
    public List<ServiceItem> list(@RequestParam(required = false) String q) {
        if (q != null && !q.isBlank()) {
            return services.findByEnabledTrueAndNameContainingIgnoreCaseOrderByNameAsc(q.trim());
        }
        return services.findByEnabledTrueOrderByNameAsc();
    }

    @GetMapping("/admin")
    public List<ServiceItem> listForAdmin(@RequestHeader(value = "Authorization", required = false) String authorization) {
        requireAdmin(authorization);
        return services.findAll();
    }

    @PostMapping
    public ServiceItem add(@RequestHeader(value = "Authorization", required = false) String authorization,
                           @Valid @RequestBody ServiceInput input) {
        requireAdmin(authorization);
        String name = input.name().trim();
        if (services.findByNameIgnoreCase(name).isPresent()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Service already exists");
        }
        return services.save(new ServiceItem(name, input.priceRupees() * 100));
    }

    @PostMapping("/{id}/enabled")
    public ServiceItem setEnabled(@RequestHeader(value = "Authorization", required = false) String authorization,
                                  @PathVariable Long id, @RequestBody EnabledInput input) {
        requireAdmin(authorization);
        ServiceItem service = services.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Service not found"));
        service.setEnabled(input.enabled());
        return services.save(service);
    }

    private void requireAdmin(String authorization) {
        Role role = resolver.fromBearer(authorization).map(user -> user.getRole())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Please sign in"));
        if (role != Role.ADMIN) throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Admin access required");
    }

    record ServiceInput(@NotBlank String name, @Min(1) int priceRupees) {}
    record EnabledInput(boolean enabled) {}
}
