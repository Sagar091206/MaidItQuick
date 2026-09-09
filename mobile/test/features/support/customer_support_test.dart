import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maiditquick_mobile/core/api_client.dart';
import 'package:maiditquick_mobile/features/auth/data/auth_repository.dart';
import 'package:maiditquick_mobile/features/profile/data/customer_profile_repository.dart';
import 'package:maiditquick_mobile/features/profile/presentation/profile_tab.dart';
import 'package:maiditquick_mobile/features/support/data/support_repository.dart';
import 'package:maiditquick_mobile/features/support/presentation/support_screen.dart';

void main() {
  const session = Session(
    token: 'cust-jwt-token',
    role: 'CUSTOMER',
    name: 'Rohan Sharma',
  );

  const profile = CustomerProfile(
    name: 'Rohan Sharma',
    phone: '9876543210',
    email: 'rohan@example.com',
    gender: 'Male',
    dob: '1995-05-15',
    profileImage: '',
    profileComplete: true,
  );

  group('Customer Support in ProfileTab', () {
    testWidgets('renders Support tile on ProfileTab with subtitle and responds to tap', (tester) async {
      bool supportOpened = false;

      final client = MockClient((request) async => http.Response('[]', 200));
      final api = ApiClient(client: client);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileTab(
              api: api,
              session: session,
              profile: profile,
              onLogout: () {},
              onOpenProfileEditor: () {},
              onOpenSettings: () {},
              onOpenSavedAddresses: () {},
              onOpenSupport: () => supportOpened = true,
            ),
          ),
        ),
      );

      expect(find.text('Support'), findsOneWidget);
      expect(find.text('Get help with your bookings or account'), findsOneWidget);
      expect(find.byIcon(Icons.support_agent_outlined), findsOneWidget);

      await tester.tap(find.text('Support'));
      await tester.pumpAndSettle();

      expect(supportOpened, isTrue);
    });
  });

  group('SupportScreen', () {
    testWidgets('renders existing customer support tickets with category and booking chips', (tester) async {
      final mockTickets = [
        {
          'id': 101,
          'subject': 'Refund for cancelled booking',
          'message': 'I have not received my refund yet',
          'reply': 'Your refund of ₹350 is processed',
          'status': 'IN_PROGRESS',
          'requester': 'Rohan Sharma',
          'requesterRole': 'CUSTOMER',
          'category': 'Payment & refund',
          'bookingId': 42,
          'createdAt': '2026-09-09T10:00:00Z',
        },
      ];

      final client = MockClient((request) async {
        if (request.url.path == '/api/support/tickets/mine') {
          return http.Response(jsonEncode(mockTickets), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('[]', 200);
      });

      final api = ApiClient(client: client);

      await tester.pumpWidget(
        MaterialApp(
          home: SupportScreen(api: api, session: session),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Support & Help'), findsOneWidget);
      expect(find.text('Refund for cancelled booking'), findsOneWidget);
      expect(find.text('Payment & refund'), findsOneWidget);
      expect(find.text('Booking #42'), findsOneWidget);
      expect(find.text('IN_PROGRESS'), findsOneWidget);
      expect(find.text('Support reply'), findsOneWidget);
      expect(find.text('Your refund of ₹350 is processed'), findsOneWidget);
    });

    testWidgets('renders empty state when customer has no support tickets', (tester) async {
      final client = MockClient((request) async {
        return http.Response('[]', 200, headers: {'content-type': 'application/json'});
      });

      final api = ApiClient(client: client);

      await tester.pumpWidget(
        MaterialApp(
          home: SupportScreen(api: api, session: session),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No support requests yet'), findsOneWidget);
      expect(find.text('Raise a request and our support team will get back to you.'), findsOneWidget);
      expect(find.text('New request'), findsOneWidget);
    });

    testWidgets('opens new support request sheet and submits ticket with category and booking', (tester) async {
      bool ticketCreated = false;

      final mockBookings = [
        {
          'id': 42,
          'service': 'Deep Cleaning',
          'scheduledFor': '2026-09-10 10:00',
        }
      ];

      final client = MockClient((request) async {
        if (request.url.path == '/api/support/tickets/mine') {
          return http.Response('[]', 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/bookings') {
          return http.Response(jsonEncode(mockBookings), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/support/tickets' && request.method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['subject'] == 'Delayed arrival' &&
              body['message'] == 'Worker was 30 mins late' &&
              body['category'] == 'Service quality') {
            ticketCreated = true;
          }
          return http.Response(jsonEncode({'id': 102, ...body, 'status': 'OPEN'}), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 200);
      });

      final api = ApiClient(client: client);

      await tester.pumpWidget(
        MaterialApp(
          home: SupportScreen(api: api, session: session, preselectedBookingId: 42),
        ),
      );

      await tester.pumpAndSettle();

      // Tap New request
      await tester.tap(find.text('New request'));
      await tester.pumpAndSettle();

      expect(find.text('New support request'), findsOneWidget);

      // Change category
      await tester.tap(find.text('General inquiry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Service quality').last);
      await tester.pumpAndSettle();

      // Enter subject and message
      await tester.enterText(find.widgetWithText(TextFormField, 'Subject'), 'Delayed arrival');
      await tester.enterText(find.widgetWithText(TextFormField, 'Describe the issue'), 'Worker was 30 mins late');

      // Submit
      await tester.ensureVisible(find.text('Submit request'));
      await tester.tap(find.text('Submit request'));
      await tester.pumpAndSettle();

      expect(ticketCreated, isTrue);
    });

    testWidgets('enforces photographic evidence when scenario requires evidence', (tester) async {
      final mockScenarios = [
        {
          'scenario': 'OTHER',
          'category': 'OTHER',
          'displayName': 'Other question or issue',
          'description': 'Other',
          'priority': 'MEDIUM',
          'severity': 'LOW',
          'requiresEvidence': false,
          'allowOptionalEvidence': true,
          'maxEvidenceCount': 5,
          'recommendedAction': 'Review request',
          'requiresAdminReview': false,
          'requiresBooking': false,
          'connectsToRefund': false,
        },
        {
          'scenario': 'PROPERTY_DAMAGE',
          'category': 'SAFETY',
          'displayName': 'Property damage occurred',
          'description': 'Damage occurred during service',
          'priority': 'HIGH',
          'severity': 'CRITICAL',
          'requiresEvidence': true,
          'allowOptionalEvidence': true,
          'maxEvidenceCount': 5,
          'recommendedAction': 'Investigate damage',
          'requiresAdminReview': true,
          'requiresBooking': true,
          'connectsToRefund': true,
        },
      ];

      final client = MockClient((request) async {
        if (request.url.path == '/api/support/tickets/mine') {
          return http.Response('[]', 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/bookings') {
          return http.Response('[{"id": 42, "service": "Deep Cleaning"}]', 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/support/scenarios') {
          return http.Response(jsonEncode(mockScenarios), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 200);
      });

      final api = ApiClient(client: client);

      await tester.pumpWidget(
        MaterialApp(
          home: SupportScreen(api: api, session: session, preselectedBookingId: 42),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('New request'));
      await tester.pumpAndSettle();

      // Select Property damage occurred
      await tester.tap(find.text('Other question or issue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Property damage occurred').last);
      await tester.pumpAndSettle();

      expect(find.text('Photographic Evidence (REQUIRED)'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Gallery'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Describe the issue'), 'Tile was chipped during floor cleaning');

      // Attempt to submit without adding evidence photos
      await tester.ensureVisible(find.text('Submit request'));
      await tester.tap(find.text('Submit request'));
      await tester.pumpAndSettle();

      // Sheet should remain open because required evidence is missing
      expect(find.text('New support request'), findsOneWidget);
      expect(find.text('At least 1 photo is required before submitting.'), findsOneWidget);
    });

    testWidgets('SupportConversationScreen renders messages and sends user reply', (tester) async {
      bool messageSent = false;
      final mockTicket = {
        'id': 105,
        'subject': 'Billing question',
        'message': 'Why was I charged ₹50 extra?',
        'reply': '',
        'status': 'OPEN',
        'requester': 'Rohan Sharma',
        'requesterRole': 'CUSTOMER',
        'createdAt': '2026-09-09T11:00:00Z',
      };

      final client = MockClient((request) async {
        if (request.url.path == '/api/support/tickets/105/messages' && request.method == 'GET') {
          return http.Response(jsonEncode([
            {
              'id': 1,
              'senderRole': 'ADMIN',
              'message': 'That was the peak hour surcharge.',
              'createdAt': '2026-09-09T11:05:00Z',
            }
          ]), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/support/tickets/105/messages' && request.method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['message'] == 'Understood, thanks!') {
            messageSent = true;
          }
          return http.Response(jsonEncode({'id': 2, 'senderRole': 'CUSTOMER', ...body}), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('[]', 200);
      });

      final api = ApiClient(client: client);
      final repo = SupportRepository(api);

      await tester.pumpWidget(
        MaterialApp(
          home: SupportConversationScreen(
            repository: repo,
            session: session,
            ticket: mockTicket,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Ticket #105'), findsOneWidget);
      expect(find.text('Why was I charged ₹50 extra?'), findsOneWidget);
      expect(find.text('That was the peak hour surcharge.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Understood, thanks!');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(messageSent, isTrue);
    });

    testWidgets('SupportConversationScreen renders priority, recommendation, refund banner, and evidence gallery', (tester) async {
      final mockTicket = {
        'id': 108,
        'subject': 'Property damage during cleaning',
        'message': 'Floor tiles were cracked by equipment',
        'reply': 'Our team is reviewing the claim',
        'status': 'IN_REVIEW',
        'requester': 'Rohan Sharma',
        'requesterRole': 'CUSTOMER',
        'category': 'SAFETY',
        'bookingId': 77,
        'scenario': 'PROPERTY_DAMAGE',
        'priority': 'HIGH',
        'recommendedAction': 'Immediate incident investigation; review damage photos and initiate claim protocol.',
        'connectsToRefund': true,
        'refundInfo': {
          'id': 15,
          'status': 'REQUESTED',
          'requestedAmount': 500.0,
        },
        'evidenceUrls': '/uploads/support/photo1.jpg,/uploads/support/photo2.jpg',
        'createdAt': '2026-09-09T11:00:00Z',
      };

      final client = MockClient((request) async {
        return http.Response('[]', 200, headers: {'content-type': 'application/json'});
      });

      final api = ApiClient(client: client);
      final repo = SupportRepository(api);

      await tester.pumpWidget(
        MaterialApp(
          home: SupportConversationScreen(
            repository: repo,
            session: session,
            ticket: mockTicket,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Ticket #108'), findsOneWidget);
      expect(find.text('HIGH'), findsOneWidget);
      expect(find.text('• PROPERTY DAMAGE'), findsOneWidget);
      expect(find.text('• Booking #77'), findsOneWidget);
      expect(find.text('Immediate incident investigation; review damage photos and initiate claim protocol.'), findsOneWidget);
      expect(find.text('Linked Refund #15 (REQUESTED)'), findsOneWidget);
      expect(find.text('Evidence Photos (2)'), findsOneWidget);
    });
  });
}
