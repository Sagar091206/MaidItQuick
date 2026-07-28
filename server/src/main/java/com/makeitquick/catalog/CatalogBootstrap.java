package com.makeitquick.catalog;

import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
class CatalogBootstrap {
    @Bean
    CommandLineRunner seedServices(ServiceItemRepository services) {
        return args -> {
            if (services.count() == 0) {
                services.save(new ServiceItem("Home cleaning", 14900));
                services.save(new ServiceItem("Dishwashing", 9900));
                services.save(new ServiceItem("Laundry & ironing", 11900));
            }
        };
    }
}
