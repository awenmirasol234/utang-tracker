# utang_tracker

Sari-sari store debt/payment ledger - Android-only Flutter app. Tracks customers, debts (with line items), and payments. UI strings are hardcoded English (no i18n, intentional).

> **New dev?** Start with [`docs/SETUP.md`](docs/SETUP.md) — single canonical setup doc (prerequisites, all subsystems, troubleshooting).

## Features

- **Customers** - create/edit/soft-delete, unique name (case-insensitive), search, sort by name/date
- **Debts** - one debt = many `debt_items` (product, qty, unit, price), editable only while `paid_amount == 0`, items can be appended to a partially paid debt
- **Payments** - record partial/full payments, balance/status derived atomically
- **Dashboard** - outstanding balance, active debt count, collected amount, recent activity
- **Cloud backup** - daily Google Drive backup when the app opens or resumes, plus manual backup and restore
- **Overdue & notifications** - due-date aware
- **Audit log** - Settings page lists every recorded change (customers, debts, payments); rows are written by the repositories
- **Updater** - GitHub Releases check, in-app update sheet + About page

## Tech Stack

| Layer | Choice |
|---|---|
| Framework | Flutter 3.44.0 (stable, Dart SDK ^3.12.0, Android only) |
| State | `flutter_riverpod` - plain `Provider`s in `lib/core/providers/core_providers.dart` |
| DB | `drift` 2.34.1 + `drift_flutter` 0.3.0 + `sqlite3` 3.5.0, schema v8, `AppDatabase.forTesting()` for tests |
| Nav | `go_router` `StatefulShellRoute.indexedStack` (5 tabs) |
| Money | `Money` (`lib/core/domain/money.dart`) - integer centavos, never `double` |
| Fonts | Poppins, Material 3 theme |

Version: `1.0.55+54` (`pubspec.yaml` + `assets/release_notes/current.json` must match tag `v<version>`).

## Prerequisites

| Requirement | Version |
|---|---|
| Flutter | `3.44.0` stable (Dart `^3.12.0`) |
| AGP | `9.0.1` |
| Kotlin | `2.3.20` |
| JDK | `17` |
| compileSdk | `36` |
| Platform | Android only (`com.example.utang_tracker`) |

Full details, env setup, and subsystem docs → [`docs/SETUP.md`](docs/SETUP.md).

## Project Structure

```
lib/
  main.dart / app.dart                 # app entry
  app/coordination.dart                # central business-data invalidation helpers
  core/
    database/ tables.dart / app_database.dart / database_location.dart / app_database.g.dart (generated, committed)
    domain/ money.dart / debt_status.dart / audit_action.dart / audit_change_detail.dart
    audit/ audit_log_writer.dart / audit_details.dart / audit_details_codec.dart   # shared audit writer called by every repository write
    providers/ core_providers.dart     # plain Riverpod Providers
    mappers: features/customers|debts|payments|audit/data/repositories/*_mappers.dart (customer_mappers.dart / debt_mappers.dart / payment_mappers.dart / audit_mappers.dart)
    router/ app_router.dart / app_shell.dart
    theme/ widgets/ utils/ constants/ error/
  features/
    customers|debts|payments|dashboard|notifications|audit|backup|updater|settings  # 9 feature dirs
      domain/entities + domain/repositories (interface) + domain/usecases (customers, debts, updater)
      data/repositories (impl - enforces business rules) + data/repositories/*_mappers.dart
      presentation/pages + presentation/providers + presentation/widgets
  android/app/src/main/kotlin/.../MainActivity.kt  # updater channel (com.example.utang_tracker/updater)
  assets/images/ + assets/release_notes/current.json
  rules/database_rules.md              # authoritative data spec (schema v8)
  test/                                # repo + migration tests (in-memory DB) + test/support (shared fakes)
```

## Data Rules

Full spec -> [`rules/database_rules.md`](rules/database_rules.md) (schema v8, authoritative).

Summary (enforced in repository impls, not SQL):

