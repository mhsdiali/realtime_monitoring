# AGENTS.md

## Current state
- Flutter app, **Android only** (no `ios/` directory). Green baseline: `flutter analyze`, `flutter test`, and `flutter build apk --debug` pass (first build is slow).
- M0 is done. Firebase uses project `monitoring-sppg-81246` (PRD §4 matches); config lives in `lib/firebase_options.dart`, `android/app/google-services.json`, and `firebase.json`.
- M1 is done: email/password login is verified on the Pixel 8 emulator; logout and session gate are widget-tested with a fake repository. `firebase_auth` is wired.
- M2 is done: the dashboard displays `monitoring/latest` and `tools/simulator/simulator.mjs` writes changing values every 5s via the device account (verified on screen in the Pixel 8 emulator).
- M3 is done: the dashboard reads `devices/status/last_seen`, uses `.info/serverTimeOffset`, re-evaluates every 5s, and shows offline + stale-data copy after 30s without updates (verified by stopping the simulator).
- M4 is done: bottom navigation has Beranda/Riwayat/Kontrol AC/Pengaturan. Riwayat reads `monitoring/history` by key range and renders `fl_chart` temperature/humidity charts plus a value list for 6h/24h/7d (verified on the Pixel 8 emulator).
- M5 is done: Pengaturan edits `thresholds` with app-side validation and confirmation; defaults are 16–20 °C and 40–60%, saved by the petugas (verified on the Pixel 8 emulator, values present in RTDB).
- M6 is done: Kontrol AC writes `devices/ac_control/commands` (`turn_on`/`turn_off`/`set_temperature`, setpoint 16–30 °C), waits 5s for a `transmitted` ack, disables controls while offline, and keeps stale commands for the device to execute on reconnect (verified end-to-end on the Pixel 8 emulator).
- M7 client side is implemented: FCM permission/channel, token storage in `fcm_tokens/{uid}`, local notification when the app is foreground, tap routing to Beranda, and token removal on logout (token save/removal verified on the emulator).
- M7 is **not complete**: the notification worker now lives in the separate private repo `realtime_monitoring` (local copy at `../worker_notifications`) with Node unit tests, but it has not been deployed to the VPS. Cloud Functions are not used; the project stays Spark and notifications are sent by the VPS worker.
- Android `applicationId` / namespace is `id.sppg.monitoring`; `MainActivity` is under `android/app/src/main/kotlin/id/sppg/monitoring/`.
- `lib/main.dart` bootstraps Firebase and `lib/app.dart` hosts the app. `AuthGate` shows `LoginPage` or `HomeShell`; widget tests inject fake auth, monitoring, history, threshold, and AC repositories and never touch Firebase.
- Dependencies so far: `firebase_core`, `firebase_auth`, `firebase_database`, `firebase_messaging`, `flutter_local_notifications`, and `fl_chart`. No state-management package yet.
- `PRD.md` (Indonesian) is the product source of truth: RTDB data contract (§5), functional requirements (§6), milestones (§10), and open questions (§13).

## PRD rules that change how you work
- Implement milestones M0–M8 in order (§10); do not start the next milestone until the current one meets its "Selesai bila" criteria.
- Never invent values tagged `[PERLU DIKONFIRMASI]` (§13), and don't silently override `[KEPUTUSAN]` decisions; ask the user.
- Feature-first `lib/` is in use: `features/auth/` (repository, gate, login), `features/dashboard/` (latest reading + online/offline UI, `device_status.dart`), `features/history/` (charts + list), `features/thresholds/` (settings form + repository), `features/ac_control/` (commands + ack listener), `features/notifications/` (FCM service + token repository), `features/home/` (bottom-nav shell), and `core/time/` (WIB formatting). Alert status is not displayed on the dashboard yet.
- All UI text is Indonesian; timestamps display in WIB. `active_parameters` is a list but RTDB omits empty arrays — treat a missing node as empty.
- AC control copy must say the IR signal was "dipancarkan", never that the AC changed state.

## Commands (repo root)
- `flutter pub get`
- `flutter analyze` — lint + typecheck gate (`flutter_lints` via `analysis_options.yaml`)
- `flutter test` — full suite; single test: `flutter test test/widget_test.dart` or `flutter test --plain-name "<test name>"`
- `flutter devices` then `flutter run -d <device-id>`; Android build: `flutter build apk --debug`
- No Makefile, task runner, CI, or pre-commit config. Directory is not a git repo.

