package com.makeitquick.booking;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Map;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/booking")
@CrossOrigin(origins = "*")
public class BookingPlanningController {
    private static final List<LocalTime> SLOTS = List.of(
            LocalTime.of(8, 0),
            LocalTime.of(10, 0),
            LocalTime.of(12, 0),
            LocalTime.of(14, 0),
            LocalTime.of(16, 0),
            LocalTime.of(18, 0));

    @GetMapping("/slots")
    public List<Map<String, Object>> slots(
            @RequestParam @Pattern(regexp = "\\d{6}") String pinCode,
            @RequestParam(required = false) String date) {
        LocalDate selectedDate = date == null || date.isBlank() ? LocalDate.now() : LocalDate.parse(date);
        LocalDate today = LocalDate.now();
        LocalTime now = LocalTime.now();
        return SLOTS.stream()
                .map(slot -> Map.<String, Object>of(
                        "time", slot.toString(),
                        "available", selectedDate.isAfter(today) || (selectedDate.isEqual(today) && slot.isAfter(now)),
                        "pinCode", pinCode))
                .toList();
    }

    @PostMapping("/calculate-duration")
    public Map<String, Object> calculateDuration(@Valid @RequestBody DurationInput input) {
        List<String> services = input.services() == null ? List.of() : input.services();
        int count = services.stream().filter(service -> service != null && !service.isBlank()).toList().size();
        int minutes = Math.max(1, count) * 60;
        return Map.of("durationMinutes", minutes, "serviceCount", count);
    }

    record DurationInput(List<@NotBlank String> services) {}
}
