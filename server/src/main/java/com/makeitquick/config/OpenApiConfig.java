package com.makeitquick.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {
    private static final String SESSION_AUTH = "sessionAuth";

    @Bean
    OpenAPI maidItQuickOpenApi() {
        return new OpenAPI()
                .info(new Info()
                        .title("MaidItQuick API")
                        .version("v1")
                        .description("Backend API for MaidItQuick home services."))
                .components(new Components().addSecuritySchemes(
                        SESSION_AUTH,
                        new SecurityScheme()
                                .type(SecurityScheme.Type.HTTP)
                                .scheme("bearer")
                                .bearerFormat("Opaque session token")))
                .addSecurityItem(new SecurityRequirement().addList(SESSION_AUTH));
    }
}
