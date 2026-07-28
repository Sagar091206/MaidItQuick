# MaidItQuick MVP — detailed user journeys

## 1. Customer: first booking

**Goal:** request a nearby home service.

1. Customer opens the Flutter app.
2. Customer registers with name, email and password, or logs in.
3. Customer chooses a saved address or enters an address and six-digit PIN code.
4. App calls availability API and shows one of: Available now, Available in 1 hour, or Not available today.
5. Customer selects an enabled service, option, duration and requested time.
6. Customer submits booking.
7. Backend checks customer session, service is enabled, and PIN is an active service area.
8. Booking is created as `REQUESTED`; customer sees an in-app confirmation.

**Failure cases:** inactive PIN, service hidden by admin, invalid login, or missing address/PIN. The app shows an actionable error and does not create a booking.

## 2. Admin: dispatch a booking

**Goal:** assign an eligible worker.

1. Admin logs in.
2. Admin opens live bookings / dispatch.
3. Admin sees `REQUESTED` bookings and eligible workers.
4. System only offers workers with approved KYC, approved background status and `AVAILABLE` availability.
5. Admin assigns a worker.
6. Booking changes to `ASSIGNED`.
7. Customer and worker receive in-app notifications.

**Failure cases:** no eligible worker. Admin leaves booking unassigned and follows up through operations.

## 3. Worker: execute a job

**Goal:** complete an assigned job safely.

1. Worker logs in and submits KYC if not already approved.
2. After approval, worker sets availability to `AVAILABLE`.
3. Worker receives an assigned job and opens job details.
4. Worker marks `ON_THE_WAY`.
5. Worker requests the start OTP; customer reads the OTP from their in-app notification.
6. Worker enters valid start OTP; booking changes to `IN_PROGRESS`.
7. Worker requests completion OTP after finishing the service.
8. Worker enters valid completion OTP; booking changes to `COMPLETED`.
9. Worker may share current location while available; dispatch can see it.

**Failure cases:** invalid OTP, missing KYC approval, or worker not assigned to booking. The server rejects the action.

## 4. Customer: cancel, refund and rate

**Goal:** manage a booking fairly.

1. Customer opens their booking list.
2. Customer may cancel only while booking is `REQUESTED` or `ASSIGNED`.
3. Cancellation is blocked after worker is on the way, work started, or job completed.
4. For a cancelled booking, customer can submit one refund request for admin review.
5. Admin approves/rejects the request; payment transfer is out of scope for MVP.
6. After a completed booking, customer submits a rating and optional comment.

## 5. Admin: configure launch operations

**Goal:** control service availability in the first launch area.

1. Admin opens Services and adds or hides a service.
2. Customer booking catalog displays only enabled services.
3. Admin opens Service Areas and adds a six-digit PIN and locality.
4. Admin enables or disables the area.
5. Availability endpoint uses the area status and worker availability for customer ETA messaging.

## 6. Customer/worker: support and notifications

1. User opens Notifications to read booking, security and assignment updates.
2. User manages email-notification preference; in-app notifications stay enabled.
3. User opens Support and creates a ticket.
4. Admin reviews the support queue and responds through the operations process.

## MVP boundaries

These journeys intentionally do not include payment settlement, SMS/WhatsApp, vendor background verification, automated payouts, continuous background GPS, or production push notifications. Those become post-MVP work only after the above journeys are accepted.
