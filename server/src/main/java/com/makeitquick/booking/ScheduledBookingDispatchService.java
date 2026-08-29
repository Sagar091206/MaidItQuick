package com.makeitquick.booking;

import com.makeitquick.notification.NotificationService;
import com.makeitquick.payment.PaymentStatus;
import java.util.List;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Retries paid scheduled bookings when no partner was available at checkout. */
@Service
public class ScheduledBookingDispatchService {
    private final BookingRepository bookings;
    private final BookingServiceRepository bookingServices;
    private final BookingAssignmentService assigner;
    private final NotificationService notifications;

    ScheduledBookingDispatchService(BookingRepository bookings,
                                    BookingServiceRepository bookingServices,
                                    BookingAssignmentService assigner,
                                    NotificationService notifications) {
        this.bookings = bookings;
        this.bookingServices = bookingServices;
        this.assigner = assigner;
        this.notifications = notifications;
    }

    @Scheduled(initialDelay = 5000, fixedDelay = 15000)
    @Transactional
    public void retryUnassignedPaidBookings() {
        for (Booking candidate : bookings.findByStatusOrderByIdDesc(BookingStatus.REQUESTED)) {
            Booking booking = bookings.findByIdForUpdate(candidate.getId()).orElse(null);
            if (booking == null || booking.getWorker() != null || booking.isInstantBooking()
                    || booking.getStatus() != BookingStatus.REQUESTED
                    || booking.getPaymentStatus() != PaymentStatus.PAID) {
                continue;
            }
            List<String> services = bookingServices.findByBookingIdOrderByIdAsc(booking.getId()).stream()
                    .map(BookingService::getServiceName)
                    .toList();
            assigner.assignBest(booking, services, notifications);
        }
    }
}
