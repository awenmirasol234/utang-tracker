# Developer Setup — Utang Tracker

Single canonical onboarding doc. If it is not here, it is not required to run or build the app. For the data spec see [`rules/database_rules.md`](../rules/database_rules.md); for the project overview see [`README.md`](../README.md).

> Android-only Flutter app. iOS / web / desktop are not supported — intentionally out of scope.

---

## 1. Prerequisites

| Requirement | Version / Value | Notes |
|---|---|---|
| **Flutter** | `3.44.0` stable | `flutter --version` must show `3.44.0` |
| **Dart SDK** | `^3.12.0` | Bundled with Flutter 3.44.0 (`Dart 3.12.0`) |
| **Android Gradle Plugin (AGP)** | `9.0.1` | `android/settings.gradle.kts:22` |
| **Kotlin** | `2.3.20` | `android/settings.gradle.kts:23` |
| **JDK** | `17` | `JavaVersion.VERSION_17` in `android/app/build.gradle.kts:30-31`, `JvmTarget.JVM_17` at line 74 |
| **compileSdk** | `36` | `android/app/build.gradle.kts:26` |
| **Android Studio** | Ladybug or newer with SDK 36 installed | Must include `Android SDK Platform 36` + `Google Play services` |
| **Platform** | Android only | `applicationId = com.example.utang_tracker`, `namespace = com.example.utang_tracker` |
| **OS for build** | Windows / macOS / Linux with Android SDK | Debug keystore path in this repo: `~/.android/debug.keystore` (Windows: `%USERPROFILE%\.android\debug.keystore`) |

Verify after install:

```sh
flutter --version   # Flutter 3.44.0 • Dart 3.12.0
java -version       # 17.x
flutter doctor      # Android toolchain must be green
```

---

## 2. Environment Setup

1. **Install Flutter 3.44.0** from <https://docs.flutter.dev/get-started/install> and add `flutter` to `PATH`.
2. **Install Android Studio** and via SDK Manager install `Android SDK Platform 36`, `Android SDK Build-Tools`, `Google Play services`.
3. **Accept licenses:**
   ```sh
   flutter doctor --android-licenses
   ```
4. **Set `local.properties` (auto-generated, do not commit):**
   `android/local.properties` must contain:
   ```properties
   sdk.dir=C:\\Users\\<you>\\AppData\\Local\\Android\\sdk
   flutter.sdk=C:\\flutter
   ```
   `flutter pub get` / `flutter run` regenerates `flutter.versionName` / `flutter.versionCode` there.
5. **Clone and fetch deps:**
   ```sh
   git clone <repo-url> utang_tracker
   cd utang_tracker
   flutter pub get
   ```
6. **Drift codegen (only after editing `lib/core/database/tables.dart` or `app_database.dart`):**
   ```sh
   dart run build_runner build --delete-conflicting-outputs
   ```
   This regenerates `lib/core/database/app_database.g.dart` (drift 2.34.1 + drift_flutter 0.3.0). The file IS committed — commit it after regeneration. Search ignores `*.g.dart` via `.ignore` (not `.gitignore`).
7. **Verify:**
   ```sh
   flutter analyze   # must print "No issues found!"
   flutter test      # CI runs analyze then test in that order.
   flutter test test/<file>.dart   # single file
   ```

---

## 3. Project Layout (quick reference)

