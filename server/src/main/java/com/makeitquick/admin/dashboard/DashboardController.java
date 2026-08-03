package com.makeitquick.admin.dashboard;

import com.makeitquick.admin.categories.CategoryRepository;
import com.makeitquick.admin.common.ApiResponse;
import com.makeitquick.admin.notifications.AdminNotificationRepository;
import com.makeitquick.admin.reviews.ReviewRepository;
import com.makeitquick.admin.services.ServiceOfferingRepository;
import com.makeitquick.booking.Booking;
import com.makeitquick.booking.BookingRepository;
import com.makeitquick.booking.BookingStatus;
import com.makeitquick.payment.PaymentRepository;
import com.makeitquick.payment.PaymentStatus;
import com.makeitquick.security.Role;
import com.makeitquick.security.UserRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/admin/dashboard")
public class DashboardController {

  private final UserRepository users;
  private final BookingRepository bookings;
  private final PaymentRepository payments;
  private final ReviewRepository reviews;
  private final ServiceOfferingRepository services;
  private final CategoryRepository categories;
  private final AdminNotificationRepository notifications;

  public DashboardController(UserRepository users, BookingRepository bookings,
                             PaymentRepository payments, ReviewRepository reviews,
                             ServiceOfferingRepository services, CategoryRepository categories,
                             AdminNotificationRepository notifications) {
    this.users = users;
    this.bookings = bookings;
    this.payments = payments;
    this.reviews = reviews;
    this.services = services;
    this.categories = categories;
    this.notifications = notifications;
  }

  @GetMapping("/summary")
  @PreAuthorize("hasAuthority('DASHBOARD_VIEW')")
  public ApiResponse<Map<String, Object>> summary() {
    Map<String, Object> r = new LinkedHashMap<>();
    r.put("totalUsers", users.count());
    r.put("totalCustomers", users.countByRole(Role.CUSTOMER));
    r.put("todayBookings", bookings.countByCreatedAtGreaterThanEqual(
        LocalDate.now(ZoneOffset.UTC).atStartOfDay().toInstant(ZoneOffset.UTC)));
    r.put("pendingBookings", countIn(List.of(BookingStatus.REQUESTED, BookingStatus.SEARCHING, BookingStatus.NO_PARTNER_FOUND)));
    r.put("confirmedBookings", countIn(List.of(BookingStatus.ASSIGNED, BookingStatus.ACCEPTED, BookingStatus.ON_THE_WAY, BookingStatus.ARRIVED)));
    r.put("inProgressBookings", countIn(List.of(BookingStatus.IN_PROGRESS)));
    r.put("completedBookings", countIn(List.of(BookingStatus.COMPLETED)));
    r.put("cancelledBookings", countIn(List.of(BookingStatus.CANCELLED, BookingStatus.EXPIRED)));
    r.put("pendingPayments", payments.countByStatus(PaymentStatus.PENDING));
    r.put("paidPayments", payments.countByStatus(PaymentStatus.PAID));
    r.put("totalRevenue", rupees(payments.sumAmountPaiseByStatus(PaymentStatus.PAID)));
    r.put("totalServices", services.count());
    r.put("totalCategories", categories.count());
    r.put("pendingReviews", reviews.countByStatus("PENDING"));
    r.put("averageRating", reviews.averageApprovedRating());
    r.put("unreadNotifications", notifications.countByReadFalse());
    return ApiResponse.ok(r);
  }

  @GetMapping("/recent-bookings")
  @PreAuthorize("hasAuthority('DASHBOARD_VIEW')")
  public ApiResponse<List<Booking>> recentBookings() {
    return ApiResponse.ok(bookings.findAll(PageRequest.of(0, 5)).getContent());
  }

  private long countIn(List<BookingStatus> statuses) {
    return statuses.stream().mapToLong(bookings::countByStatus).sum();
  }

  private BigDecimal rupees(long paise) {
    return BigDecimal.valueOf(paise, 2);
  }
}
