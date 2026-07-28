package com.makeitquick.catalog;

import org.springframework.stereotype.Service;

@Service
public class ServiceCatalogService {
    private final ServiceItemRepository services;

    ServiceCatalogService(ServiceItemRepository services) {
        this.services = services;
    }

    public boolean isEnabled(String serviceName) {
        return services.findByNameIgnoreCase(serviceName == null ? "" : serviceName.trim())
                .map(ServiceItem::isEnabled)
                .orElse(false);
    }
}