```
lib/
  main.dart / app.dart                 # app entry
  core/database/ tables.dart / app_database.dart / database_location.dart / app_database.g.dart
  core/domain/ money.dart / debt_status.dart / audit_action.dart
  core/audit/ audit_log_writer.dart   # shared audit writer called by every repository write
  core/providers/ core_providers.dart  # Riverpod DI and business-data refresh signal
  mappers: features/customers|debts|payments|audit/data/repositories/*_mappers.dart (customer_mappers.dart / debt_mappers.dart / payment_mappers.dart / audit_mappers.dart)
  core/router/ app_router.dart / app_shell.dart   # go_router StatefulShellRoute.indexedStack (5 tabs)
  core/theme/ core/widgets/ core/utils/ core/error/ core/constants/
  features/customers|debts|payments|dashboard|notifications|audit|backup|updater|settings  # 9 dirs
    domain/entities + domain/repositories (interface) + domain/usecases (customers, debts, payments, updater)
    data/repositories (impl) + data/repositories/*_mappers.dart
    presentation/pages + presentation/providers + presentation/widgets
  android/app/src/main/kotlin/.../MainActivity.kt  # updater channel com.example.utang_tracker/updater
assets/images/ + assets/release_notes/current.json
rules/database_rules.md   # authoritative schema v8 spec
test/                     # AppDatabase.forTesting() (in-memory SQLite)
```

State and navigation details are in §4.

---

## 4. Subsystems Reference

### 4.1 Drift SQLite — schema v8

- **Files:** `lib/core/database/tables.dart`, `lib/core/database/app_database.dart`, `lib/core/database/database_location.dart`, `lib/core/database/app_database.g.dart` (generated) + `lib/features/customers/data/repositories/customer_mappers.dart`, `lib/features/debts/data/repositories/debt_mappers.dart`, `lib/features/payments/data/repositories/payment_mappers.dart`, `lib/features/audit/data/repositories/audit_mappers.dart` (`features/*/data/repositories/*_mappers.dart`).
- **Schema version:** `8` (`AppDatabase.schemaVersion`). No SQL `CHECK`/`UNIQUE`/cascade — rules enforced in repository impls.
- **Tables:** `customers`, `debts`, `debt_items`, `payments`, `audit_logs` — see `rules/database_rules.md` for columns, indexes, and business rules.
- **Migrations:** v2 soft-delete (`deleted_at`), v3 recreate `debt_items`, v4 add `unit` default `piece`, v5 `unit_price+subtotal -> price` (custom line amount, quantity does NOT multiply price), v6 add the append-only `audit_logs` table, v7 rewrite `audit_logs.summary` into English, v8 add the nullable `audit_logs.details` column.
- **Date handling:** user-selected local day + save-time clock → stored UTC (`DateTime` as `INTEGER`). `due_date` is date-only (no save-time stamping).
- **Testing:** `AppDatabase.forTesting()` creates an in-memory DB; migration tests seed legacy schemas via raw SQL.
- **Codegen:** `dart run build_runner build --delete-conflicting-outputs` after editing drift tables. Commit the updated `app_database.g.dart`.

### 4.2 Money

- `lib/core/domain/money.dart` — `Money` is integer **centavos** (`int`), never `double`. 100 centavos = 1 peso. `debt_items.price` is the final custom line amount; `total_amount = sum(active prices)`.

### 4.3 Updater (GitHub Releases)

- **Channel:** `com.example.utang_tracker/updater` lives in `android/app/src/main/kotlin/.../MainActivity.kt`. Handles APK install permission (`REQUEST_INSTALL_PACKAGES`) + `FileProvider` (`@xml/file_provider_paths`).
- **Dart side:** `lib/features/updater/data/repositories/update_repository_impl.dart` checks `https://api.github.com/repos/<owner>/<repo>/releases/latest` via `http ^1.4.0` + `pub_semver ^2.2.0` comparison, surfaces via `lib/features/updater/presentation` sheet + About page.
- **Known quirk:** permission flow uses deprecated `onActivityResult` — intentional for now, do not migrate without testing on Android 11-15.

### 4.4 Signing

- `android/key.properties` + `android/app/*.jks` / `*.keystore` are **gitignored** (`.gitignore:49-51`). Never commit them.
- **Local release build:** create `android/key.properties`:
  ```properties
  storePassword=<storePassword>
  keyPassword=<keyPassword>
  keyAlias=<keyAlias>
  storeFile=app/<your>.jks      # or an absolute path; resolved from the android/ directory
  ```
  `android/app/build.gradle.kts:10-70` validates this at `taskGraph.whenReady` and throws `Release signing is not configured` if any of the four keys is missing when any `*Release*` task runs.
