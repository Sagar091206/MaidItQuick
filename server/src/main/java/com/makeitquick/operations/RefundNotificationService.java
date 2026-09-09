package com.makeitquick.operations;

import com.makeitquick.admin.returns.ReturnRequest;
import com.makeitquick.booking.Booking;
import com.makeitquick.security.Role;
import com.makeitquick.security.UserAccount;
import com.makeitquick.security.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.PageRequest;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

import java.time.ZoneId;
import java.time.format.DateTimeFormatter;

/**
 * Sends resilient, non-blocking email notifications to the admin upon new refund requests.
 */
@Service
public class RefundNotificationService {

  private static final Logger log = LoggerFactory.getLogger(RefundNotificationService.class);
  private static final DateTimeFormatter FMT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss z")
      .withZone(ZoneId.of("Asia/Kolkata"));

  private final ObjectProvider<JavaMailSender> mailSender;
  private final UserRepository users;
  private final String adminEmailConfig;
  private final String bootstrapEmail;
  private final String fromAddress;

  public RefundNotificationService(
      ObjectProvider<JavaMailSender> mailSender,
      UserRepository users,
      @Value("${app.admin.email:}") String adminEmailConfig,
      @Value("${app.bootstrap.email:a.k.bharati019@gmail.com}") String bootstrapEmail,
      @Value("${app.mail.from:no-reply@maiditquick.local}") String fromAddress) {
    this.mailSender = mailSender;
    this.users = users;
    this.adminEmailConfig = adminEmailConfig;
    this.bootstrapEmail = bootstrapEmail;
    this.fromAddress = fromAddress;
  }

  /**
   * Dispatches the new refund notification to the admin.
   * Any email failure is logged and suppressed so it never interrupts or fails the refund request.
   */
  public void notifyAdminOnRefundCreated(ReturnRequest refund, Booking booking, UserAccount customer) {
    try {
      JavaMailSender sender = mailSender.getIfAvailable();
      if (sender == null) {
        log.info("JavaMailSender not available; skipping admin email dispatch for RR-{}", refund.getId());
        return;
      }

      String recipientEmail = resolveAdminEmail();
      if (recipientEmail == null || recipientEmail.isBlank()) {
        log.warn("No admin email found to notify for refund RR-{}", refund.getId());
        return;
      }

      String customerName = customer != null ? customer.getName() : "Customer #" + refund.getBookingId();
      String partnerName = (booking != null && booking.getWorker() != null)
          ? booking.getWorker().getName()
          : "Unassigned";
      String serviceName = booking != null ? booking.getService() : "—";
      String amountPaid = refund.getRequestedAmount() != null
          ? "₹" + refund.getRequestedAmount().stripTrailingZeros().toPlainString()
          : "₹0.00";
      String recommendedRefund = (refund.getRecommendedRefundPercentage() != null ? refund.getRecommendedRefundPercentage() : 0)
          + "% / ₹" + String.format("%.2f", (refund.getRecommendedRefundAmountPaise() != null ? refund.getRecommendedRefundAmountPaise() : 0) / 100.0);
      String submittedTime = refund.getCreatedAt() != null ? FMT.format(refund.getCreatedAt()) : "Just now";

      String stage = refund.getCancellationStage() != null
          ? refund.getCancellationStage()
          : (booking != null ? booking.getCancellationStage() : null);

      String subject = "New Refund Request - RR-" + refund.getId();
      String body = "Hello Admin,\n\n"
          + "A new refund request has been submitted.\n\n"
          + "Refund Request ID: RR-" + refund.getId() + "\n"
          + "Booking ID: BK-" + refund.getBookingId() + "\n"
          + "Customer: " + customerName + "\n"
          + "Partner: " + partnerName + "\n"
          + "Service: " + serviceName + "\n\n"
          + "Reason:\n" + refund.getReason() + "\n\n"
          + (stage != null && !stage.isBlank() ? "Cancellation Stage:\n" + stage + "\n\n" : "")
          + "Amount Paid:\n" + amountPaid + "\n\n"
          + "System Recommendation:\n" + (refund.getRecommendedResolution() != null ? refund.getRecommendedResolution() : "Under Review") + "\n\n"
          + "Recommended Refund:\n" + recommendedRefund + "\n\n"
          + "Fault:\n" + (refund.getFaultType() != null ? refund.getFaultType() : "Unclassified") + "\n\n"
          + "Status:\n" + refund.getStatus() + "\n\n"
          + "Submitted Date/Time:\n" + submittedTime + "\n\n"
          + "Please review the request and evidence from the Admin Dashboard before making the final decision.\n\n"
          + "This is an automated notification from MaidItQuick.\n";

      SimpleMailMessage msg = new SimpleMailMessage();
      msg.setFrom(fromAddress);
      msg.setTo(recipientEmail);
      msg.setSubject(subject);
      msg.setText(body);

      sender.send(msg);
      log.info("Admin notification email sent successfully to {} for refund RR-{}", recipientEmail, refund.getId());
    } catch (Exception e) {
      // Must NOT fail the refund request creation
      log.warn("Failed to send admin refund notification email for RR-{}: {}", refund.getId(), e.getMessage());
    }
  }

  private String resolveAdminEmail() {
    if (adminEmailConfig != null && !adminEmailConfig.isBlank()) {
      return adminEmailConfig.trim();
    }
    var adminOpt = users.findByRole(Role.ADMIN, PageRequest.of(0, 1)).stream().findFirst();
    if (adminOpt.isPresent() && adminOpt.get().getEmail() != null && !adminOpt.get().getEmail().isBlank()) {
      return adminOpt.get().getEmail().trim();
    }
    return bootstrapEmail != null ? bootstrapEmail.trim() : null;
  }
}