## Firebase / test prerequisites
- The Android app is already registered in Firebase; do not register it again. Reconfigure with `flutterfire configure --project=monitoring-sppg-81246 --platforms=android --android-package-name=id.sppg.monitoring` (CLI at `~/.pub-cache/bin/flutterfire`, not on PATH).
- Firebase CLI is installed and logged in; `firebase projects:list` shows both `monitoring-sppg-81246` and the older `monitoring-suhu-gudang-b64c4`.
- PRD §9 was updated: the client uses the real Firebase project on the Pixel 8 emulator, not the Emulator Suite. FCM must still be verified on an Android device/emulator with Play services.
- Email/password sign-in is enabled; petugas accounts must be created manually in Firebase Console (self-registration is disabled by decision).
- RTDB default instance is `monitoring-sppg-81246-default-rtdb` in `asia-southeast1`; `databaseURL` is in `lib/firebase_options.dart`.
- `database.rules.json` follows PRD §8 and is deployed with the device account UID (`perangkat1@example.com`); it grants petugas read and device write for `devices/status/last_seen`, petugas read/write for `thresholds` with numeric range validation, petugas write/read for `ac_control/commands`, device write/read for `ac_control/acknowledgements`, owner read/write for `fcm_tokens/{uid}`, and read-only `alert_state` for petugas. Redeploy with `firebase deploy --only database` after rule changes.
- Device simulator: `DRY_RUN=1 DEVICE_EMAIL=... DEVICE_PASSWORD=... node tools/simulator/simulator.mjs` prints the device UID without writing; drop `DRY_RUN` to write `monitoring/latest`, `devices/status/last_seen`, and history every 30min every 5s, and to ack pending AC commands every second (`ACK_POLL_MS`). For quick history tests, set `HISTORY_INTERVAL_MS=5000`.
- A zsh function `Simulator` in `~/.zshrc` wraps the simulator command, prompts for the device password, and also accepts the phrase `Simulator ESP run`; `DRY_RUN=1 Simulator` is the no-write check.
- Notification worker: separate private repo, local copy at `../worker_notifications`. Run `cd ../worker_notifications && node --test` for logic tests. Running it needs `GOOGLE_APPLICATION_CREDENTIALS` pointing to a service-account JSON and `DATABASE_URL`; never put that JSON in the repo. The VPS systemd template is `deploy/app-monitoring-notifier.service` in that worker repo.
- FCM test messages can be sent from Firebase Console to the token stored in `fcm_tokens`; the emulator uses the Play Store image and has Google Play services.
- `android/local.properties` is machine-local (gitignored) and pins the Flutter SDK path.

## Toolchain quirks
- Flutter 3.44.4 stable, Dart SDK `^3.12.2`. Template code uses Dart dot shorthands (`.fromSeed`, `.center`); keep that style.
- Android build is Kotlin DSL with AGP 9.0.1, Kotlin 2.3.20, Java 17, and google-services 4.4.4. Build output lands in repo-root `build/`, not `android/build/` (see `android/build.gradle.kts`).
- The build warns that Firebase plugins still apply KGP; it is a warning, not a failure.
- `sdkmanager` fails without a JDK on PATH; use `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"`. Flutter requires NDK `28.2.13676358`; a partial download breaks the build with `CXX1101`, fix by reinstalling that NDK.
- `flutter_local_notifications` is pinned to `^22.3.3`; 23.x requires compileSdk 37, which the installed SDK does not provide. The app enables core library desugaring and multiDex in `android/app/build.gradle.kts`; removing either breaks the Android build.
- Emulator `Pixel_8` exists (run `flutter emulators --launch Pixel_8`); `adb` is at `~/Library/Android/sdk/platform-tools/adb`, not on PATH. The AVD uses the Play Store system image (FCM works).
- Runtime deps are `firebase_core`, `firebase_auth`, `firebase_database`, `firebase_messaging`, `flutter_local_notifications`, `fl_chart`, and `cupertino_icons`, plus `flutter_lints`; `flutter.uses-material-design` is enabled.
