# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Branch context

This is the **`main` branch**: the general-purpose, **single-country, English-only** version of GiSTX. It connects to one FTP server and has no country selection or language switching. The **`burkinafaso`** branch is a fork of this app that adds a second country (Burkina Faso, over SFTP), bilingual English/French UI text, and per-country server routing — those concerns do not exist here. When porting fixes between branches, keep this in mind: `main` has no `app_strings.dart`, no `country` setting, and no `dartssh2` dependency.

## Commands

```bash
flutter pub get                 # install dependencies
flutter analyze                 # static analysis (analysis_options.yaml)
flutter test                    # run all tests
flutter test test/services/db_service_test.dart   # run a single test file
flutter test --plain-name "explicit null update"  # run a single test by name

flutter run -d windows|macos|linux|chrome   # run during development
```

Version bump + build for release (each build script runs `dart run tool/update_version.dart` first, which auto-increments the patch version in `pubspec.yaml`):

```bash
./build_windows.ps1             # bump version, flutter build windows
./build_apk.ps1                 # bump version, flutter build apk, renamed to gistx.apk
./tool/build_macos_dmg.sh       # flutter build macos --release, packages GiSTX-<version>.dmg
```

When cutting a release, update `ChangeLog.md` (Added/Changed/Fixed/Housekeeping sections per version) alongside the version bump.

## Architecture

GiSTX is an offline-first Flutter survey/data-collection app. Surveys are defined in XML and rendered as dynamic multi-page questionnaires; all responses are stored locally in SQLite. There is no bundled `assets/surveys` folder — surveys are downloaded/side-loaded as zip packages and extracted at runtime (see below), which is a departure from `md/TECHNICAL_README.md` (that doc describes an older, asset-bundled version of the app and is stale on this point; treat it as a conceptual reference for skip/logic/validation semantics, not as ground truth for survey loading or storage paths).

### Survey packaging and multi-survey storage (`SurveyConfigService`)

- Each survey is a zip containing one or more question-XML files plus a `survey_manifest.gistx` (JSON) with `surveyId`, `surveyName`, and `databaseName`.
- Zips are placed in `<platform-base-dir>/GiSTX/zips/` and extracted once into `<platform-base-dir>/GiSTX/surveys/<zip-name>/` (idempotent — skipped if the target folder already exists).
- The "active survey" is just a name stored in `SettingsService`; `SurveyConfigService.getActiveSurveyId()` resolves it to a `surveyId` by scanning manifests in the surveys directory. Multiple surveys can be installed side by side, each with its own manifest, credentials, and database.
- Platform base dir differs: Android → external storage dir, Windows → `%LOCALAPPDATA%`, Linux/macOS → application support dir.
- **`databaseName` in the manifest must stay stable across survey versions.** Because the subject-ID counter is derived from `MAX(...)` in the survey's own table, giving a new zip a new `databaseName` silently resets ID counters and causes duplicate subject IDs. See [docs/DATABASE_VERSIONING_DECISIONS.md](docs/DATABASE_VERSIONING_DECISIONS.md) before changing anything about database naming/versioning.

### Database layer (`DbService`)

- One SQLite database per surveyId (`Map<surveyId, Database>`), opened via `sqflite` on mobile and `sqflite_common_ffi` on desktop (Windows/Linux/macOS init FFI in `DbService.init()`).
- On survey init, `_syncSurveyTable()` reconciles the table schema against the XML questions: creates the table if missing, otherwise diffs existing columns and runs `ALTER TABLE ... ADD COLUMN` for new fields (added as `TEXT`; existing data and unused old columns are preserved, never dropped).
- Table name = survey XML filename (lowercase, no extension); column names = question `fieldname` values, so XML fieldnames and DB columns must match exactly (case-sensitive).
- `crfs` table drives `MainScreen`'s survey list: `filename`, `id_config` (JSON for `IdGenerator`), `primary_keys`, `linking_field` (parent-child hierarchical linking).
- Updates only write changed fields (diff current vs. `_originalAnswers`); explicit `null`s must still be written to clear previously-skipped answers (see `prepareUpdateRowData` and the null-handling test in `test/services/db_service_test.dart`).

