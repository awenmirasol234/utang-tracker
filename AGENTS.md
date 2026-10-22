# AGENTS.md

## Repo facts

- Android-only Flutter app (no ios/web/desktop): sari-sari store debt/payment ledger. UI strings are hardcoded English — no i18n, intentional.
- `rules/database_rules.md` is the authoritative data spec (schema v7, business rules, migration history) - keep it in sync with any schema/repo change. `README.md` is the project overview.

## Commands

- `flutter pub get` (no root pub; Flutter app)
- After editing drift tables: `dart run build_runner build --delete-conflicting-outputs` — `lib/core/database/app_database.g.dart` is generated AND committed
- Verify before committing: `flutter analyze` then `flutter test` (matches CI order)
- Single test: `flutter test test/<file>.dart`
- Release: bump version in BOTH `pubspec.yaml` and `assets/release_notes/current.json`, then tag `v<version>`. CI fails if tag ≠ pubspec version ≠ notes version.

## Data rules (enforced in repository impls, not SQL)

- Money = integer centavos (`Money` in `lib/core/domain/money.dart`) — never doubles
- `debt_items.price` is the final custom line amount; quantity does NOT multiply price
- Soft delete everywhere (`deleted_at IS NULL` = active); no cascades; debt/payment deletion intentionally not exposed
- Debt status derived: UNPAID → PARTIAL → PAID; debt editable only while `paid_amount == 0`
- Items can be appended to a PARTIAL debt via `DebtRepository.addItems` (total grows, paid unchanged, balance/status recomputed); rejected for PAID debts
- Dates: user-selected local day + save-time clock, stored UTC

## Architecture

- Data refresh is push-based: after writes call `invalidateBusinessData(ref)` from `lib/app/coordination.dart` (31-42) — NOT Drift reactive streams. Register new list/detail providers there.
- DI: plain Riverpod `Provider`s in `lib/core/providers/core_providers.dart`; repo interfaces in `features/<f>/domain/repositories`, impls in `features/<f>/data/repositories`
- Repo tests use `AppDatabase.forTesting()` (in-memory SQLite); migration tests seed legacy schemas via raw SQL
- Android method channels live in `android/.../MainActivity.kt`: updater (`com.example.utang_tracker/updater`); the updater permission flow uses deprecated onActivityResult
- The updater also polls every 6h while the app is foregrounded (`lib/features/updater/presentation/widgets/update_auto_checker.dart`); a dismissed version only suppresses that automatic prompt, never a manual check
- `android/key.properties` + keystores are gitignored; CI signs from GH secrets
- `.ignore` (not `.gitignore`) excludes generated `*.g.dart` from search tools
