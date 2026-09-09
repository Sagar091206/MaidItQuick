package com.makeitquick.operations;

import com.makeitquick.booking.Booking;
import com.makeitquick.booking.BookingStatus;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.Locale;

/**
 * Automated Refund Rules Engine for MaidItQuick.
 *
 * Evaluates refund requests against 18 predefined business scenarios and booking data,
 * producing an advisory recommendation for the admin without auto-approving or auto-processing.
 */
@Service
public class RefundRulesEngine {

  public static final String PLATFORM_FAULT = "PLATFORM_FAULT";
  public static final String PARTNER_FAULT = "PARTNER_FAULT";
  public static final String CUSTOMER_FAULT = "CUSTOMER_FAULT";
  public static final String PAYMENT_ISSUE = "PAYMENT_ISSUE";

  public static final String RESOLUTION_FULL_REFUND = "FULL_REFUND";
  public static final String RESOLUTION_PARTIAL_REFUND = "PARTIAL_REFUND";
  public static final String RESOLUTION_NO_REFUND = "NO_REFUND";
  public static final String RESOLUTION_FREE_RESERVICE = "FREE_RESERVICE";
  public static final String RESOLUTION_INVESTIGATION = "INVESTIGATION_REQUIRED";

  @Value("${app.refund.default-percentage:50}")
  private int defaultPercentage;

  @Value("${app.refund.severity-minor-percentage:15}")
  private int severityMinorPercentage;

  @Value("${app.refund.severity-moderate-percentage:35}")
  private int severityModeratePercentage;

  @Value("${app.refund.severity-major-percentage:60}")
  private int severityMajorPercentage;

  @Value("${app.refund.severity-critical-percentage:100}")
  private int severityCriticalPercentage;

  public record RefundRecommendation(
      String faultType,
      String severity,
      String recommendedResolution,
      int recommendedRefundPercentage,
      int recommendedRefundAmountPaise,
      boolean evidenceRequired,
      String recommendationReason
  ) {}

  /**
   * Evaluates the refund request and outputs an advisory recommendation.
   */
  public RefundRecommendation evaluate(
      String rawReason,
      Booking booking,
      int amountPaise,
      int serviceDeliveredPercent,
      String cancellationReason,
      String partnerArrivalInfo) {
    String stage = booking != null ? booking.getCancellationStage() : null;
    return evaluate(rawReason, booking, amountPaise, serviceDeliveredPercent, cancellationReason, partnerArrivalInfo, stage);
  }

  /**
   * Evaluates the refund request with explicit cancellation stage awareness.
   */
  public RefundRecommendation evaluate(
      String rawReason,
      Booking booking,
      int amountPaise,
      int serviceDeliveredPercent,
      String cancellationReason,
      String partnerArrivalInfo,
      String cancellationStage) {

    String scenarioKey = identifyScenario(rawReason, cancellationReason);
    int deliveredPct = Math.max(0, Math.min(100, serviceDeliveredPercent));

    // Refine deliveredPct from booking data if 0
    if (deliveredPct == 0 && booking != null) {
      deliveredPct = estimateDeliveredPercent(booking);
    }

    String stage = cancellationStage != null && !cancellationStage.isBlank()
        ? cancellationStage
        : (booking != null ? booking.getCancellationStage() : null);

    return switch (scenarioKey) {
      case "partner_no_show" -> buildPartnerNoShow(amountPaise);
      case "customer_no_show" -> buildCustomerNoShow(amountPaise);
      case "partner_late_arrival" -> buildPartnerLateArrival(amountPaise, deliveredPct);
      case "customer_late_arrival" -> buildCustomerLateArrival(amountPaise);
      case "service_quality_issue" -> buildServiceQualityIssue(rawReason, amountPaise, deliveredPct);
      case "wrong_address_customer_error" -> buildWrongAddressCustomer(amountPaise);
      case "wrong_location_partner_error" -> buildWrongLocationPartner(amountPaise);
      case "double_payment" -> buildDoublePayment(amountPaise);
      case "payment_failed_debited" -> buildPaymentFailedDebited(amountPaise, booking);
      case "mid_service_cancellation" -> buildMidServiceCancellation(amountPaise, deliveredPct);
      case "damaged_property" -> buildDamagedProperty(amountPaise);
      case "incomplete_service" -> buildIncompleteService(amountPaise, deliveredPct);
      case "missing_item_complaint" -> buildMissingItem(amountPaise);
      case "safety_incident" -> buildSafetyIncident(amountPaise);
      case "duplicate_booking" -> buildDuplicateBooking(amountPaise);
      case "customer_cancels_after_partner_arrives" -> buildCustomerCancelsAfterArrival(amountPaise);
      case "company_side_cancellation" -> buildCompanySideCancellation(amountPaise);
      case "partner_lacks_tools" -> buildPartnerLacksTools(amountPaise);
      case "customer_cancels_before_service" -> buildCustomerCancelsBeforeService(amountPaise, stage);
      case "partner_asked_to_cancel" -> buildPartnerAskedToCancel(amountPaise);
      case "emergency" -> buildEmergency(amountPaise, stage);
      default -> buildFallback(rawReason, amountPaise, deliveredPct);
    };
  }

