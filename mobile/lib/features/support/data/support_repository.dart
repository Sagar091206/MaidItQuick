import 'dart:typed_data';

import '../../../core/api_client.dart';

class ScenarioRule {
  const ScenarioRule({
    required this.scenario,
    required this.category,
    required this.displayName,
    required this.description,
    required this.priority,
    required this.severity,
    required this.requiresEvidence,
    required this.allowOptionalEvidence,
    required this.maxEvidenceCount,
    required this.recommendedAction,
    required this.requiresAdminReview,
    required this.requiresBooking,
    required this.connectsToRefund,
  });

  final String scenario;
  final String category;
  final String displayName;
  final String description;
  final String priority;
  final String severity;
  final bool requiresEvidence;
  final bool allowOptionalEvidence;
  final int maxEvidenceCount;
  final String recommendedAction;
  final bool requiresAdminReview;
  final bool requiresBooking;
  final bool connectsToRefund;

  factory ScenarioRule.fromJson(Map<String, dynamic> json) {
    return ScenarioRule(
      scenario: json['scenario']?.toString() ?? '',
      category: json['category']?.toString() ?? 'OTHER',
      displayName: json['displayName']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      priority: json['priority']?.toString() ?? 'MEDIUM',
      severity: json['severity']?.toString() ?? 'LOW',
      requiresEvidence: json['requiresEvidence'] == true,
      allowOptionalEvidence: json['allowOptionalEvidence'] == true,
      maxEvidenceCount: (json['maxEvidenceCount'] as num?)?.toInt() ?? 3,
      recommendedAction: json['recommendedAction']?.toString() ?? '',
      requiresAdminReview: json['requiresAdminReview'] == true,
      requiresBooking: json['requiresBooking'] == true,
      connectsToRefund: json['connectsToRefund'] == true,
    );
  }
}

