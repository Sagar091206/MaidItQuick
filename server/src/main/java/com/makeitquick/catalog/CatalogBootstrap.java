package com.makeitquick.catalog;

import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
class CatalogBootstrap {
    private record Seed(String name, String priceRupees, String emoji, String description, int defaultDurationMinutes) {}

    private static final Seed[] PRD_SERVICES = {
            new Seed("Bathroom Cleaning", "799", "🛁",
                    "Deep cleaning of sinks, taps, mirrors, tiles and WC using the supplies you provide at home.", 60),
            new Seed("Kitchen Cleaning", "899", "🍳",
                    "Degreasing of the hob, chimney, countertops, sink and cabinets using the supplies you provide at home.", 90),
            new Seed("Bedroom Cleaning", "699", "🛏️",
                    "Bed-making, dusting of furniture and fixtures, and floor care for the bedrooms.", 60),
            new Seed("Balcony Cleaning", "599", "🪴",
                    "Sweeping, mopping and dusting of the balcony area with the supplies you provide at home.", 45),
            new Seed("Living Room Cleaning", "799", "🛋️",
                    "Full dusting, sofa and floor care for the living room using the supplies you provide at home.", 60),
    };

    @Bean
    CommandLineRunner seedServices(ServiceItemRepository services) {
        return args -> {
            for (Seed entry : PRD_SERVICES) {
                services.findByNameIgnoreCase(entry.name()).orElseGet(() -> {
                    ServiceItem item = new ServiceItem(entry.name(), Integer.parseInt(entry.priceRupees()) * 100);
                    item.setEmoji(entry.emoji());
                    item.setDescription(entry.description());
                    item.setDefaultDurationMinutes(entry.defaultDurationMinutes());
                    return services.save(item);
                });
            }
        };
    }
}