- IDs = UUID v4 `TEXT`, Money = `INTEGER` centavos, `deleted_at IS NULL` = active, no cascades
- `debt_items.price` = final custom line amount - `quantity` does **not** multiply price; `total_amount = sum(active prices)`
- Debt status derived: `UNPAID (paid<=0)` -> `PARTIAL (0<paid<total)` -> `PAID (paid>=total)`; `balance = total - paid`
- Debt editable only while `paid_amount == 0`; edit = soft-delete old items + insert new in transaction
- Items can be appended to a `PARTIAL` debt (total grows, paid unchanged, balance/status recomputed); appending to a `PAID` debt is rejected
- Payment: `0 < amount <= balance`, only against active non-PAID debt; insert + debt update atomic
- Dates: user-selected local day + save-time clock -> stored UTC; `due_date` is date-only
- Customer delete blocked if active `UNPAID`/`PARTIAL` debts exist; names unique among active (case-insensitive)
- Audit log: every customer/debt/payment write appends an immutable `audit_logs` row (written by the repository; debt + payment rows share the write transaction)

Indexes: `idx_debts_customer_id/status/transaction_date`, `idx_debt_items_debt_id`, `idx_payments_debt_id/payment_date`, `idx_audit_logs_created_at`.

Migrations: v2 soft-delete, v3 recreate `debt_items`, v4 add `unit` (default `piece`), v5 `unit_price+subtotal -> price`, v6 add `audit_logs`, v7 rewrite `audit_logs.summary` into English, v8 add `audit_logs.details`.

## Setup & Commands

> Exhaustive steps → [`docs/SETUP.md`](docs/SETUP.md) (canonical). Summary below.

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs  # after editing drift tables (app_database.g.dart is committed)
flutter analyze
flutter test
flutter test test/<file>.dart   # single file
```

Search ignores `*.g.dart` via `.ignore` (not `.gitignore`).

## Architecture Notes

- **Push refresh, not streams:** after writes call `invalidateBusinessData(ref)` from `lib/app/coordination.dart`; restore uses `invalidateBusinessDataFromRef(ref)`. Register new business-data providers there.
- **DI:** plain Riverpod `Provider`s in `core_providers.dart`; repo interfaces `features/<f>/domain/repositories`, impls `features/<f>/data/repositories`.
- **Testing:** `AppDatabase.forTesting()` (in-memory); migration tests seed legacy schemas via raw SQL.
- **Method channels:** `MainActivity.kt` holds the updater channel; its install-permission flow uses deprecated `onActivityResult`.
- **Signing:** local release builds use gitignored `android/key.properties` and a keystore. CI uses the `SIGNING_KEY_BASE64`, `KEY_STORE_PASSWORD`, `KEY_PASSWORD`, and `KEY_ALIAS` GitHub Secrets.

## Routes

- `/dashboard`, `/customers` (`/new`, `/:id`, `/:id/edit`), `/debts` (`/new?customerId`, `/:id`, `/:id/edit`), `/payments` (`/new?debtId`), `/settings`, `/cloud-backup`, `/about`, `/audit-log`.

## Google Drive configuration

Google Drive backup requires the public Web OAuth client ID at build time. For
local builds, copy `config/local.json.example` to the ignored
`config/local.json` and replace the placeholder:

```sh
cp config/local.json.example config/local.json
flutter run --dart-define-from-file=config/local.json
flutter build apk --release --dart-define-from-file=config/local.json
```

For GitHub Actions releases, configure `GOOGLE_DRIVE_SERVER_CLIENT_ID` as a
repository **Variable**. It is not a secret. CI also requires these GitHub
**Secrets** for Android signing: `SIGNING_KEY_BASE64`, `KEY_STORE_PASSWORD`,
`KEY_PASSWORD`, and `KEY_ALIAS`.

The local JSON file is ignored and must never be committed. CI supplies the
same value through the `GOOGLE_DRIVE_SERVER_CLIENT_ID` repository Variable.

Google Cloud must have the Drive API enabled, the OAuth consent screen
configured, and Android OAuth credentials matching the app package and signing
certificate fingerprints. The app uses Google account permissions and does not
use a separate backup password.

## Release

1. Bump `version` in **both** `pubspec.yaml` and `assets/release_notes/current.json`
2. Tag `v<version>` - CI fails if `tag != pubspec != notes`
3. Push tag -> `.github/workflows/release.yml` validates versions, runs tests, configures signing from the four signing Secrets, builds with the `GOOGLE_DRIVE_SERVER_CLIENT_ID` repository Variable, and creates the GitHub Release.

```sh
# example
# edit pubspec.yaml: 1.0.47+46
# edit assets/release_notes/current.json: { "version": "1.0.47", ... }
git commit -m "release: v1.0.47"
git tag v1.0.47 && git push origin v1.0.47
```
