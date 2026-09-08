# Solveig Identity App

Flutter reference client for [solveig-api-platform](https://github.com/manishpareekwork/solveig-api-platform) `/v1` APIs.

## User flow

1. **API Setup** — connect with admin token (auto-registers mobile client) or existing client credentials
2. **Create identity** — `POST /v1/identities`
3. **Enroll face** — camera capture → `POST /v1/face/enrollments`
4. **Show QR** — `POST /v1/qr/references` (opaque token, no PII)
5. **Start verification** — `POST /v1/verification-sessions`
6. **Capture & verify** — face 1:1 + liveness checks on same capture
7. **Result** — session status and per-check outcomes

Default development API: `https://solveig-identity-api-dev.onrender.com`

## Auto-connect (skip API Setup)

Copy `secrets.json.example` → `secrets.json` (gitignored) and set either:

- `IDENTITY_ADMIN_TOKEN` — app auto-registers a client on launch, or
- `SOLVEIG_CLIENT_ID` + `SOLVEIG_CLIENT_KEY` + `SOLVEIG_CLIENT_SECRET` — reuses existing client

Run with secrets injected at compile time:

```bash
flutter run --dart-define-from-file=secrets.json
# or
./scripts/flutter-run.sh
```

On success the app opens directly on **Create identity** (no manual Connect step). Credentials are persisted in SharedPreferences for subsequent launches.

Test API: `./scripts/test-api.sh` (health always; full flow if `secrets.json` present).

## Prerequisites

- Flutter 3.11+ / Dart 3.11+
- Android SDK for APK builds
- Render **IDENTITY_ADMIN_TOKEN** (from Render dashboard secrets — not committed)

## Run (debug)

**Projects on `/Volumes/` (exFAT):** macOS writes `._*` AppleDouble files during Gradle builds, causing errors like `._drawable-v21 is not a directory`. Build from an APFS cache on your system disk:

```bash
./scripts/flutter-run.sh
```

This rsyncs to `~/Library/Caches/solveig-identity-app-build` and runs `flutter run` there. Keep **~8 GB free** on your system disk (`df -h /`).

For release APK: `./scripts/build-apk.sh` (copies APK back to `build/app/outputs/flutter-apk/`).

## Build release APK

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk` (~50 MB)

**macOS JDK:** If Gradle fails with `25.0.2`, Android Studio’s Java 25 is incompatible with current Kotlin. Use Java 17–23:

```bash
export JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk-23.jdk/Contents/Home"
flutter config --jdk-dir="$JAVA_HOME"
```

**External volume:** On exFAT/network drives, macOS `._*` metadata can break Gradle (`._xml is not a directory`). Use the helper script:

```bash
./scripts/build-apk.sh
```

This rsyncs to `/tmp`, builds there, and copies the APK back.

Install: `adb install -r build/app/outputs/flutter-apk/app-release.apk`

## First-time setup in app

1. Open app → **API Setup**
2. Enter API base URL and tenant slug (`demo-tenant` works for new clients)
3. Paste **IDENTITY_ADMIN_TOKEN** from Render → **Connect**
4. Complete the stepper on the home screen

## Notes

- Uses platform APIs only — no on-device SQLite or TFLite matching
- Biometric processing runs on Render (`solveig-biometric-dev`)
- For Postgres persistence, set `IDENTITY_DATABASE_URL` on Render (see platform wiki)
