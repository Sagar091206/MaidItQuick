package com.makeitquick.operations;

import com.makeitquick.worker.WorkerSafetyService;
import jakarta.validation.constraints.Pattern;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/availability")
public class AvailabilityController {
    private final ServiceAreaService serviceAreas;
    private final WorkerSafetyService workers;

    AvailabilityController(ServiceAreaService serviceAreas, WorkerSafetyService workers) {
        this.serviceAreas = serviceAreas;
        this.workers = workers;
    }

    @GetMapping
    public Map<String, Object> check(@RequestParam @Pattern(regexp = "\\d{6}") String pinCode) {
        if (!serviceAreas.acceptsBookings(pinCode)) {
            return Map.of("status", "NOT_AVAILABLE", "label", "Not available today",
                    "message", "We do not serve this PIN code yet.");
        }
        if (workers.eligibleAvailableWorkerCount() > 0) {
            return Map.of("status", "AVAILABLE_NOW", "label", "Available now", "etaMinutes", 20,
                    "message", "An approved local expert can be assigned in about 20 minutes.");
        }
        return Map.of("status", "AVAILABLE_LATER", "label", "Available in 1 hour", "etaMinutes", 60,
                "message", "This area is open; the next expert is expected within about an hour.");
    }
}