  // --------------------------------------------------------------------------
  // Scenario Builders
  // --------------------------------------------------------------------------

  private RefundRecommendation buildPartnerNoShow(int amountPaise) {
    return new RefundRecommendation(
        PARTNER_FAULT,
        "critical",
        RESOLUTION_FULL_REFUND,
        100,
        amountPaise,
        true,
        "Partner failed to show up for scheduled booking. Replacement was prioritized; full 100% refund recommended if unfulfilled."
    );
  }

  private RefundRecommendation buildCustomerNoShow(int amountPaise) {
    return new RefundRecommendation(
        CUSTOMER_FAULT,
        "minor",
        RESOLUTION_NO_REFUND,
        0,
        0,
        true,
        "Customer was unavailable at scheduled service location. No refund recommended per no-show policy (emergency exceptions require admin review)."
    );
  }

  private RefundRecommendation buildPartnerLateArrival(int amountPaise, int deliveredPct) {
    if (deliveredPct >= 80) {
      return new RefundRecommendation(
          PARTNER_FAULT,
          "minor",
          RESOLUTION_NO_REFUND,
          0,
          0,
          true,
          "Partner arrived late but completed substantial work (" + deliveredPct + "%). No refund recommended, consider goodwill credit if requested."
      );
    } else if (deliveredPct > 0) {
      int refundPct = Math.max(severityMinorPercentage, 100 - deliveredPct);
      int refundPaise = calculateProportionalRefund(amountPaise, refundPct);
      return new RefundRecommendation(
          PARTNER_FAULT,
          "moderate",
          RESOLUTION_PARTIAL_REFUND,
          refundPct,
          refundPaise,
          true,
          "Major partner arrival delay resulted in partial service delivery (" + deliveredPct + "%). Partial refund of " + refundPct + "% recommended."
      );
    } else {
      return new RefundRecommendation(
          PARTNER_FAULT,
          "major",
          RESOLUTION_FULL_REFUND,
          100,
          amountPaise,
          true,
          "Partner arrived excessively late and service was cancelled before commencement. Full 100% refund recommended."
      );
    }
  }

  private RefundRecommendation buildCustomerLateArrival(int amountPaise) {
    return new RefundRecommendation(
        CUSTOMER_FAULT,
        "minor",
        RESOLUTION_NO_REFUND,
        0,
        0,
        true,
        "Customer arrived late for scheduled appointment. Partner waited; 0% refund recommended unless partner agreed to reschedule."
    );
  }

