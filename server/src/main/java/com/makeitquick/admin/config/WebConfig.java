package com.makeitquick.admin.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.nio.file.Path;
import java.nio.file.Paths;

@Configuration
public class WebConfig implements WebMvcConfigurer {

  private final String uploadsDir;

  public WebConfig(@Value("${app.uploads-dir:uploads}") String uploadsDir) {
    this.uploadsDir = uploadsDir;
  }

  @Override
  public void addResourceHandlers(ResourceHandlerRegistry registry) {
    Path base = Paths.get(uploadsDir).toAbsolutePath().normalize();
    registry.addResourceHandler("/uploads/**")
        .addResourceLocations("file:" + base + "/");
  }
}
