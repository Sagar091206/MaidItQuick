package com.makeitquick.operations;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import static org.junit.jupiter.api.Assertions.*;

public class RefundRulesEngineTest {

  private RefundRulesEngine engine;

  @BeforeEach
  void setUp() {
    engine = new RefundRulesEngine();
    ReflectionTestUtils.setField(engine, "defaultPercentage", 50);
    ReflectionTestUtils.setField(engine, "severityMinorPercentage", 15);
    ReflectionTestUtils.setField(engine, "severityModeratePercentage", 35);
    ReflectionTestUtils.setField(engine, "severityMajorPercentage", 60);
    ReflectionTestUtils.setField(engine, "severityCriticalPercentage", 100);
  }

  @Test
  void testScenarioA_PartnerNoShow_FullRefund() {
    int amount = 60000; // ₹600.00
    var rec = engine.evaluate("partner_no_show", null, amount, 0, null, null);

    assertEquals(RefundRulesEngine.PARTNER_FAULT, rec.faultType());
    assertEquals(RefundRulesEngine.RESOLUTION_FULL_REFUND, rec.recommendedResolution());
    assertEquals(100, rec.recommendedRefundPercentage());
    assertEquals(amount, rec.recommendedRefundAmountPaise());
    assertTrue(rec.evidenceRequired());
  }

  @Test
  void testScenarioB_CustomerNoShow_NoRefund() {
    int amount = 60000;
    var rec = engine.evaluate("customer_no_show", null, amount, 0, null, null);

    assertEquals(RefundRulesEngine.CUSTOMER_FAULT, rec.faultType());
    assertEquals(RefundRulesEngine.RESOLUTION_NO_REFUND, rec.recommendedResolution());
    assertEquals(0, rec.recommendedRefundPercentage());
    assertEquals(0, rec.recommendedRefundAmountPaise());
    assertTrue(rec.evidenceRequired());
  }

  @Test
  void testScenarioC_MinorServiceQualityIssue() {
    int amount = 60000;
    var rec = engine.evaluate("Minor dust left after cleaning", null, amount, 80, null, null);

    assertEquals(RefundRulesEngine.PARTNER_FAULT, rec.faultType());
    assertEquals("minor", rec.severity());
    assertEquals(RefundRulesEngine.RESOLUTION_FREE_RESERVICE, rec.recommendedResolution());
    assertEquals(15, rec.recommendedRefundPercentage());
    assertEquals(9000, rec.recommendedRefundAmountPaise()); // 15% of 60000 = 9000
    assertTrue(rec.evidenceRequired());
  }

  @Test
  void testScenarioD_IncompleteService_Proportional() {
    int amount = 60000; // ₹600
    int deliveredPct = 50; // 50% completed
    var rec = engine.evaluate("incomplete_service", null, amount, deliveredPct, null, null);

    assertEquals(RefundRulesEngine.PARTNER_FAULT, rec.faultType());
    assertEquals(RefundRulesEngine.RESOLUTION_PARTIAL_REFUND, rec.recommendedResolution());
    assertEquals(50, rec.recommendedRefundPercentage());
    assertEquals(30000, rec.recommendedRefundAmountPaise()); // ₹300
    assertTrue(rec.evidenceRequired());
  }

  @Test
  void testScenarioE_DoublePayment_FullRefund() {
    int duplicateAmount = 50000; // ₹500
    var rec = engine.evaluate("double_payment", null, duplicateAmount, 0, null, null);

    assertEquals(RefundRulesEngine.PAYMENT_ISSUE, rec.faultType());
    assertEquals(RefundRulesEngine.RESOLUTION_FULL_REFUND, rec.recommendedResolution());
    assertEquals(100, rec.recommendedRefundPercentage());
    assertEquals(duplicateAmount, rec.recommendedRefundAmountPaise());
    assertTrue(rec.evidenceRequired());
  }

  @Test
  void testScenarioF_PaymentFailedDebited_FullRefund() {
    int amount = 75000;
    var rec = engine.evaluate("payment_failed_debited", null, amount, 0, null, null);

    assertEquals(RefundRulesEngine.PAYMENT_ISSUE, rec.faultType());
    assertEquals(RefundRulesEngine.RESOLUTION_FULL_REFUND, rec.recommendedResolution());
    assertEquals(100, rec.recommendedRefundPercentage());
    assertEquals(amount, rec.recommendedRefundAmountPaise());
    assertTrue(rec.evidenceRequired());
  }

  @Test
  void testScenarioG_CompanySideCancellation_FullRefund() {
    int amount = 80000;
    var rec = engine.evaluate("company_side_cancellation", null, amount, 0, null, null);

    assertEquals(RefundRulesEngine.PLATFORM_FAULT, rec.faultType());
    assertEquals(RefundRulesEngine.RESOLUTION_FULL_REFUND, rec.recommendedResolution());
    assertEquals(100, rec.recommendedRefundPercentage());
    assertEquals(amount, rec.recommendedRefundAmountPaise());
    assertTrue(rec.evidenceRequired());
  }

  @Test
  void testMidServiceCancellation() {
    int amount = 100000; // ₹1000
    int delivered = 25; // 25% delivered
    var rec = engine.evaluate("mid_service_cancellation", null, amount, delivered, null, null);

    assertEquals(RefundRulesEngine.PARTNER_FAULT, rec.faultType());
    assertEquals(RefundRulesEngine.RESOLUTION_PARTIAL_REFUND, rec.recommendedResolution());
    assertEquals(75, rec.recommendedRefundPercentage());
    assertEquals(75000, rec.recommendedRefundAmountPaise()); // ₹750
  }

  @Test
  void testSafetyIncident_FullRefund() {
    int amount = 50000;
    var rec = engine.evaluate("safety_incident", null, amount, 0, null, null);

    assertEquals(RefundRulesEngine.PLATFORM_FAULT, rec.faultType());
    assertEquals(RefundRulesEngine.RESOLUTION_FULL_REFUND, rec.recommendedResolution());
    assertEquals(100, rec.recommendedRefundPercentage());
    assertEquals(amount, rec.recommendedRefundAmountPaise());
  }

  @Test
  void testCustomerCancelsAfterPartnerArrives_NoRefund() {
    int amount = 50000;
    var rec = engine.evaluate("customer_cancels_after_partner_arrives", null, amount, 0, null, null);

    assertEquals(RefundRulesEngine.CUSTOMER_FAULT, rec.faultType());
    assertEquals(RefundRulesEngine.RESOLUTION_NO_REFUND, rec.recommendedResolution());
    assertEquals(0, rec.recommendedRefundPercentage());
    assertEquals(0, rec.recommendedRefundAmountPaise());
  }
}
