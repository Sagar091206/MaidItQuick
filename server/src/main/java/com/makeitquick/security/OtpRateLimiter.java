package com.makeitquick.security;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

/**
 * In-memory sliding-window rate limiter used for OTP issuance.
 *
 * <p>Keeps a per-key deque of request timestamps and only admits requests that
 * fit inside the configured window. Old entries are pruned on access and by a
 * periodic sweep so the map cannot grow without bound. Single-instance
 * deployments are protected; a distributed deployment should back this with
 * Redis or an equivalent shared store.</p>
 */
@Service
public class OtpRateLimiter {
    private final Map<String, Deque<Instant>> hits = new ConcurrentHashMap<>();

    public synchronized boolean allow(String key, int max, Duration window) {
        Instant cutoff = Instant.now().minus(window);
        Deque<Instant> deque = hits.computeIfAbsent(key, k -> new ArrayDeque<>());
        while (!deque.isEmpty() && deque.peekFirst().isBefore(cutoff)) {
            deque.pollFirst();
        }
        if (deque.size() >= max) {
            return false;
        }
        deque.addLast(Instant.now());
        return true;
    }

    @Scheduled(fixedRate = 3_600_000)
    public synchronized void cleanup() {
        Instant cutoff = Instant.now().minus(Duration.ofHours(1));
        hits.entrySet().removeIf(entry -> {
            Deque<Instant> deque = entry.getValue();
            while (!deque.isEmpty() && deque.peekFirst().isBefore(cutoff)) {
                deque.pollFirst();
            }
            return deque.isEmpty();
        });
    }
}