- **CI:** `.github/workflows/release.yml` runs `.github/scripts/configure_signing.py` which materializes the keystore from GitHub Secrets. No local `key.properties` is needed in CI.
  Required CI Secrets are `SIGNING_KEY_BASE64` (the complete keystore encoded as
  base64), `KEY_STORE_PASSWORD`, `KEY_PASSWORD`, and `KEY_ALIAS`.

### 4.5 Navigation (go_router)

- `lib/core/router/app_router.dart` + `lib/core/router/app_shell.dart`.
- `go_router ^17.3.0`, `StatefulShellRoute.indexedStack` with 5 tabs: `/dashboard`, `/customers` (`/new`, `/:id`, `/:id/edit`), `/debts` (`/new?customerId`, `/:id`, `/:id/edit`), `/payments` (`/new?debtId`), `/settings`. Top-level routes outside the shell: `/about`, `/audit-log`, `/cloud-backup`.
- Add new top-level routes in `app_router.dart` and add the shell branch in `app_shell.dart`.

### 4.6 State (Riverpod) — push refresh, not streams

- **DI:** plain `Provider`s in `lib/core/providers/core_providers.dart`. Repo interfaces in `features/<f>/domain/repositories`, impls in `features/<f>/data/repositories`.
- **Refresh model:** Drift reactive streams are NOT used. After any write, call:
  ```dart
  ref.read(dataVersionProvider.notifier).bump();
  ```
  All business list/detail providers watch `dataVersionProvider` and rebuild
  automatically, so no per-feature registration is needed.

### 4.7 Release process

Version is triple-locked — CI fails if any drift:

1. Bump `version: <semver>+<build>` in `pubspec.yaml`.
2. Bump `version: "<semver>"` in `assets/release_notes/current.json` (same semver, no `+build`).
3. Tag `v<semver>` where `<semver>` is the semver from `pubspec.yaml`:
   ```sh
   git commit -m "release: v<semver>"
   git tag v<semver>
   git push origin v<semver>
   ```
4. Push tag triggers `.github/workflows/release.yml`:
     `verify_version.py` (tag == pubspec == notes) → `test_release_scripts.py` → `check_release_configuration.py` → `flutter analyze` → `flutter test` → `configure_signing.py` (four signing Secrets) → `flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64` with the `GOOGLE_DRIVE_SERVER_CLIENT_ID` repository Variable → `prepare_release.py` + `generate_release_notes.py` → GitHub Release with `RELEASE_NOTES.md` (6 helpers in `.github/scripts/`).

### 4.8 Google Drive cloud backup

Cloud backup uses Google Sign-In and the Google Drive API. The app keeps the
five newest SQLite backups per Google account. Users can choose daily, weekly,
or manual-only automatic backups. Automatic backup starts only after explicit
sign-in during the current app session, runs when due, and checks again when
the app resumes. Automatic failures are silent so they do not block startup or
interrupt the user. Manual backup and restore show errors in the cloud-backup
page. The page shows the last backup status, interval settings, and collapsible
backup history. Restore replaces the local database after an explicit
confirmation and refreshes the business-data providers. The existing
`utang_tracker_latest.sqlite` file is included in history when upgrading to
the history format. Backups are stored in the `Utang Tracker Backups` folder
in the user's Google Drive. Existing root-level Utang Tracker backup files are
moved into that folder on first use after this change.

### Google Cloud setup

1. Create or select a Google Cloud project.
2. Enable the Google Drive API.
3. Configure the OAuth consent screen and add the Drive file scope.
4. Create an Android OAuth client for package `com.example.utang_tracker`.
5. Add the SHA-1/SHA-256 fingerprints for every debug or release signing key.
6. Create a Web application OAuth client. For local builds, copy the ignored
   configuration template and replace its placeholder:
   ```sh
   cp config/local.json.example config/local.json
   flutter run --dart-define-from-file=config/local.json
   python tool/build_android_release.py
   ```

