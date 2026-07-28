# MaidItQuick mobile frontend

Flutter boilerplate for the final Android and iOS application.

## Architecture

Feature-first folders with Flutter's recommended separation of views, view models, repositories and services:

```text
lib/
  core/                 API configuration and shared infrastructure
  features/
    auth/               Login and session
    booking/            Service catalog and booking flow
    home/               Role-aware home screen
  shared/widgets/       Reusable UI components
```

## Setup

1. Install the Flutter SDK and Android Studio.
2. Run `flutter pub get` in this folder.
3. Start the Java API.
4. For Android emulator use `http://10.0.2.2:8080/api` as the API base URL; for a real phone use the deployed HTTPS API URL.
5. Run `flutter run`.

The current machine does not have Flutter installed, so this boilerplate is intentionally not generated or built until the Flutter SDK is available.
