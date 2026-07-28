package com.makeitquick;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/** Serves the local frontend during development at /app/. Deploy static files separately in production. */
@Configuration
public class FrontendPreviewConfig implements WebMvcConfigurer {
    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        registry.addResourceHandler("/app/**")
                .addResourceLocations("file:../outputs/makeitquick-mvp/");
    }
}
