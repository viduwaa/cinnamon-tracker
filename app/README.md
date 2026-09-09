# Cinnamon Trace — mobile app

Offline-first Flutter app for farm-to-export cinnamon batch traceability.

## Setup

```sh
cp env.example.json env.json   # then fill in MAPS_API_KEY
flutter pub get
```

`env.json` is gitignored. It holds build-time config injected via
`--dart-define-from-file`:

| Key               | Purpose                                   | Default without file |
|-------------------|-------------------------------------------|----------------------|
| `API_BASE_URL`    | Backend REST base                         | prod URL (hardcoded) |
| `VERIFY_BASE_URL` | Public QR verify page base                | prod URL (hardcoded) |
| `MAPS_API_KEY`    | Google Maps SDK for Android (farm picker) | empty → picker shows "disabled" card |

## Run

- **VS Code**: press F5 — `.vscode/launch.json` already passes `env.json`.
- **Terminal**: `flutter run --dart-define-from-file=env.json`
- **Build**: `flutter build apk --dart-define-from-file=env.json`

## Google Maps key

Create an API key in Google Cloud with **Maps SDK for Android** enabled, then
restrict it (APIs & Services → Credentials → key → *Application restrictions* →
Android apps):

- Package name: `com.cinnamontrace.cinnamon_trace`
- SHA-1 (debug keystore on this machine): `B7:AD:54:52:A3:88:CC:F9:E7:79:4B:07:AB:B9:43:37:B8:51:0B:A7`
  (re-derive anytime: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`)

Release builds currently sign with the debug keystore too
(`android/app/build.gradle.kts`), so one SHA-1 covers both. When a real release
keystore is introduced, add its SHA-1 to the same key.

Because the key is restricted to this package + signature, embedding it in the
APK is safe — a copied key is useless outside our signed builds. The key
reaches Android through `dart-defines` → `manifestPlaceholders["MAPS_API_KEY"]`
(see `build.gradle.kts`) and Dart through `String.fromEnvironment` in
`lib/core/api/maps_api_key.dart`.

## Test

```sh
flutter test
```
