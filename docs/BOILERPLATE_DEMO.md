# 2 PM boilerplate demo — MaidItQuick

## Open these folders

1. **VS Code**: `maiditquick-mobile`
2. **IntelliJ IDEA**: `makeitquick-server`
3. **Scope document**: `docs/MVP_SCOPE.md`
4. **Requirements document**: `docs/PRODUCT_REQUIREMENTS.md`

## What to say

> We have frozen the MVP scope. The final customer, worker and admin frontend will be a Flutter mobile app with one Dart codebase for Android and iOS. The backend is Java 21 Spring Boot with MySQL. The HTML portal is only a prototype and API test harness; it is not the final mobile frontend.

## Show frontend first

```text
maiditquick-mobile/
  lib/
    core/                 API client and environment configuration
    features/
      auth/               login/session module
      booking/            booking module placeholder
      home/               first mobile screen
    shared/               reusable widgets
  test/                   Flutter widget tests
  pubspec.yaml            dependency lock point
```

Explain the rule: every feature will have views, view-model/state, repository and API service boundaries. No module is added without first changing the PRD.

## Show backend next

```text
makeitquick-server/
  src/main/java/com/makeitquick/
    security/             authentication and role controls
    booking/              booking lifecycle
    worker/               worker onboarding/availability
    operations/           PINs, dispatch, SLA and refunds
    catalog/              enabled services
  src/main/resources/
    application.yml       environment-based configuration
```

## MVP module list to lock

- Authentication
- Customer booking
- Worker job execution
- Admin dispatch
- Service/PIN configuration
- In-app notifications/support

## Do not discuss as MVP features

- Payments
- SMS/WhatsApp/email provider
- Firebase push
- Background checks/payout vendor
- Full GPS routing
- Production deployment and Play Store release

## Commands for the demo

```powershell
# Backend, from makeitquick-server
mvn spring-boot:run

# Flutter, after Flutter SDK installation, from maiditquick-mobile
flutter pub get
flutter run
flutter test
```
