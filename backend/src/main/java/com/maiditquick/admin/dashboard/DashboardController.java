package com.maiditquick.admin.dashboard;

import com.maiditquick.admin.bookings.Booking;
import com.maiditquick.admin.bookings.BookingRepository;
import com.maiditquick.admin.categories.CategoryRepository;
import com.maiditquick.admin.common.ApiResponse;
import com.maiditquick.admin.customers.CustomerRepository;
import com.maiditquick.admin.notifications.NotificationRepository;
import com.maiditquick.admin.payments.PaymentRepository;
import com.maiditquick.admin.reviews.ReviewRepository;
import com.maiditquick.admin.services.ServiceOfferingRepository;
import com.maiditquick.admin.users.UserRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

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
  private final CustomerRepository customers;
  private final BookingRepository bookings;
  private final PaymentRepository payments;
  private final ReviewRepository reviews;
  private final ServiceOfferingRepository services;
  private final CategoryRepository categories;
  private final NotificationRepository notifications;

  public DashboardController(UserRepository users, CustomerRepository customers,
                             BookingRepository bookings, PaymentRepository payments,
                             ReviewRepository reviews, ServiceOfferingRepository services,
                             CategoryRepository categories, NotificationRepository notifications) {
    this.users = users;
    this.customers = customers;
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
    r.put("totalCustomers", customers.count());
    r.put("todayBookings", bookings.countByCreatedAtGreaterThanEqual(LocalDate.now(ZoneOffset.UTC).atStartOfDay().toInstant(ZoneOffset.UTC)));
    r.put("pendingBookings", bookings.countByStatus("PENDING"));
    r.put("confirmedBookings", bookings.countByStatus("CONFIRMED"));
    r.put("inProgressBookings", bookings.countByStatus("IN_PROGRESS"));
    r.put("completedBookings", bookings.countByStatus("COMPLETED"));
    r.put("cancelledBookings", bookings.countByStatus("CANCELLED"));
    r.put("pendingPayments", payments.countByStatus("PENDING"));
    r.put("paidPayments", payments.countByStatus("PAID"));
    r.put("totalRevenue", payments.sumPaid());
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
}
