package com.makeitquick.security;

import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/admin/users")
public class AdminUserController {
    private final UserRepository users;
    private final SessionRepository sessions;

    AdminUserController(UserRepository users, SessionRepository sessions) {
        this.users = users;
        this.sessions = sessions;
    }

    @GetMapping
    public List<Map<String, Object>> list(@RequestHeader(value = "Authorization", required = false) String authorization) {
        requireAdmin(authorization);
        return users.findAllByOrderByIdDesc().stream().map(user -> Map.<String, Object>of(
                "id", user.getId(), "name", user.getName(), "email", user.getEmail(),
                "role", user.getRole(), "enabled", user.isEnabled())).toList();
    }

    private void requireAdmin(String authorization) {
        String token = authorization == null ? "" : authorization.replaceFirst("(?i)^Bearer\\s+", "");
        Role role = sessions.findByToken(token).filter(Session::valid).map(session -> session.getUser().getRole())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Please sign in"));
        if (role != Role.ADMIN) throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Admin access required");
    }
}
