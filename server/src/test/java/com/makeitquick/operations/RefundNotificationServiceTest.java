package com.makeitquick.operations;

import com.makeitquick.admin.returns.ReturnRequest;
import com.makeitquick.booking.Booking;
import com.makeitquick.security.Role;
import com.makeitquick.security.UserAccount;
import com.makeitquick.security.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.mail.MailSendException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

public class RefundNotificationServiceTest {

  private JavaMailSender mailSender;
  private ObjectProvider<JavaMailSender> mailProvider;
  private UserRepository users;
  private RefundNotificationService service;

  @BeforeEach
  void setUp() {
    mailSender = mock(JavaMailSender.class);
    mailProvider = mock(ObjectProvider.class);
    when(mailProvider.getIfAvailable()).thenReturn(mailSender);
    users = mock(UserRepository.class);

    UserAccount admin = new UserAccount("Admin User", "admin@maiditquick.in", "hash", Role.ADMIN);
    when(users.findByRole(eq(Role.ADMIN), any())).thenReturn(new org.springframework.data.domain.PageImpl<>(List.of(admin)));

    service = new RefundNotificationService(
        mailProvider,
        users,
        "",
        "a.k.bharati019@gmail.com",
        "no-reply@maiditquick.local"
    );
  }

  @Test
  void testScenarioH_EmailSucceeds() {
    ReturnRequest refund = new ReturnRequest();
    refund.setId(101L);
    refund.setBookingId(202L);
    refund.setReason("partner_no_show");
    refund.setRequestedAmount(BigDecimal.valueOf(600.00));
    refund.setFaultType("PARTNER_FAULT");
    refund.setSeverity("critical");
    refund.setRecommendedResolution("FULL_REFUND");
    refund.setRecommendedRefundPercentage(100);
    refund.setRecommendedRefundAmountPaise(60000);
    refund.setEvidenceRequired(true);

    UserAccount customer = new UserAccount("Jane Customer", "customer@test.com", "hash", Role.CUSTOMER);

    service.notifyAdminOnRefundCreated(refund, null, customer);

    ArgumentCaptor<SimpleMailMessage> captor = ArgumentCaptor.forClass(SimpleMailMessage.class);
    verify(mailSender, times(1)).send(captor.capture());

    SimpleMailMessage sent = captor.getValue();
    assertNotNull(sent);
    assertEquals("admin@maiditquick.in", sent.getTo()[0]);
    assertEquals("New Refund Request - RR-101", sent.getSubject());
    assertTrue(sent.getText().contains("RR-101"));
    assertTrue(sent.getText().contains("Jane Customer"));
    assertTrue(sent.getText().contains("FULL_REFUND"));
    assertTrue(sent.getText().contains("PARTNER_FAULT"));
  }

  @Test
  void testScenarioI_EmailFails_DoesNotThrow() {
    doThrow(new MailSendException("SMTP connection refused"))
        .when(mailSender).send(any(SimpleMailMessage.class));

    ReturnRequest refund = new ReturnRequest();
    refund.setId(102L);
    refund.setBookingId(203L);
    refund.setReason("incomplete_service");
    refund.setRequestedAmount(BigDecimal.valueOf(300.00));

    UserAccount customer = new UserAccount("cust@test.com", "pass", "Cust", Role.CUSTOMER);

    assertDoesNotThrow(() -> service.notifyAdminOnRefundCreated(refund, null, customer));
    verify(mailSender, times(1)).send(any(SimpleMailMessage.class));
  }
}