### Survey rendering pipeline

1. `SurveyLoader` parses a survey XML file (from a local `File`, not `rootBundle`) into a `List<Question>` (`lib/models/question.dart`), including static/CSV/DB-backed response options, preskip/postskip conditions, logic checks, numeric/date range validation, unique checks, computed `calculation` expressions, and input `mask`.
2. `SurveyScreen` (`lib/screens/survey_screen.dart`, the largest file — ~2000 lines) owns navigation state (`_currentQuestion`, `_history`, `_visitedFields`) and the single shared `AnswerMap` (`Map<String, dynamic>`) that all questions read/write directly — this is the one source of truth, not per-widget copies.
3. `SkipService` evaluates preskip (before showing a question) and postskip (after answering) conditions to jump between fields; `LogicService` evaluates cross-field `logic_check` expressions (supports `AND`/`OR`, parentheses, quoted/field-reference operands) and blocks navigation with an inline message on failure.
4. `AutoFields` computes values for `type="automatic"` questions via a registry keyed by fieldname (`starttime`, `stoptime`, `uniqueid`, `swver`, `lastmod`, etc.) — these never render UI.
5. `IdGenerator` builds subject/record IDs from the CRF's `id_config` JSON (field sources + padding + fixed strings + an auto-incrementing counter queried from the survey's own table).
6. `question_views.dart` renders each `QuestionType` (text/radio/checkbox/combobox/date/datetime/information/automatic); dynamic response lists come from `DatabaseResponseService` (DB-backed, with placeholder-expanded filters) or `csv_data_service.dart` (CSV-backed).
7. On completion, skipped-question answers are cleared, IDs are generated if configured, `lastmod` is touched only on an actual save, and the record is written via `DbService.saveInterview` / `updateInterview`.

### Sync (`FtpService`, `sync_screen.dart`)

Transfers survey data files to/from a single remote FTP server via `ftpconnect`. Credentials can be global (`SettingsService.ftpHost/Username/Password`) or per-survey (`getCredentialsForSurvey`, falling back to global). `SettingsService` stores secrets via `flutter_secure_storage`, except on macOS/Linux where it falls back to `shared_preferences` (keychain entitlements conflict with local ad-hoc code signing there).

### Key services reference

| Service | Responsibility |
|---|---|
| `survey_loader.dart` | XML → `Question` model parsing |
| `survey_config_service.dart` | Zip extraction, manifest lookup, multi-survey storage paths |
| `db_service.dart` | Per-survey SQLite lifecycle, schema sync, CRUD |
| `skip_service.dart` | preskip/postskip evaluation |
| `logic_service.dart` | Cross-field `logic_check` evaluation |
| `expression_evaluator.dart` | Shared expression/condition parsing used by skip/logic/calculation |
| `auto_fields.dart` | Computed/automatic field registry |
| `id_generator.dart` | Subject/record ID generation and validation |
| `database_response_service.dart` / `csv_data_service.dart` | Dynamic response-option sources for radio/checkbox/combobox |
| `question_cache_service.dart` | Caches parsed questions across a survey's XML files for fast option-label lookup |
| `change_summary_service.dart` | Diffs answers for edit-mode change detection |
| `survey_navigation_service.dart` | Navigation helpers shared with `SurveyScreen` |
| `settings_service.dart` | Secure/prefs-backed credentials and app settings |
| `theme_service.dart` | Light/dark theme state |

### Platform-specific notes

- Desktop (Windows/Linux/macOS) uses `sqflite_common_ffi`; mobile uses native `sqflite`. Any DB code must work under both.
- File-system base directories differ per platform (see `SurveyConfigService._getBaseDir()` and the equivalent logic in `DbService`/`FtpService`) — Android uses external storage, Windows uses `%LOCALAPPDATA%`, macOS/Linux use application support dir.
- macOS keychain entitlements conflict with local ad-hoc signing, hence the `shared_preferences` fallback in `SettingsService` for macOS/Linux.
