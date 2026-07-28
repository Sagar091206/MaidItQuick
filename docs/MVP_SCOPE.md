# MaidItQuick MVP scope — locked for development

## Product goal

Launch a mobile-first home-services MVP for the Kolkata / Hooghly launch area. Customers request a service, an approved worker is assigned, and the job moves through a simple, auditable lifecycle.

## Included modules

| Module | MVP capability |
|---|---|
| Customer app | Register/login, choose PIN and saved address, browse enabled services, see availability, request a booking, track/cancel a booking, in-app notifications and support ticket |
| Worker app | Login, availability toggle, assigned jobs, on-the-way/start/complete statuses, location sharing while available |
| Admin operations | Login, service catalog, service areas/PINs, worker approval, booking assignment, SLA/refund review, customer account view |
| Backend | Java REST API, MySQL persistence, role-based authentication, audit-friendly booking state transitions |

## Explicitly out of scope for MVP

- Payment gateway and automated refunds/payouts
- SMS, WhatsApp, production email, and Firebase push delivery
- Background-check vendor integration
- Automated KYC verification and cloud document storage
- Continuous background GPS tracking and route optimisation
- iOS/Android store release, production hosting, monitoring and analytics

## MVP acceptance flow

1. Customer registers, chooses an enabled PIN, sees service availability, and requests a service.
2. Admin sees the requested job and assigns an approved available worker.
3. Worker accepts the job, marks on-the-way, starts with customer OTP, and completes with customer OTP.
4. Customer receives in-app updates, can cancel before worker travel, and may rate the completed job.

## Technology decision — locked

- Mobile frontend: **Flutter (Dart)**
- Backend: **Java 21 + Spring Boot**
- Database: **MySQL + JPA/Hibernate**
- API style: REST over HTTPS

## Non-negotiable engineering rules

- Flutter app is the source of truth for customer, worker and admin mobile experiences.
- The existing HTML portal remains a development/admin prototype only; it is not the final mobile frontend.
- Backend API contracts are versioned under `/api` and shared with Flutter through typed repositories.
- Do not add modules outside this document without a written scope change.
