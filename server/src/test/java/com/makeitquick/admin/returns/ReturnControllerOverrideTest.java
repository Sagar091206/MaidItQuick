package com.makeitquick.admin.returns;

import com.makeitquick.admin.audit.AuditService;
import com.makeitquick.booking.Booking;
import com.makeitquick.booking.BookingRepository;
import com.makeitquick.notification.NotificationService;
import com.makeitquick.security.Role;
import com.makeitquick.security.UserAccount;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

import java.math.BigDecimal;
import java.security.Principal;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

public class ReturnControllerOverrideTest {

  private ReturnRepository returnRepo;
  private BookingRepository bookingRepo;
  private AuditService audit;
  private NotificationService notifications;
  private ReturnController controller;
  private HttpServletRequest request;

  @BeforeEach
  void setUp() {
    returnRepo = mock(ReturnRepository.class);
    bookingRepo = mock(BookingRepository.class);
    audit = mock(AuditService.class);
    notifications = mock(NotificationService.class);
    controller = new ReturnController(returnRepo, bookingRepo, audit, notifications);
    request = mock(HttpServletRequest.class);

    Principal principal = () -> "admin@maiditquick.in";
    when(request.getUserPrincipal()).thenReturn(principal);
  }

  @Test
  void testScenarioJ_AdminModifiesSystemRecommendation() {
    ReturnRequest existing = new ReturnRequest();
    existing.setId(42L);
    existing.setBookingId(1001L);
    existing.setRequestedAmount(BigDecimal.valueOf(600.00));
    existing.setReason("Incomplete Service");
    existing.setStatus("REQUESTED");

    // Original system recommendation: 50% / ₹300
    existing.setFaultType("PARTNER_FAULT");
    existing.setSeverity("moderate");
    existing.setServiceDeliveredPercent(50);
    existing.setRecommendedResolution("PARTIAL_REFUND");
    existing.setRecommendedRefundPercentage(50);
    existing.setRecommendedRefundAmountPaise(30000);
    existing.setEvidenceRequired(true);
    existing.setRecommendationReason("Incomplete service with 50% delivered.");

    when(returnRepo.findById(42L)).thenReturn(Optional.of(existing));
    when(returnRepo.save(any(ReturnRequest.class))).thenAnswer(inv -> inv.getArgument(0));

    Booking booking = mock(Booking.class);
    UserAccount customer = new UserAccount("Customer", "c@test.com", "pass", Role.CUSTOMER);
    when(booking.getCustomer()).thenReturn(customer);
    when(bookingRepo.findById(1001L)).thenReturn(Optional.of(booking));

    // Admin overrides: approves modified amount ₹450.00 instead of recommended ₹300.00
    BigDecimal modifiedAmount = BigDecimal.valueOf(450.00);
    ReturnController.StatusChange input = new ReturnController.StatusChange(
        "APPROVED",
        "Admin increased refund to ₹450 after reviewing extra customer photos",
        modifiedAmount
    );

    var response = controller.changeStatus(42L, input, request);

    assertNotNull(response);
    ReturnRequest updated = response.data();
    assertEquals("APPROVED", updated.getStatus());
    // Admin override amount is recorded
    assertEquals(modifiedAmount, updated.getApprovedAmount());
    assertEquals("admin@maiditquick.in", updated.getDecidedBy());
    assertNotNull(updated.getDecidedAt());
    assertTrue(updated.getAdminNote().contains("Admin increased refund to ₹450"));

    // ORIGINAL system recommendation is STILL preserved!
    assertEquals("PARTIAL_REFUND", updated.getRecommendedResolution());
    assertEquals(50, updated.getRecommendedRefundPercentage());
    assertEquals(30000, updated.getRecommendedRefundAmountPaise());
    assertEquals("Incomplete service with 50% delivered.", updated.getRecommendationReason());
  }
}
