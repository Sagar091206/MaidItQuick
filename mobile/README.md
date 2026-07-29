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

1. Install the Flutter SDK. Install Android Studio for Android emulator testing and Xcode for iOS simulator testing.
2. Run `flutter pub get` in this folder.
3. Start the Java API.
4. The app defaults to the local API URL for each simulator:
   - Android emulator: `http://10.0.2.2:8080/api`
   - iOS simulator: `http://127.0.0.1:8080/api`
   - Real devices: pass a deployed HTTPS API URL with `--dart-define=API_BASE_URL=...`
5. Run `flutter run`.

## Simulator targets

Recommended local test devices:

- Android: Pixel 7 or Pixel 8 emulator.
- iOS: iPhone 17 Pro simulator.

```bash
flutter run -d <android-emulator-id>
flutter run -d <ios-simulator-id>
```