  private RefundRecommendation buildServiceQualityIssue(String reason, int amountPaise, int deliveredPct) {
    String lower = (reason == null ? "" : reason).toLowerCase(Locale.ROOT);
    String severity;
    int pct;
    String resolution;

    if (lower.contains("unusable") || lower.contains("horrible") || lower.contains("terrible") || lower.contains("hazard") || (deliveredPct > 0 && deliveredPct <= 10)) {
      severity = "critical";
      pct = severityCriticalPercentage;
      resolution = RESOLUTION_FULL_REFUND;
    } else if (lower.contains("major") || lower.contains("severe") || (deliveredPct > 0 && deliveredPct <= 40)) {
      severity = "major";
      pct = severityMajorPercentage;
      resolution = RESOLUTION_PARTIAL_REFUND;
    } else if (lower.contains("minor") || lower.contains("small") || lower.contains("slight")) {
      severity = "minor";
      pct = severityMinorPercentage;
      resolution = RESOLUTION_FREE_RESERVICE;
    } else if (lower.contains("moderate") || lower.contains("average") || (deliveredPct > 0 && deliveredPct <= 70)) {
      severity = "moderate";
      pct = severityModeratePercentage;
      resolution = RESOLUTION_PARTIAL_REFUND;
    } else {
      severity = "minor";
      pct = severityMinorPercentage;
      resolution = RESOLUTION_FREE_RESERVICE;
    }

    int refundPaise = calculateProportionalRefund(amountPaise, pct);
    return new RefundRecommendation(
        PARTNER_FAULT,
        severity,
        resolution,
        pct,
        refundPaise,
        true,
        "Service quality dispute evaluated as " + severity + " severity. Recommended: " + resolution + " (" + pct + "%). Evidence review required."
    );
  }

  private RefundRecommendation buildWrongAddressCustomer(int amountPaise) {
    return new RefundRecommendation(
        CUSTOMER_FAULT,
        "minor",
        RESOLUTION_NO_REFUND,
        0,
        0,
        true,
        "Customer provided an inaccurate service address. Partner navigated to provided address; no refund recommended."
    );
  }

  private RefundRecommendation buildWrongLocationPartner(int amountPaise) {
    return new RefundRecommendation(
        PARTNER_FAULT,
        "major",
        RESOLUTION_FULL_REFUND,
        100,
        amountPaise,
        true,
        "Partner failed to arrive at correct customer address. Replacement was prioritized; full 100% refund recommended if undelivered."
    );
  }

  private RefundRecommendation buildDoublePayment(int amountPaise) {
    return new RefundRecommendation(
        PAYMENT_ISSUE,
        "critical",
        RESOLUTION_FULL_REFUND,
        100,
        amountPaise,
        true,
        "Double/duplicate payment reported. Full 100% refund recommended for verified extra debit upon gateway reconciliation."
    );
  }

  private RefundRecommendation buildPaymentFailedDebited(int amountPaise, Booking booking) {
    return new RefundRecommendation(
        PAYMENT_ISSUE,
        "critical",
        RESOLUTION_FULL_REFUND,
        100,
        amountPaise,
        true,
        "Payment was debited but booking was not confirmed or immediately cancelled. Full 100% payment reversal recommended."
    );
  }

  private RefundRecommendation buildMidServiceCancellation(int amountPaise, int deliveredPct) {
    int fairChargePaise = (amountPaise * deliveredPct) / 100;
    int refundPaise = Math.max(0, amountPaise - fairChargePaise);
    int refundPct = Math.max(0, 100 - deliveredPct);

    return new RefundRecommendation(
        PARTNER_FAULT,
        deliveredPct <= 25 ? "major" : "moderate",
        refundPct > 0 ? RESOLUTION_PARTIAL_REFUND : RESOLUTION_NO_REFUND,
        refundPct,
        refundPaise,
        true,
        "Mid-service cancellation with " + deliveredPct + "% valid work delivered. Proportional refund recommended: Total Paid - Fair Charge = ₹" + String.format("%.2f", refundPaise / 100.0) + "."
    );
  }

