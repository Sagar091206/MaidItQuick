package com.makeitquick.support;

import org.springframework.stereotype.Service;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class SupportRulesEngine {

    public record ScenarioRule(
        String scenario,
        String category,
        String displayName,
        String description,
        String priority, // LOW, MEDIUM, HIGH, URGENT
        String severity, // LOW, MEDIUM, HIGH, CRITICAL
        boolean requiresEvidence,
        boolean allowOptionalEvidence,
        int maxEvidenceCount,
        String recommendedAction,
        boolean requiresAdminReview,
        boolean requiresBooking,
        boolean connectsToRefund
    ) {}

    private static final Map<String, ScenarioRule> RULES = new LinkedHashMap<>();

    static {
        define(new ScenarioRule(
            "PARTNER_NO_SHOW",
            "SERVICE",
            "Partner did not arrive (No-Show)",
            "The assigned partner failed to show up at the scheduled service time.",
            "HIGH",
            "HIGH",
            false,
            false,
            3,
            "Verify partner GPS and attendance records; reassign urgent replacement or process full refund.",
            true,
            true,
            true
        ));

        define(new ScenarioRule(
            "PARTNER_LATE",
            "SERVICE",
            "Partner is running late",
            "The partner has not arrived on time and is causing a delay.",
            "MEDIUM",
            "MEDIUM",
            false,
            false,
            3,
            "Check real-time arrival tracking and contact partner for ETA.",
            false,
            true,
            false
        ));

        define(new ScenarioRule(
            "PARTNER_BEHAVIOR",
            "PARTNER",
            "Unprofessional or inappropriate behavior",
            "The partner acted in an unprofessional, rude, or inappropriate manner.",
            "HIGH",
            "HIGH",
            false,
            true,
            5,
            "Escalate to Partner Operations for conduct investigation and possible account suspension.",
            true,
            true,
            false
        ));

        define(new ScenarioRule(
            "SERVICE_QUALITY",
            "SERVICE",
            "Poor service quality",
            "The service delivered did not meet quality or cleanliness expectations.",
            "MEDIUM",
            "MEDIUM",
            true,
            true,
            5,
            "Review photographic evidence; arrange complimentary re-service or partial refund.",
            true,
            true,
            true
        ));

        define(new ScenarioRule(
            "SERVICE_INCOMPLETE",
            "SERVICE",
            "Service was left incomplete",
            "The partner left before completing all agreed-upon tasks.",
            "MEDIUM",
            "MEDIUM",
            true,
            true,
            5,
            "Review incomplete work photos; schedule partner return or adjust invoice amount.",
            true,
            true,
            true
        ));

        define(new ScenarioRule(
            "WRONG_SERVICE",
            "SERVICE",
            "Wrong service performed",
            "The service delivered was different from what was booked.",
            "MEDIUM",
            "MEDIUM",
            true,
            true,
            5,
            "Verify booked service vs delivered work; adjust billing or dispatch correct service.",
            true,
            true,
            true
        ));

        define(new ScenarioRule(
            "PROPERTY_DAMAGE",
            "SAFETY",
            "Property damage occurred",
            "Household property, appliance, or item was damaged during the service.",
            "HIGH",
            "CRITICAL",
            true,
            true,
            5,
            "Immediate incident investigation; review damage photos and initiate claim protocol.",
            true,
            true,
            true
        ));

        define(new ScenarioRule(
            "MISSING_ITEM",
            "SAFETY",
            "Missing or misplaced personal item",
            "An item is missing following the partner's service visit.",
            "HIGH",
            "CRITICAL",
            true,
            true,
            5,
            "Escalate to Trust & Safety team; initiate formal security inquiry and partner interview.",
            true,
            true,
            false
        ));

        define(new ScenarioRule(
            "SAFETY_CONCERN",
            "SAFETY",
            "Safety or security concern",
            "Customer feels unsafe or reports a security violation.",
            "URGENT",
            "CRITICAL",
            false,
            true,
            5,
            "Execute urgent safety escalation protocol; direct call to customer immediately.",
            true,
            true,
            false
        ));

        define(new ScenarioRule(
            "PAYMENT_CHARGED_INCORRECTLY",
            "PAYMENT",
            "Charged incorrect amount or overcharged",
            "The amount deducted does not match the booking total or was billed multiple times.",
            "HIGH",
            "HIGH",
            false,
            true,
            3,
            "Reconcile payment gateway transaction logs against booking charges; issue refund difference.",
            true,
            true,
            true
        ));

        define(new ScenarioRule(
            "REFUND_NOT_RECEIVED",
            "PAYMENT",
            "Refund not received",
            "A promised or approved refund has not reflected in the bank or original payment method.",
            "MEDIUM",
            "MEDIUM",
            false,
            false,
            3,
            "Check existing ReturnRequest / refund transaction status with payment gateway.",
            true,
            true,
            true
        ));

        define(new ScenarioRule(
            "BOOKING_PROBLEM",
            "BOOKING",
            "Issue with booking or scheduling",
            "Unable to modify, reschedule, or find information regarding an active booking.",
            "MEDIUM",
            "LOW",
            false,
            true,
            3,
            "Check booking timeline, partner assignment status, and slot availability.",
            false,
            true,
            false
        ));

        define(new ScenarioRule(
            "PARTNER_CANCELLATION",
            "BOOKING",
            "Partner cancelled the booking",
            "The assigned partner cancelled unexpectedly before or near the service time.",
            "HIGH",
            "HIGH",
            false,
            false,
            3,
            "Check partner cancellation reason; offer instant rebooking or complete refund.",
            true,
            true,
            true
        ));

        define(new ScenarioRule(
            "APP_TECHNICAL_ISSUE",
            "TECHNICAL",
            "App technical problem or bug",
            "Encountered a crash, error, or UI glitch while using the MaidItQuick app.",
            "LOW",
            "LOW",
            false,
            true,
            5,
            "Log app platform details; forward bug report to mobile engineering team.",
            false,
            false,
            false
        ));

        define(new ScenarioRule(
            "ACCOUNT_PROFILE_ISSUE",
            "ACCOUNT",
            "Account, login, or profile issue",
            "Difficulty updating profile info, phone number, saved addresses, or signing in.",
            "LOW",
            "LOW",
            false,
            true,
            3,
            "Assist customer with profile verification, phone update, or credential reset.",
            false,
            false,
            false
        ));

        define(new ScenarioRule(
            "ADDRESS_LOCATION_ISSUE",
            "BOOKING",
            "Address or service location issue",
            "Incorrect pin location, unserviceable pin code, or partner lost en-route.",
            "LOW",
            "LOW",
            false,
            true,
            3,
            "Verify geocoded address coordinates and update service location details.",
            false,
            false,
            false
        ));

        define(new ScenarioRule(
            "EMERGENCY_URGENT",
            "SAFETY",
            "Emergency / Immediate danger",
            "Active emergency requiring prompt platform and emergency response intervention.",
            "URGENT",
            "CRITICAL",
            false,
            true,
            5,
            "Trigger high-priority emergency escalation; customer safety dispatch and immediate callback.",
            true,
            false,
            false
        ));

        define(new ScenarioRule(
            "OTHER",
            "OTHER",
            "Other question or issue",
            "General question, feedback, or issue not covered by the categories above.",
            "MEDIUM",
            "LOW",
            false,
            true,
            5,
            "Review customer request details and route to relevant support agent.",
            true,
            false,
            false
        ));
    }

    private static void define(ScenarioRule rule) {
        RULES.put(rule.scenario(), rule);
    }

    public ScenarioRule evaluate(String scenario) {
        if (scenario == null || scenario.isBlank()) {
            return RULES.get("OTHER");
        }
        ScenarioRule rule = RULES.get(scenario.trim().toUpperCase());
        return rule != null ? rule : RULES.get("OTHER");
    }

    public List<ScenarioRule> getAllRules() {
        return Collections.unmodifiableList(List.copyOf(RULES.values()));
    }

    public boolean isEvidenceRequired(String scenario) {
        return evaluate(scenario).requiresEvidence();
    }
}
