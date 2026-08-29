package com.makeitquick.operations;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;

/**
 * Sets up the first MaidItQuick launch locality for local MVP demonstrations.
 * Disable it in a production environment with APP_LAUNCH_SEED_DEFAULT_AREA=false.
 */
@Configuration
public class MvpLaunchAreaBootstrap {
    @Bean
    @Order(20)
    CommandLineRunner seedLaunchArea(
            ServiceAreaRepository areas,
            @Value("${app.launch.seed-default-area:true}") boolean seedDefaultArea,
            @Value("${app.launch.default-pin:712235}") String pinCode,
            @Value("${app.launch.default-locality:Konnagar, Hooghly}") String locality) {
        return args -> {
            if (seedDefaultArea && areas.findByPinCode(pinCode).isEmpty()) {
                areas.save(new ServiceArea(pinCode, locality));
            }
        };
    }
}