  private RefundRecommendation buildDamagedProperty(int amountPaise) {
    return new RefundRecommendation(
        PARTNER_FAULT,
        "critical",
        RESOLUTION_INVESTIGATION,
        0,
        0,
        true,
        "Property damage reported. Formal investigation required with inspection photos and partner statement before any payout/repair authorization."
    );
  }

  private RefundRecommendation buildIncompleteService(int amountPaise, int deliveredPct) {
    int fairChargePaise = (amountPaise * deliveredPct) / 100;
    int refundPaise = Math.max(0, amountPaise - fairChargePaise);
    int refundPct = Math.max(0, 100 - deliveredPct);
    String resolution = deliveredPct < 30 ? RESOLUTION_FREE_RESERVICE : RESOLUTION_PARTIAL_REFUND;

    return new RefundRecommendation(
        PARTNER_FAULT,
        deliveredPct <= 50 ? "major" : "moderate",
        resolution,
        refundPct,
        refundPaise,
        true,
        "Incomplete service with " + deliveredPct + "% delivered. Proportional partial refund of " + refundPct + "% (or free re-service) recommended."
    );
  }

  private RefundRecommendation buildMissingItem(int amountPaise) {
    return new RefundRecommendation(
        PARTNER_FAULT,
        "critical",
        RESOLUTION_INVESTIGATION,
        0,
        0,
        true,
        "Missing item complaint. Immediate safety & compliance investigation required. Refund or compensation pending verified responsibility."
    );
  }

  private RefundRecommendation buildSafetyIncident(int amountPaise) {
    return new RefundRecommendation(
        PLATFORM_FAULT,
        "critical",
        RESOLUTION_FULL_REFUND,
        100,
        amountPaise,
        true,
        "Safety incident flagged. Immediate platform safety escalation triggered; 100% full refund recommended pending safety team investigation."
    );
  }

  private RefundRecommendation buildDuplicateBooking(int amountPaise) {
    return new RefundRecommendation(
        PLATFORM_FAULT,
        "moderate",
        RESOLUTION_FULL_REFUND,
        100,
        amountPaise,
        true,
        "Duplicate booking detected for same customer/slot. 100% refund recommended for the redundant reservation."
    );
  }

  private RefundRecommendation buildCustomerCancelsAfterArrival(int amountPaise) {
    return new RefundRecommendation(
        CUSTOMER_FAULT,
        "moderate",
        RESOLUTION_NO_REFUND,
        0,
        0,
        true,
        "Customer cancelled after partner arrived on site. Partner dispatch fee must be covered; 0% refund recommended unless mitigating emergency verified."
    );
  }

  private RefundRecommendation buildCompanySideCancellation(int amountPaise) {
    return new RefundRecommendation(
        PLATFORM_FAULT,
        "critical",
        RESOLUTION_FULL_REFUND,
        100,
        amountPaise,
        true,
        "Booking cancelled due to company/platform constraints or weather force majeure. Full 100% refund recommended."
    );
  }

  private RefundRecommendation buildPartnerLacksTools(int amountPaise) {
    return new RefundRecommendation(
        PARTNER_FAULT,
        "major",
        RESOLUTION_FULL_REFUND,
        100,
        amountPaise,
        true,
        "Partner lacked required equipment/supplies. Replacement prioritized; full 100% refund recommended if service was unfulfilled."
    );
  }

