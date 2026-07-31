package com.makeitquick.security;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

/** Admin-only operations deliberately live with the shared MySQL user model. */
@RestController
@RequestMapping("/api/admin/users")
@CrossOrigin(origins = {"http://localhost:5173", "http://127.0.0.1:5173"})
public class AdminUserController {
    private final UserRepository users;
    private final SessionRepository sessions;

    AdminUserController(UserRepository users, SessionRepository sessions) {
        this.users = users;
        this.sessions = sessions;
    }

    @GetMapping
    public Map<String, Object> list(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @RequestParam(defaultValue = "") String query) {
        requireAdmin(authorization);
        String match = query.trim().toLowerCase();
        List<Map<String, Object>> items = users.findAllByOrderByIdDesc().stream()
                .filter(user -> match.isEmpty() || user.getName().toLowerCase().contains(match)
                        || user.getEmail().toLowerCase().contains(match))
                .map(user -> Map.<String, Object>of(
                        "id", user.getId(), "name", user.getName(), "email", user.getEmail(),
                        "role", user.getRole().name(), "status", user.isEnabled() ? "ACTIVE" : "SUSPENDED",
                        "createdAt", user.getCreatedAt()))
                .toList();
        return Map.of("items", items, "total", items.size());
    }

    @PatchMapping("/{id}/status")
    public Map<String, Object> changeStatus(@PathVariable long id,
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @Valid @RequestBody StatusChange input) {
        requireAdmin(authorization);
        UserAccount user = users.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));
        user.setEnabled(input.enabled());
        users.save(user);
        return Map.of("id", user.getId(), "status", user.isEnabled() ? "ACTIVE" : "SUSPENDED");
    }

    private void requireAdmin(String authorization) {
        String token = authorization == null ? "" : authorization.replaceFirst("(?i)^Bearer\\s+", "");
        Role role = sessions.findByToken(token).filter(Session::valid).map(session -> session.getUser().getRole())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Please sign in"));
        if (role != Role.ADMIN) throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Admin access required");
    }

    public record StatusChange(@NotNull Boolean enabled) {}
}