The client ID is not a secret, but it is environment-specific and must not be
hardcoded in Dart source. Release and CI builds must provide the same
`GOOGLE_DRIVE_SERVER_CLIENT_ID` define. Configure it as the GitHub Actions
repository **Variable** `GOOGLE_DRIVE_SERVER_CLIENT_ID` for release builds.

### Required CI configuration

| GitHub setting | Name | Purpose |
|---|---|---|
| Repository Variable | `GOOGLE_DRIVE_SERVER_CLIENT_ID` | Public Web OAuth client ID passed with `--dart-define` |
| Secret | `SIGNING_KEY_BASE64` | Base64-encoded Android release keystore |
| Secret | `KEY_STORE_PASSWORD` | Keystore password |
| Secret | `KEY_PASSWORD` | Signing key password |
| Secret | `KEY_ALIAS` | Signing key alias |

For local debug builds, use the ignored `config/local.json` file with
`--dart-define-from-file`. For local release builds, also create
`android/key.properties` and provide the keystore referenced by `storeFile`.
Without the Google client ID or valid OAuth configuration, the app still runs,
but Google Drive sign-in and backup are unavailable. Never commit
`config/local.json`.

The `tool/build_android_release.py` script validates the local OAuth
configuration, signing properties, and referenced keystore before building the
ARM and ARM64 split release APKs. It supports Windows, macOS, and Linux.

Backups are SQLite files containing customer, debt, payment, and audit data.
They are protected by the signed-in Google account and Drive permissions. The
app does not add a separate backup password in this version.

---

## 5. Commands Cheat Sheet

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # only after editing drift tables
flutter analyze
flutter test
flutter test test/<file>.dart
flutter clean && flutter pub get   # after changing Gradle plugins
```

---

## 6. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| **Release build fails: "Release signing is not configured"** | `android/key.properties` missing or incomplete. | Create `android/key.properties` with all four keys (`storePassword`, `keyPassword`, `keyAlias`, `storeFile`). Keystore file itself must exist at the `storeFile` path (also gitignored). In CI, secrets are injected by `configure_signing.py`. |
| **Google Drive sign-in is unavailable** | Missing `GOOGLE_DRIVE_SERVER_CLIENT_ID`, disabled Drive API, or OAuth credentials do not match the package/signing certificate. | Build with the `--dart-define`, enable the Drive API, and verify the Android OAuth package name and SHA-1/SHA-256 fingerprints. |
| **Automatic backup did not run** | The user is signed out, the selected interval is not due, automatic backups are set to manual-only, or the app was offline. | Open **Settings → Cloud backup**, sign in during the current app session, choose an interval, and use **Back up now** if needed. Automatic failures are retried on a later resume during that session. |
| **Restore fails** | The cloud file is missing, damaged, or incompatible with this app version. | Create a new backup or update the app. Restore validates the SQLite snapshot before replacing local data. |

### Where to find logs

```sh
# Device logs (filter to Flutter)
adb logcat | findstr /i "flutter utang"   # Windows
adb logcat | grep -i "flutter\|utang"    # macOS/Linux

# Flutter run verbose
flutter run -v
flutter analyze -v
```

---

## 7. Gotchas

- UI strings are hardcoded English — no i18n, intentional. Do not add localization plumbing.
- `Money` must stay integer centavos — never introduce `double` for amounts.
- `debt_items.price` is final — quantity does NOT multiply price.
- Soft delete everywhere (`deleted_at IS NULL` = active); debt/payment deletion is intentionally not exposed.
- Dates: local day + save-time clock → stored UTC; `due_date` is date-only.
- Do not commit `android/key.properties` or `*.jks` — all gitignored.
