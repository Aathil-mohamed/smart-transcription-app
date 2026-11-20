# smart_transcription_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Firebase Setup

This project uses Firebase for Auth, Firestore, and Storage. To ensure the
app connects on all platforms:

- Android: `android/app/google-services.json` is included (ensure its values
	match your Firebase console project). The Gradle files are configured to
	apply the Google Services plugin.
- iOS: add your `GoogleService-Info.plist` to `ios/Runner` and re-run the app.
- Web/Desktop: generate `lib/firebase_options.dart` using the FlutterFire CLI:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

After adding platform files, run:

```bash
flutter pub get
flutter run -d chrome   # or -d windows or an Android device
```

If you want, I can try generating `firebase_options.dart` here (requires the
FlutterFire CLI) or run the app on an available device to verify connectivity.
