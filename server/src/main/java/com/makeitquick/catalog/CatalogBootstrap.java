package com.makeitquick.catalog;

import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
class CatalogBootstrap {
    private static final String[][] PRD_SERVICES = {
            {"Bathroom Cleaning", "799"},
            {"Kitchen Cleaning", "899"},
            {"Bedroom Cleaning", "699"},
            {"Balcony Cleaning", "599"},
            {"Living Room Cleaning", "799"},
    };

    @Bean
    CommandLineRunner seedServices(ServiceItemRepository services) {
        return args -> {
            for (String[] entry : PRD_SERVICES) {
                String name = entry[0];
                int pricePaise = Integer.parseInt(entry[1]) * 100;
                services.findByNameIgnoreCase(name).orElseGet(() -> services.save(new ServiceItem(name, pricePaise)));
            }
        };
    }
}
