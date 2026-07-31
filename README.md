# MaidItQuick

## Interfaces

- `mobile/` — customer and worker mobile application
- `web-prototype/` — customer-facing web prototype
- `admin-web/` — administrator web application
- `server/` — shared MySQL API and domain model for all interfaces

The admin client intentionally uses the existing `ADMIN` user role and `/api/admin/**` endpoints. It does not run a separate PostgreSQL service or duplicate customer/worker tables.
MaidItQuick is a home-services MVP for customers and maid partners. This repository contains the mobile app, backend API, project documents, and the earlier web prototype.

## Repository layout

- `mobile/` — Flutter mobile app for Android and iOS.
- `server/` — Java 21 / Spring Boot backend with MySQL via JPA/Hibernate.
- `docs/` — MVP scope, product requirements, brand guide, and user journeys.
- `web-prototype/` — HTML/CSS/JavaScript prototype retained as a design and operations reference.

## Run locally

### Backend

1. Copy `server/.env.example` to `server/.env` and enter local MySQL credentials.
2. From `server/`, run `mvn spring-boot:run` (or `./run-local.ps1` after dependencies have been built locally).
3. API health check: `http://localhost:8080/api/health`.
4. API documentation: `http://localhost:8080/swagger-ui/index.html`.

### Mobile app

1. Install Flutter and Android Studio.
2. Start the backend, then open `mobile/` in Android Studio.
3. Run `flutter pub get` and select an Android emulator or device.
4. Run the app with `flutter run`.

For an Android emulator, the API base address should use `http://10.0.2.2:8080` rather than `localhost`.

## Important

Never commit `server/.env`, passwords, API keys, KYC uploads, or generated Android builds. The provided `.env.example` is safe to share and documents the required configuration.
