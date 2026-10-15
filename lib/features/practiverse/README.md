# PractiVerse MVP

## Integration

The existing CampusOS dashboard calls:

```dart
PractiverseModule.getEntryPoint(context)
```

The public entry point remains in `lib/features/practiverse/practiverse_module.dart`. No root routing, dashboard, shared theme, authentication, or dependency changes are required.

## Included

- Three predefined challenges with difficulty, descriptions, examples, completion state, and filters.
- Challenge workspace with answer input, deterministic expected-answer comparison, result feedback, and test-case summary.
- Three lives per challenge, one life per failed evaluation, invalid-empty-answer protection, explicit retries, and incremental hints.
- Five-question multiple-choice quiz with required answers, score, explanations, and duplicate-submission protection.
- Session-only challenge and quiz progress.
- Responsive Material UI using existing `AppColors` and the CampusOS theme.

## Evaluation limitation

This MVP does **not** execute arbitrary code. It compares a submitted expected output against a predefined answer and reports simulated test results. The per-case display is illustrative; a correct expected answer marks all listed demo cases as passed. Do not describe this as a real compiler or sandbox.

## Timer and persistence

The quiz has no countdown in this MVP to avoid unreliable timer behavior in a two-day demo. Progress is held in memory for the current module session and is not persisted across application restarts.

## Verify

From the repository root:

```bash
dart format lib/features/practiverse/practiverse_module.dart test/practiverse_module_test.dart
flutter analyze
flutter test test/practiverse_module_test.dart
flutter test
```

## Ownership

All implementation code belongs under `lib/features/practiverse/`. The focused widget tests are under `test/practiverse_module_test.dart`. Existing dashboard integration remains unchanged.