const List<ScenarioRule> kDefaultScenarios = [
  ScenarioRule(
    scenario: 'PARTNER_NO_SHOW',
    category: 'SERVICE',
    displayName: 'Partner did not arrive (No-Show)',
    description: 'The assigned partner failed to show up at the scheduled service time.',
    priority: 'HIGH',
    severity: 'HIGH',
    requiresEvidence: false,
    allowOptionalEvidence: false,
    maxEvidenceCount: 3,
    recommendedAction: 'Verify partner GPS and attendance records; reassign urgent replacement or process full refund.',
    requiresAdminReview: true,
    requiresBooking: true,
    connectsToRefund: true,
  ),
  ScenarioRule(
    scenario: 'PARTNER_LATE',
    category: 'SERVICE',
    displayName: 'Partner is running late',
    description: 'The partner has not arrived on time and is causing a delay.',
    priority: 'MEDIUM',
    severity: 'MEDIUM',
    requiresEvidence: false,
    allowOptionalEvidence: false,
    maxEvidenceCount: 3,
    recommendedAction: 'Check real-time arrival tracking and contact partner for ETA.',
    requiresAdminReview: false,
    requiresBooking: true,
    connectsToRefund: false,
  ),
  ScenarioRule(
    scenario: 'PARTNER_BEHAVIOR',
    category: 'PARTNER',
    displayName: 'Unprofessional or inappropriate behavior',
    description: 'The partner acted in an unprofessional, rude, or inappropriate manner.',
    priority: 'HIGH',
    severity: 'HIGH',
    requiresEvidence: false,
    allowOptionalEvidence: true,
    maxEvidenceCount: 5,
    recommendedAction: 'Escalate to Partner Operations for conduct investigation and possible account suspension.',
    requiresAdminReview: true,
    requiresBooking: true,
    connectsToRefund: false,
  ),
  ScenarioRule(
    scenario: 'SERVICE_QUALITY',
    category: 'SERVICE',
    displayName: 'Poor service quality',
    description: 'The service delivered did not meet quality or cleanliness expectations.',
    priority: 'MEDIUM',
    severity: 'MEDIUM',
    requiresEvidence: true,
    allowOptionalEvidence: true,
    maxEvidenceCount: 5,
    recommendedAction: 'Review photographic evidence; arrange complimentary re-service or partial refund.',
    requiresAdminReview: true,
    requiresBooking: true,
    connectsToRefund: true,
  ),
  ScenarioRule(
    scenario: 'SERVICE_INCOMPLETE',
    category: 'SERVICE',
    displayName: 'Service was left incomplete',
    description: 'The partner left before completing all agreed-upon tasks.',
    priority: 'MEDIUM',
    severity: 'MEDIUM',
    requiresEvidence: true,
    allowOptionalEvidence: true,
    maxEvidenceCount: 5,
    recommendedAction: 'Review incomplete work photos; schedule partner return or adjust invoice amount.',
    requiresAdminReview: true,
    requiresBooking: true,
    connectsToRefund: true,
  ),
  ScenarioRule(
    scenario: 'WRONG_SERVICE',
    category: 'SERVICE',
    displayName: 'Wrong service performed',
    description: 'The service delivered was different from what was booked.',
    priority: 'MEDIUM',
    severity: 'MEDIUM',
    requiresEvidence: true,
    allowOptionalEvidence: true,
    maxEvidenceCount: 5,
    recommendedAction: 'Verify booked service vs delivered work; adjust billing or dispatch correct service.',
    requiresAdminReview: true,
    requiresBooking: true,
    connectsToRefund: true,
  ),
  ScenarioRule(
    scenario: 'PROPERTY_DAMAGE',
    category: 'SAFETY',
    displayName: 'Property damage occurred',
    description: 'Household property, appliance, or item was damaged during the service.',
    priority: 'HIGH',
    severity: 'CRITICAL',
    requiresEvidence: true,
    allowOptionalEvidence: true,
    maxEvidenceCount: 5,
    recommendedAction: 'Immediate incident investigation; review damage photos and initiate claim protocol.',
    requiresAdminReview: true,
    requiresBooking: true,
    connectsToRefund: true,
  ),
  ScenarioRule(
    scenario: 'MISSING_ITEM',
    category: 'SAFETY',
    displayName: 'Missing or misplaced personal item',
    description: 'An item is missing following the partner\'s service visit.',
    priority: 'HIGH',
    severity: 'CRITICAL',
    requiresEvidence: true,
    allowOptionalEvidence: true,
    maxEvidenceCount: 5,
    recommendedAction: 'Escalate to Trust & Safety team; initiate formal security inquiry and partner interview.',
    requiresAdminReview: true,
    requiresBooking: true,
    connectsToRefund: false,
  ),
  ScenarioRule(
    scenario: 'SAFETY_CONCERN',
    category: 'SAFETY',
    displayName: 'Safety or security concern',
    description: 'Customer feels unsafe or reports a security violation.',
    priority: 'URGENT',
    severity: 'CRITICAL',
    requiresEvidence: false,
    allowOptionalEvidence: true,
    maxEvidenceCount: 5,
    recommendedAction: 'Execute urgent safety escalation protocol; direct call to customer immediately.',
    requiresAdminReview: true,
    requiresBooking: true,
    connectsToRefund: false,
  ),
  ScenarioRule(
    scenario: 'PAYMENT_CHARGED_INCORRECTLY',
    category: 'PAYMENT',
    displayName: 'Charged incorrect amount or overcharged',
    description: 'The amount deducted does not match the booking total or was billed multiple times.',
    priority: 'HIGH',
    severity: 'HIGH',
    requiresEvidence: false,
    allowOptionalEvidence: true,
    maxEvidenceCount: 3,
    recommendedAction: 'Reconcile payment gateway transaction logs against booking charges; issue refund difference.',
    requiresAdminReview: true,
    requiresBooking: true,
    connectsToRefund: true,
  ),
  ScenarioRule(
    scenario: 'REFUND_NOT_RECEIVED',
    category: 'PAYMENT',
    displayName: 'Refund not received',
    description: 'A promised or approved refund has not reflected in the bank or original payment method.',
    priority: 'MEDIUM',
    severity: 'MEDIUM',
    requiresEvidence: false,
    allowOptionalEvidence: false,
    maxEvidenceCount: 3,
    recommendedAction: 'Check existing ReturnRequest / refund transaction status with payment gateway.',
    requiresAdminReview: true,
    requiresBooking: true,
    connectsToRefund: true,
  ),
  ScenarioRule(
    scenario: 'BOOKING_PROBLEM',
    category: 'BOOKING',
    displayName: 'Issue with booking or scheduling',
    description: 'Unable to modify, reschedule, or find information regarding an active booking.',
    priority: 'MEDIUM',
    severity: 'LOW',
    requiresEvidence: false,
    allowOptionalEvidence: true,
    maxEvidenceCount: 3,
    recommendedAction: 'Check booking timeline, partner assignment status, and slot availability.',
    requiresAdminReview: false,
    requiresBooking: true,
    connectsToRefund: false,
  ),
  ScenarioRule(
    scenario: 'PARTNER_CANCELLATION',
    category: 'BOOKING',
    displayName: 'Partner cancelled the booking',
    description: 'The assigned partner cancelled unexpectedly before or near the service time.',
    priority: 'HIGH',
    severity: 'HIGH',
    requiresEvidence: false,
    allowOptionalEvidence: false,
    maxEvidenceCount: 3,
    recommendedAction: 'Check partner cancellation reason; offer instant rebooking or complete refund.',
    requiresAdminReview: true,
    requiresBooking: true,
    connectsToRefund: true,
  ),
  ScenarioRule(
    scenario: 'APP_TECHNICAL_ISSUE',
    category: 'TECHNICAL',
    displayName: 'App technical problem or bug',
    description: 'Encountered a crash, error, or UI glitch while using the MaidItQuick app.',
    priority: 'LOW',
    severity: 'LOW',
    requiresEvidence: false,
    allowOptionalEvidence: true,
    maxEvidenceCount: 5,
    recommendedAction: 'Log app platform details; forward bug report to mobile engineering team.',
    requiresAdminReview: false,
    requiresBooking: false,
    connectsToRefund: false,
  ),
  ScenarioRule(
    scenario: 'ACCOUNT_PROFILE_ISSUE',
    category: 'ACCOUNT',
    displayName: 'Account, login, or profile issue',
    description: 'Difficulty updating profile info, phone number, saved addresses, or signing in.',
    priority: 'LOW',
    severity: 'LOW',
    requiresEvidence: false,
    allowOptionalEvidence: true,
    maxEvidenceCount: 3,
    recommendedAction: 'Assist customer with profile verification, phone update, or credential reset.',
    requiresAdminReview: false,
    requiresBooking: false,
    connectsToRefund: false,
  ),
  ScenarioRule(
    scenario: 'ADDRESS_LOCATION_ISSUE',
    category: 'BOOKING',
    displayName: 'Address or service location issue',
    description: 'Incorrect pin location, unserviceable pin code, or partner lost en-route.',
    priority: 'LOW',
    severity: 'LOW',
    requiresEvidence: false,
    allowOptionalEvidence: true,
    maxEvidenceCount: 3,
    recommendedAction: 'Verify geocoded address coordinates and update service location details.',
    requiresAdminReview: false,
    requiresBooking: false,
    connectsToRefund: false,
  ),
  ScenarioRule(
    scenario: 'EMERGENCY_URGENT',
    category: 'SAFETY',
    displayName: 'Emergency / Immediate danger',
    description: 'Active emergency requiring prompt platform and emergency response intervention.',
    priority: 'URGENT',
    severity: 'CRITICAL',
    requiresEvidence: false,
    allowOptionalEvidence: true,
    maxEvidenceCount: 5,
    recommendedAction: 'Trigger high-priority emergency escalation; customer safety dispatch and immediate callback.',
    requiresAdminReview: true,
    requiresBooking: false,
    connectsToRefund: false,
  ),
  ScenarioRule(
    scenario: 'OTHER',
    category: 'OTHER',
    displayName: 'Other question or issue',
    description: 'General question, feedback, or issue not covered by the categories above.',
    priority: 'MEDIUM',
    severity: 'LOW',
    requiresEvidence: false,
    allowOptionalEvidence: true,
    maxEvidenceCount: 5,
    recommendedAction: 'Review customer request details and route to relevant support agent.',
    requiresAdminReview: true,
    requiresBooking: false,
    connectsToRefund: false,
  ),
];

