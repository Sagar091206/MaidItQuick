package com.makeitquick.admin.reports;

import com.makeitquick.admin.common.ApiResponse;
import com.makeitquick.admin.reviews.ReviewRepository;
import com.makeitquick.admin.services.ServiceOfferingRepository;
import com.makeitquick.booking.Booking;
import com.makeitquick.booking.BookingRepository;
import com.makeitquick.payment.Payment;
import com.makeitquick.payment.PaymentRepository;
import com.makeitquick.payment.PaymentStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/v1/admin/reports")
public class ReportsController {

  private final BookingRepository bookings;
  private final PaymentRepository payments;
  private final ReviewRepository reviews;
  private final ServiceOfferingRepository services;

  public ReportsController(BookingRepository bookings, PaymentRepository payments,
                           ReviewRepository reviews, ServiceOfferingRepository services) {
    this.bookings = bookings;
    this.payments = payments;
    this.reviews = reviews;
    this.services = services;
  }

  @GetMapping("/bookings-by-status")
  @PreAuthorize("hasAuthority('REPORTS_VIEW')")
  public ApiResponse<List<Map<String, Object>>> bookingsByStatus() {
    Map<String, Long> counts = bookings.findAll().stream()
        .collect(Collectors.groupingBy(b -> b.getStatus().name(), Collectors.counting()));
    return ApiResponse.ok(counts.entrySet().stream()
        .map(e -> Map.<String, Object>of("status", e.getKey(), "count", e.getValue()))
        .toList());
  }

  @GetMapping("/revenue-by-month")
  @PreAuthorize("hasAuthority('REPORTS_VIEW')")
  public ApiResponse<List<Map<String, Object>>> revenueByMonth() {
    LocalDate start = LocalDate.now(ZoneOffset.UTC).withDayOfMonth(1).minusMonths(11);
    Map<String, BigDecimal> byMonth = new TreeMap<>();
    for (int i = 0; i < 12; i++) {
      byMonth.put(start.plusMonths(i).format(MONTH_KEY), BigDecimal.ZERO);
    }
    payments.findAll().stream()
        .filter(p -> p.getStatus() == PaymentStatus.PAID && p.getCompletedAt() != null)
        .filter(p -> !p.getCompletedAt().isBefore(start.atStartOfDay().toInstant(ZoneOffset.UTC)))
        .forEach(p -> byMonth.merge(p.getCompletedAt().atZone(ZoneOffset.UTC).format(MONTH_KEY),
            BigDecimal.valueOf(p.getAmountPaise(), 2), BigDecimal::add));
    return ApiResponse.ok(byMonth.entrySet().stream()
        .map(e -> Map.<String, Object>of("month", e.getKey(), "revenue", e.getValue()))
        .toList());
  }

  @GetMapping("/top-services")
  @PreAuthorize("hasAuthority('REPORTS_VIEW')")
  public ApiResponse<List<Map<String, Object>>> topServices() {
    Map<String, Long> counts = bookings.findAll().stream()
        .map(Booking::getService)
        .collect(Collectors.groupingBy(s -> s == null ? "Unknown" : s, Collectors.counting()));
    return ApiResponse.ok(counts.entrySet().stream()
        .sorted(Map.Entry.<String, Long>comparingByValue().reversed())
        .limit(10)
        .map(e -> Map.<String, Object>of("service", e.getKey(), "bookings", e.getValue()))
        .toList());
  }

  @GetMapping("/revenue-total")
  @PreAuthorize("hasAuthority('REPORTS_VIEW')")
  public ApiResponse<Map<String, Object>> revenueTotal() {
    return ApiResponse.ok(Map.of(
        "totalRevenue", BigDecimal.valueOf(payments.sumAmountPaiseByStatus(PaymentStatus.PAID), 2),
        "paidPayments", payments.countByStatus(PaymentStatus.PAID),
        "pendingPayments", payments.countByStatus(PaymentStatus.PENDING),
        "averageRating", reviews.averageApprovedRating(),
        "totalServices", services.count()));
  }

  private static final DateTimeFormatter MONTH_KEY = DateTimeFormatter.ofPattern("yyyy-MM");
}
