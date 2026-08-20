package com.makeitquick.catalog;

import com.makeitquick.security.Role;
import com.makeitquick.security.SessionResolver;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
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
    private final ServiceAreaOfferingRepository offerings;
    private final com.makeitquick.operations.ServiceAreaRepository areas;

    CatalogController(ServiceItemRepository services, SessionResolver resolver,
                      ServiceAreaOfferingRepository offerings, com.makeitquick.operations.ServiceAreaRepository areas) {
        this.services = services;
        this.resolver = resolver;
        this.offerings = offerings;
        this.areas = areas;
    }

    @GetMapping
    public List<Map<String, Object>> list(@RequestParam(required = false) String q,
                                          @RequestParam(required = false) String pinCode) {
        if (pinCode != null && !pinCode.isBlank()) {
            if (!pinCode.matches("\\d{6}")) throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"PIN code must have six digits");
            return offerings.findByServiceAreaPinCodeAndEnabledTrueOrderByServiceNameAsc(pinCode).stream()
                    .filter(o -> o.getServiceArea().isEnabled() && o.getService().isEnabled())
                    .filter(o -> q == null || q.isBlank() || o.getService().getName().toLowerCase().contains(q.trim().toLowerCase()))
                    .map(o -> serviceView(o.getService(), o.getPricePaise())).toList();
        }
        List<ServiceItem> items;
        if (q != null && !q.isBlank()) {
            items = services.findByEnabledTrueAndNameContainingIgnoreCaseOrderByNameAsc(q.trim());
        } else {
            items = services.findByEnabledTrueOrderByNameAsc();
        }
        return items.stream().map(this::serviceView).toList();
    }

    @GetMapping("/{id}")
    public Map<String, Object> detail(@PathVariable Long id,
                                      @RequestParam(required = false) String pinCode) {
        ServiceItem service = services.findByIdAndEnabledTrue(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Service not found"));
        if (pinCode != null && !pinCode.isBlank()) {
            if (!pinCode.matches("\\d{6}")) throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"PIN code must have six digits");
            ServiceAreaOffering offering = offerings.findByServiceAreaPinCodeAndServiceNameIgnoreCase(pinCode, service.getName())
                    .filter(ServiceAreaOffering::isEnabled)
                    .filter(item -> item.getServiceArea().isEnabled())
                    .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Service is not available in this PIN code"));
            return serviceView(service, offering.getPricePaise());
        }
        return serviceView(service);
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

    @PutMapping("/admin/{id}")
    public ServiceItem update(@RequestHeader(value="Authorization",required=false) String authorization,
                              @PathVariable Long id,@Valid @RequestBody UpdateServiceInput input){
        requireAdmin(authorization); ServiceItem item=services.findById(id).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Service not found"));
        item.setName(input.name().trim()); item.setPricePaise(input.priceRupees()*100); item.setDescription(input.description()); item.setDefaultDurationMinutes(input.defaultDurationMinutes()); item.setEnabled(input.enabled()); return services.save(item);
    }

    @GetMapping("/admin/{id}/areas")
    public List<Map<String,Object>> areaPrices(@RequestHeader(value="Authorization",required=false) String authorization,@PathVariable Long id){
        requireAdmin(authorization);
        ServiceItem service = services.findById(id).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Service not found"));
        Map<Long, ServiceAreaOffering> configured = new LinkedHashMap<>();
        offerings.findByServiceIdOrderByServiceAreaPinCodeAsc(id)
                .forEach(offering -> configured.put(offering.getServiceArea().getId(), offering));
        return areas.findAll().stream()
                .sorted(java.util.Comparator.comparing(com.makeitquick.operations.ServiceArea::getPinCode))
                .map(area -> {
                    ServiceAreaOffering offering = configured.get(area.getId());
                    if (offering != null) return offeringView(offering);
                    Map<String,Object> view = new LinkedHashMap<>();
                    view.put("id", null); view.put("serviceId", service.getId()); view.put("areaId", area.getId());
                    view.put("pinCode", area.getPinCode()); view.put("locality", area.getLocality());
                    view.put("pricePaise", service.getPricePaise()); view.put("enabled", false);
                    return view;
                }).toList();
    }

    @PutMapping("/admin/{serviceId}/areas/{areaId}")
    public Map<String,Object> setAreaPrice(@RequestHeader(value="Authorization",required=false) String authorization,@PathVariable Long serviceId,@PathVariable Long areaId,@Valid @RequestBody OfferingInput input){
        requireAdmin(authorization); var service=services.findById(serviceId).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Service not found")); var area=areas.findById(areaId).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Service area not found"));
        var offering=offerings.findByServiceAreaIdAndServiceId(areaId,serviceId).orElseGet(()->new ServiceAreaOffering(area,service,input.priceRupees()*100)); offering.update(input.priceRupees()*100,input.enabled()); return offeringView(offerings.save(offering));
    }

    /** Customer-facing view of a catalog item (additive keys only). */
    Map<String, Object> serviceView(ServiceItem service) {
        return serviceView(service, service.getPricePaise());
    }
    Map<String,Object> serviceView(ServiceItem service,int pricePaise) {
        Map<String, Object> view = new LinkedHashMap<>();
        view.put("id", service.getId());
        view.put("name", service.getName());
        view.put("pricePaise", pricePaise);
        view.put("description", service.getDescription());
        view.put("emoji", service.getEmoji());
        view.put("defaultDurationMinutes", service.getDefaultDurationMinutes());
        view.put("enabled", service.isEnabled());
        return view;
    }
    private Map<String,Object> offeringView(ServiceAreaOffering o){Map<String,Object> v=new LinkedHashMap<>();v.put("id",o.getId());v.put("serviceId",o.getService().getId());v.put("areaId",o.getServiceArea().getId());v.put("pinCode",o.getServiceArea().getPinCode());v.put("locality",o.getServiceArea().getLocality());v.put("pricePaise",o.getPricePaise());v.put("enabled",o.isEnabled());return v;}

    private void requireAdmin(String authorization) {
        Role role = resolver.fromBearer(authorization).map(user -> user.getRole())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Please sign in"));
        if (role != Role.ADMIN) throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Admin access required");
    }

    record ServiceInput(@NotBlank String name, @Min(1) int priceRupees) {}
    record EnabledInput(boolean enabled) {}
    record UpdateServiceInput(@NotBlank String name,@Min(1) int priceRupees,String description,@Min(1) int defaultDurationMinutes,boolean enabled){}
    record OfferingInput(@Min(1) int priceRupees,boolean enabled){}
}
