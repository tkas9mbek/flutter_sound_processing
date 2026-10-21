# Release — AI Context

Rules `R1`–`R4` are in [AGENTS.md](../../AGENTS.md). Check with `/com_release`.

## Semver

| Change | Bump |
|---|---|
| Removed/renamed public API; changed return shape; raised Dart/Flutter `environment` lower bound, `minSdk`, iOS deployment target; new abstract method on the platform interface | **major** |
| New public method or optional parameter | minor |
| Bug fix, native-library patch, docs | patch |

From 1.0.0 on the table applies as written (no `0.x` leniency). Pre-release suffixes (`-beta`) only as in the `0.0.x` entries, if ever needed.

## Checklist (`R2`, `R3`)

1. Branch `release/<version>` from `master`.
2. `pubspec.yaml` → `version: <version>`.
3. `CHANGELOG.md` → new top entry `## [<version>] - YYYY-MM-DD` (date = publish day); `### Breaking` first, each bullet with its migration step, then `### Added`, `### Fixed`, `### Known issues`.
4. `README.md` usage, API reference, Errors and Known limitations match the code; every public member has dartdoc; `example/README.md` matches the example's buttons.
5. `docs/project/plugin-context.md`: snapshot comment, versions and "Known state" current (not shipped, but the next agent reads it).
6. Versions declared elsewhere agree with `pubspec.yaml`: `ios/flutter_sound_processing.podspec` `s.version` (and its `s.homepage` / `s.author` are real values), `android/build.gradle` `version`.
7. `fvm flutter analyze`, `fvm flutter test` clean; `example/` run on Android and iOS, at least the fixed-input check (reference values in `example/README.md`) and one file button per platform; record which platforms were exercised.
8. `fvm flutter pub publish --dry-run` — no errors; warnings read and accepted or fixed. `.pubignore` keeps `AGENTS.md`, `CLAUDE.md`, `docs/`, `.claude/`, `work/`, `.fvm*` out of the package; check the listed files.
9. Commit `release: Bump version to <version>`.
10. **Only on explicit request (`R4`)**: merge to `master`, tag `v<version>`, `fvm flutter pub publish`, push.

## CHANGELOG format

```
## [1.0.0] - 2026-10-19

### Breaking

- <what changed>. Migration: <what the app must do>.

### Added

- <feature>.

### Fixed

- <bug>.

### Known issues

- <limitation the release ships with>.
```

Older entries keep their original flat-bullet format; don't rewrite them.

## Don't

- ❌ Publish, tag or push without being asked.
- ❌ Change `version` without a matching CHANGELOG entry.
- ❌ Ship a breaking constraint change in a minor/patch.
- ❌ Add `publish_to: none` to the root `pubspec.yaml` (the example app has it, the plugin must not).
- ❌ Put measurements in README/CHANGELOG that were not actually observed; say "not verified on <platform>" instead.
