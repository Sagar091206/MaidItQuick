package com.makeitquick.booking;

import com.makeitquick.notification.NotificationService;
import com.makeitquick.notification.NotificationType;
import com.makeitquick.security.UserAccount;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Releases pending scheduled requests when a partner goes offline. */
@Service
public class PartnerAvailabilityBookingService {
    private final BookingRepository bookings;
    private final BookingServiceRepository bookingServices;
    private final BookingEventRepository bookingEvents;
    private final BookingAssignmentService assigner;
    private final NotificationService notifications;

    PartnerAvailabilityBookingService(
            BookingRepository bookings,
            BookingServiceRepository bookingServices,
            BookingEventRepository bookingEvents,
            BookingAssignmentService assigner,
            NotificationService notifications) {
        this.bookings = bookings;
        this.bookingServices = bookingServices;
        this.bookingEvents = bookingEvents;
        this.assigner = assigner;
        this.notifications = notifications;
    }

    @Transactional
    public void releasePendingScheduledRequests(UserAccount worker) {
        List<Booking> pending = bookings.findByWorkerIdAndStatusIn(
                worker.getId(), List.of(BookingStatus.ASSIGNED));
        for (Booking candidate : pending) {
            Booking booking = bookings.findByIdForUpdate(candidate.getId()).orElse(null);
            if (booking == null || booking.isInstantBooking()
                    || booking.getStatus() != BookingStatus.ASSIGNED
                    || booking.getWorker() == null
                    || !booking.getWorker().getId().equals(worker.getId())) {
                continue;
            }

            notifications.removeBookingNotifications(worker, booking.getId());
            booking.unassign();
            bookings.save(booking);
            bookingEvents.save(new BookingEvent(
                    booking, BookingStatus.REQUESTED,
                    "Partner " + worker.getName() + " went offline; finding another partner"));
            notifications.sendBooking(
                    booking.getCustomer(), NotificationType.BOOKING, "Finding another partner",
                    "The assigned partner went offline. We are sending your request to another available partner.",
                    booking.getId());

            List<String> services = bookingServices.findByBookingIdOrderByIdAsc(booking.getId()).stream()
                    .map(BookingService::getServiceName)
                    .toList();
            assigner.assignBest(booking, services, notifications).ifPresent(reassigned ->
                    bookingEvents.save(new BookingEvent(
                            booking, BookingStatus.ASSIGNED, "Assigned to " + reassigned.getName())));
        }
    }
}
