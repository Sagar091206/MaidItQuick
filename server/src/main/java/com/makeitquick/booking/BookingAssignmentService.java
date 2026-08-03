package com.makeitquick.booking;

import com.makeitquick.notification.NotificationService;
import com.makeitquick.notification.NotificationType;
import com.makeitquick.operations.AvailabilityStatus;
import com.makeitquick.security.UserAccount;
import com.makeitquick.worker.WorkerProfile;
import com.makeitquick.worker.WorkerProfileRepository;
import java.time.Instant;
import java.util.Collection;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;

/**
 * Finds the best available worker for a booking.
 *
 * <p>Candidates must have an approved KYC pack, be marked available and be free
 * of other active jobs. Among them the nearest match is chosen using the
 * worker's declared work locations (PIN code match) and the most recent
 * location update as a proximity proxy; workers who cover every requested
 * service are preferred.</p>
 */
@Service
public class BookingAssignmentService {
    private static final Collection<BookingStatus> ACTIVE_STATUSES = List.of(
            BookingStatus.ASSIGNED,
            BookingStatus.ACCEPTED,
            BookingStatus.ON_THE_WAY,
            BookingStatus.ARRIVED,
            BookingStatus.IN_PROGRESS);

    private final WorkerProfileRepository profiles;
    private final BookingRepository bookings;

    BookingAssignmentService(WorkerProfileRepository profiles, BookingRepository bookings) {
        this.profiles = profiles;
        this.bookings = bookings;
    }

    public Optional<UserAccount> findBestWorker(List<String> services, String pinCode) {
        List<WorkerProfile> candidates = profiles.findAll().stream()
                .filter(WorkerProfile::isReadyForJobs)
                .filter(profile -> profile.getAvailability() == AvailabilityStatus.AVAILABLE)
                .filter(profile -> bookings.findByWorkerIdAndStatusIn(profile.getUser().getId(), ACTIVE_STATUSES).isEmpty())
                .filter(profile -> coversServices(profile, services))
                .sorted(Comparator
                        .comparingInt((WorkerProfile profile) -> coversLocation(profile, pinCode) ? 0 : 1)
                        .thenComparing(BookingAssignmentService::lastLocationUpdate, Comparator.reverseOrder())
                        .thenComparingLong(WorkerProfile::getId))
                .toList();
        if (candidates.isEmpty()) return Optional.empty();
        return Optional.of(candidates.get(0).getUser());
    }

    /**
     * Assigns the best available worker and notifies both sides.
     * Only runs while the booking is still unassigned (REQUESTED), so it can be
     * safely triggered after payment without double-assigning.
     */
    public Optional<UserAccount> assignBest(Booking b, List<String> services,
                                            NotificationService notifications) {
        if (b.getStatus() != BookingStatus.REQUESTED) return Optional.empty();
        Optional<UserAccount> best = findBestWorker(services, b.getPinCode());
        if (best.isEmpty()) return Optional.empty();
        UserAccount worker = best.get();
        b.assign(worker);
        bookings.save(b);
        notifications.sendBooking(worker, NotificationType.WORKER_ASSIGNMENT, "New booking request",
                "You have been assigned " + b.getService() + " for " + b.getScheduledFor() + ".", b.getId());
        notifications.send(b.getCustomer(), NotificationType.BOOKING, "Worker assigned",
                "A worker has been assigned to your " + b.getService() + " booking.");
        return best;
    }

    private boolean coversServices(WorkerProfile profile, List<String> services) {
        Set<String> tokens = tokens(profile.getServiceCategories());
        if (tokens.isEmpty()) return true;
        for (String service : services) {
            if (tokens.stream().noneMatch(token -> fuzzy(token, service))) return false;
        }
        return true;
    }

    private boolean coversLocation(WorkerProfile profile, String pinCode) {
        String locations = profile.getWorkLocations();
        if (locations == null || locations.isBlank()) return false;
        String normalized = locations.toLowerCase(Locale.ROOT);
        if (normalized.contains(pinCode)) return true;
        if (pinCode != null && pinCode.length() >= 3 && normalized.contains(pinCode.substring(0, 3))) return true;
        return false;
    }

    private static Instant lastLocationUpdate(WorkerProfile profile) {
        Instant updated = profile.getLocationUpdatedAt();
        return updated == null ? Instant.EPOCH : updated;
    }

    private static Set<String> tokens(String value) {
        if (value == null || value.isBlank()) return Set.of();
        return Set.of(value.toLowerCase(Locale.ROOT).split("[,/;]")).stream()
                .map(String::trim)
                .filter(token -> !token.isEmpty())
                .collect(Collectors.toSet());
    }

    private static boolean fuzzy(String token, String service) {
        String candidate = service.toLowerCase(Locale.ROOT);
        return token.equals(candidate)
                || token.contains(candidate)
                || candidate.contains(token);
    }
}
