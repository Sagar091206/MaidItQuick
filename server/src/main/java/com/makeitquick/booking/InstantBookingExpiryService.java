package com.makeitquick.booking;

import com.makeitquick.notification.NotificationService;
import com.makeitquick.notification.NotificationType;
import java.time.Instant;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Closes unaccepted Instant Maid requests even when no app is polling them. */
@Service
public class InstantBookingExpiryService {
    private final BookingRepository bookings;
    private final NotificationService notifications;

    InstantBookingExpiryService(BookingRepository bookings, NotificationService notifications) {
        this.bookings = bookings;
        this.notifications = notifications;
    }

    @Scheduled(fixedDelay = 30000)
    @Transactional
    public void expireStaleRequests() {
        Instant now = Instant.now();
        for (Booking booking : bookings.findByStatusOrderByIdDesc(BookingStatus.SEARCHING)) {
            if (booking.getExpiresAt() == null || now.isBefore(booking.getExpiresAt())) continue;
            booking.expire();
            notifications.send(booking.getCustomer(), NotificationType.BOOKING,
                    "No partner found",
                    "We could not find an available partner for your Instant Maid request. Please try again shortly.");
        }
    }
}