  private RefundRecommendation buildCustomerCancelsBeforeService(int amountPaise, String stage) {
    boolean beforeAssignment = stage != null && (stage.equalsIgnoreCase("BEFORE_ASSIGNMENT") || stage.equalsIgnoreCase("REQUESTED"));
    if (beforeAssignment) {
      return new RefundRecommendation(
          CUSTOMER_FAULT,
          "minor",
          RESOLUTION_FULL_REFUND,
          100,
          amountPaise,
          false,
          "Customer cancelled before partner assignment. No partner was dispatched and 0 operational costs incurred; 100% full refund recommended."
      );
    }
    boolean afterArrival = stage != null && (stage.equalsIgnoreCase("AFTER_ARRIVAL") || stage.equalsIgnoreCase("ARRIVED") || stage.equalsIgnoreCase("DURING_SERVICE") || stage.equalsIgnoreCase("IN_PROGRESS"));
    if (afterArrival) {
      return new RefundRecommendation(
          CUSTOMER_FAULT,
          "moderate",
          RESOLUTION_NO_REFUND,
          0,
          0,
          true,
          "Customer cancelled after partner arrived at location. Partner dispatch/travel cost must be protected; 0% refund recommended unless emergency verified."
      );
    }
    // After assignment / before arrival (partner assigned/en route, not yet arrived)
    int refundPct = defaultPercentage;
    int refundPaise = calculateProportionalRefund(amountPaise, refundPct);
    return new RefundRecommendation(
        CUSTOMER_FAULT,
        "moderate",
        RESOLUTION_PARTIAL_REFUND,
        refundPct,
        refundPaise,
        true,
        "Customer cancelled after partner assignment. Partial refund (" + refundPct + "%) recommended to cover allocation."
    );
  }

  private RefundRecommendation buildPartnerAskedToCancel(int amountPaise) {
    return new RefundRecommendation(
        PARTNER_FAULT,
        "major",
        RESOLUTION_FULL_REFUND,
        100,
        amountPaise,
        true,
        "Customer reported that partner requested cancellation. Replacement prioritized; full 100% refund recommended subject to partner dispute review."
    );
  }

  private RefundRecommendation buildEmergency(int amountPaise, String stage) {
    boolean beforeAssignment = stage != null && (stage.equalsIgnoreCase("BEFORE_ASSIGNMENT") || stage.equalsIgnoreCase("REQUESTED"));
    if (beforeAssignment) {
      return new RefundRecommendation(
          CUSTOMER_FAULT,
          "minor",
          RESOLUTION_FULL_REFUND,
          100,
          amountPaise,
          false,
          "Emergency reported by customer prior to partner assignment. Full 100% refund recommended on humanitarian/compassionate grounds."
      );
    }
    return new RefundRecommendation(
        CUSTOMER_FAULT,
        "moderate",
        RESOLUTION_INVESTIGATION,
        0,
        0,
        true,
        "Customer reported emergency cancellation after partner assignment. Admin review of emergency context required before approving refund."
    );
  }

  private RefundRecommendation buildFallback(String reason, int amountPaise, int deliveredPct) {
    int refundPct = defaultPercentage;
    int refundPaise = calculateProportionalRefund(amountPaise, refundPct);
    return new RefundRecommendation(
        PARTNER_FAULT,
        "moderate",
        RESOLUTION_PARTIAL_REFUND,
        refundPct,
        refundPaise,
        true,
        "Standard refund review: " + (reason == null || reason.isBlank() ? "Unspecified reason" : reason) + ". Evidence review and admin discretion required."
    );
  }

  // --------------------------------------------------------------------------
  // Helper Matchers & Math
  // --------------------------------------------------------------------------

  private int calculateProportionalRefund(int amountPaise, int pct) {
    if (amountPaise <= 0 || pct <= 0) return 0;
    if (pct >= 100) return amountPaise;
    return (int) Math.round((amountPaise * pct) / 100.0);
  }

  private int estimateDeliveredPercent(Booking booking) {
    if (booking == null) return 0;
    if (booking.getEndOtpHash() != null) {
      return 100;
    }
    if (booking.getStartOtpHash() != null) {
      return 50;
    }
    return 0;
  }

