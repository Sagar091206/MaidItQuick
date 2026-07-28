package com.makeitquick;

import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** A small unauthenticated status endpoint used by health checks. */
@RestController
@RequestMapping("/api")
public class ApiController {
    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "ok", "service", "maiditquick-api");
    }
}
