# MaidItQuick product requirements document

## Roles

| Role | Primary job |
|---|---|
| Customer | Request and manage a home service |
| Worker | Make availability known and execute assigned jobs |
| Admin | Configure launch area, services, workers and dispatch |

## Core entities

User, Service, Service Area, Saved Address, Booking, Worker Profile, Notification, Support Ticket, Refund Request.

## Booking states

`REQUESTED → ASSIGNED → ON_THE_WAY → IN_PROGRESS → COMPLETED`

`CANCELLED` is allowed only before `ON_THE_WAY` for customers. Admins handle exceptions.

## Key API groups

- `/api/auth` — registration, login, password reset
- `/api/services` — customer catalog and admin service management
- `/api/availability` — availability for a PIN code
- `/api/bookings` — booking lifecycle
- `/api/workers` — worker profile, availability, KYC and location
- `/api/operations` — service areas, SLA alerts and refunds
- `/api/notifications` — notification inbox and preferences

## Release criteria for MVP demo

- Flutter app runs on Android emulator/device.
- Java API runs against local MySQL.
- Customer, worker and admin demo accounts complete the acceptance flow in `MVP_SCOPE.md`.
- All critical API and Flutter tests pass.
- No payment or external delivery provider is claimed as implemented.