  /**
   * Normalizes and maps freeform/slug reasons to one of the known scenario keys.
   */
  public String identifyScenario(String rawReason, String cancellationReason) {
    String text = ((rawReason == null ? "" : rawReason) + " " + (cancellationReason == null ? "" : cancellationReason)).toLowerCase(Locale.ROOT);
    String slug = text.replace("-", "_").replace(" ", "_");

    if (slug.contains("partner_asked") || text.contains("partner asked") || text.contains("partner requested") || text.contains("partner told") || text.contains("worker asked") || text.contains("worker requested")) {
      return "partner_asked_to_cancel";
    }
    if (slug.contains("emergency") || text.contains("emergency") || text.contains("hospital") || text.contains("medical") || text.contains("unexpected situation")) {
      return "emergency";
    }
    if (slug.contains("no_longer_need") || text.contains("no longer need") || text.contains("no longer required") || slug.contains("booked_by_mistake") || text.contains("booked by mistake") || text.contains("plans changed") || text.contains("change of plans") || slug.contains("mistake") || text.contains("found alternative") || text.contains("wrong time") || text.contains("wrong date")) {
      return "customer_cancels_before_service";
    }
    if (slug.contains("partner_no_show") || (text.contains("partner") && (text.contains("no show") || text.contains("noshow") || text.contains("didn't show") || text.contains("did not show") || text.contains("not coming") || text.contains("isn't coming"))) || text.contains("unreachable") || text.contains("not responding")) {
      return "partner_no_show";
    }
    if (slug.contains("customer_no_show") || (text.contains("customer") && (text.contains("no show") || text.contains("noshow") || text.contains("not available") || text.contains("unavailable")))) {
      return "customer_no_show";
    }
    if (slug.contains("partner_late") || (text.contains("partner") && (text.contains("late") || text.contains("delayed") || text.contains("running late")))) {
      return "partner_late_arrival";
    }
    if (slug.contains("customer_late") || (text.contains("customer") && text.contains("late"))) {
      return "customer_late_arrival";
    }
    if (slug.contains("wrong_address") || text.contains("wrong address") || text.contains("incorrect address") || text.contains("customer address error")) {
      return "wrong_address_customer_error";
    }
    if (slug.contains("wrong_location") || text.contains("wrong location") || (text.contains("partner") && text.contains("wrong place"))) {
      return "wrong_location_partner_error";
    }
    if (slug.contains("double_payment") || text.contains("duplicate payment") || text.contains("paid twice")) {
      return "double_payment";
    }
    if (slug.contains("payment_failed") || (text.contains("debited") && text.contains("failed"))) {
      return "payment_failed_debited";
    }
    if (slug.contains("mid_service") || text.contains("mid service") || text.contains("cancelled halfway") || text.contains("left early")) {
      return "mid_service_cancellation";
    }
    if (slug.contains("damaged_property") || text.contains("damage") || text.contains("broken")) {
      return "damaged_property";
    }
    if (slug.contains("incomplete_service") || text.contains("incomplete") || text.contains("unfinished") || text.contains("half done")) {
      return "incomplete_service";
    }
    if (slug.contains("missing_item") || text.contains("missing") || text.contains("theft") || text.contains("stolen")) {
      return "missing_item_complaint";
    }
    if (slug.contains("safety_incident") || text.contains("safety") || text.contains("harassment") || text.contains("abuse") || text.contains("unsafe")) {
      return "safety_incident";
    }
    if (slug.contains("duplicate") || text.contains("duplicate") || text.contains("booked twice")) {
      return "duplicate_booking";
    }
    if (slug.contains("cancels_after_partner_arrives") || text.contains("after partner arrived") || text.contains("after arrival")) {
      return "customer_cancels_after_partner_arrives";
    }
    if (slug.contains("company_side") || text.contains("weather") || text.contains("force majeure") || text.contains("company cancel")) {
      return "company_side_cancellation";
    }
    if (slug.contains("lacks_tools") || text.contains("no tools") || text.contains("without equipment") || text.contains("missing supplies")) {
      return "partner_lacks_tools";
    }
    if (slug.contains("quality") || text.contains("poor") || text.contains("bad") || text.contains("subpar") || text.contains("dirty") || text.contains("dust") || text.contains("cleaning") || text.contains("unsatisfied") || text.contains("issue")) {
      return "service_quality_issue";
    }

    return "general_dispute";
  }
}