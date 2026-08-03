package com.maiditquick.admin.reports;

import com.maiditquick.admin.bookings.Booking;
import com.maiditquick.admin.bookings.BookingRepository;
import com.maiditquick.admin.common.ApiResponse;
import com.maiditquick.admin.payments.Payment;
import com.maiditquick.admin.payments.PaymentRepository;
import com.maiditquick.admin.reviews.ReviewRepository;
import com.maiditquick.admin.services.ServiceOfferingRepository;
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
        .collect(Collectors.groupingBy(Booking::getStatus, Collectors.counting()));
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
        .filter(p -> "PAID".equals(p.getStatus()) && p.getPaidAt() != null)
        .filter(p -> !p.getPaidAt().isBefore(start.atStartOfDay().toInstant(ZoneOffset.UTC)))
        .forEach(p -> byMonth.merge(p.getPaidAt().atZone(ZoneOffset.UTC).format(MONTH_KEY),
            p.getAmount(), BigDecimal::add));
    return ApiResponse.ok(byMonth.entrySet().stream()
        .map(e -> Map.<String, Object>of("month", e.getKey(), "revenue", e.getValue()))
        .toList());
  }

  @GetMapping("/top-services")
  @PreAuthorize("hasAuthority('REPORTS_VIEW')")
  public ApiResponse<List<Map<String, Object>>> topServices() {
    Map<String, Long> counts = bookings.findAll().stream()
        .filter(b -> b.getService() != null)
        .collect(Collectors.groupingBy(b -> b.getService().getName(), Collectors.counting()));
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
        "totalRevenue", payments.sumPaid(),
        "paidPayments", payments.countByStatus("PAID"),
        "pendingPayments", payments.countByStatus("PENDING"),
        "averageRating", reviews.averageApprovedRating(),
        "totalServices", services.count()));
  }

  private static final DateTimeFormatter MONTH_KEY = DateTimeFormatter.ofPattern("yyyy-MM");
}
