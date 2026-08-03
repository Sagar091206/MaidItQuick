package com.makeitquick.security;

import com.makeitquick.booking.Booking;
import com.makeitquick.booking.BookingRepository;
import com.makeitquick.worker.WorkerProfile;
import com.makeitquick.worker.WorkerProfileRepository;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

/** Read-only administration views over the same MySQL domain model used by mobile clients. */
@RestController
@RequestMapping("/api/admin/dashboard")
@CrossOrigin(origins = {"http://localhost:5173", "http://127.0.0.1:5173"})
public class AdminDashboardController {
    private final UserRepository users;
    private final WorkerProfileRepository workers;
    private final BookingRepository bookings;
    private final SessionRepository sessions;

    AdminDashboardController(UserRepository users, WorkerProfileRepository workers,
            BookingRepository bookings, SessionRepository sessions) {
        this.users = users;
        this.workers = workers;
        this.bookings = bookings;
        this.sessions = sessions;
    }

    @GetMapping("/summary")
    public Map<String, Object> summary(@RequestHeader(value = "Authorization", required = false) String authorization) {
        requireAdmin(authorization);
        List<Booking> allBookings = bookings.findAll();
        long activeUsers = users.findAll().stream().filter(UserAccount::isEnabled).count();
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("totalUsers", activeUsers);
        result.put("totalWorkers", workers.count());
        result.put("totalBookings", allBookings.size());
        result.put("requestedBookings", allBookings.stream().filter(b -> "REQUESTED".equals(b.getStatus().name())).count());
        result.put("activeBookings", allBookings.stream().filter(b -> "ASSIGNED".equals(b.getStatus().name()) || "ON_THE_WAY".equals(b.getStatus().name()) || "IN_PROGRESS".equals(b.getStatus().name())).count());
        result.put("completedBookings", allBookings.stream().filter(b -> "COMPLETED".equals(b.getStatus().name())).count());
        return result;
    }

    private void requireAdmin(String authorization) {
        String token = authorization == null ? "" : authorization.replaceFirst("(?i)^Bearer\\s+", "");
        Role role = sessions.findByToken(token).filter(Session::valid).map(session -> session.getUser().getRole())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Please sign in"));
        if (role != Role.ADMIN) throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Admin access required");
    }
}