/// Wraps the mobile support-ticket endpoints so screens never hardcode API
/// paths or token plumbing.
class SupportRepository {
  SupportRepository(this._api);

  final ApiClient _api;

  Future<List<ScenarioRule>> fetchScenarios() async {
    try {
      final payload = await _api.get('/support/scenarios');
      if (payload is List) {
        return payload
            .whereType<Map>()
            .map((item) => ScenarioRule.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    } catch (_) {
      // Fallback if offline
    }
    return kDefaultScenarios;
  }

  Future<String> uploadEvidence(String token, Uint8List bytes, String fileName) async {
    final ext = fileName.split('.').last.toLowerCase();
    final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
    final payload = await _api.multipartPost(
      '/support/evidence',
      token: token,
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
      fileField: 'file',
    );
    if (payload is Map && payload['url'] != null) {
      return payload['url'].toString();
    }
    throw ApiException('Invalid response from evidence upload', 500);
  }

  Future<List<Map<String, dynamic>>> fetchMyTickets(String token) async {
    final payload = await _api.get('/support/tickets/mine', token: token);
    if (payload is List) {
      return payload
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> createTicket(
    String token, {
    required String subject,
    required String message,
    String? category,
    int? bookingId,
    String? scenario,
    List<String>? evidenceUrls,
  }) async {
    final payload = await _api.post(
      '/support/tickets',
      {
        'subject': subject.trim(),
        'message': message.trim(),
        if (category != null && category.trim().isNotEmpty)
          'category': category.trim(),
        if (bookingId != null) 'bookingId': bookingId,
        if (scenario != null && scenario.trim().isNotEmpty)
          'scenario': scenario.trim(),
        if (evidenceUrls != null && evidenceUrls.isNotEmpty)
          'evidenceUrls': evidenceUrls,
      },
      token: token,
    );
    return payload is Map
        ? Map<String, dynamic>.from(payload)
        : <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> fetchMessages(
      String token, String ticketId) async {
    final payload = await _api.get('/support/tickets/$ticketId/messages', token: token);
    return payload is List
        ? payload.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
        : <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> sendMessage(
      String token, String ticketId, String message) async {
    final payload = await _api.post('/support/tickets/$ticketId/messages',
        {'message': message.trim()}, token: token);
    return payload is Map ? Map<String, dynamic>.from(payload) : <String, dynamic>{};
  }
}
