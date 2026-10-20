# Release — AI Context

Rules `R1`–`R4` are in [AGENTS.md](../../AGENTS.md). Check with `/com_release`.

## Semver

| Change | Bump |
|---|---|
| Removed/renamed public API; changed return shape; raised Dart/Flutter `environment` lower bound, `minSdk`, iOS deployment target; new abstract method on the platform interface | **major** |
| New public method or optional parameter | minor |
| Bug fix, native-library patch, docs | patch |

Pre-1.0 convention does not apply: this plugin is past `0.x`; follow the table. Use `-beta` suffixes the way the existing CHANGELOG does (`0.0.1-beta`).

## Checklist (`R2`, `R3`)

1. Branch `release/<version>` from `master`.
2. `pubspec.yaml` → `version: <version>`.
3. `CHANGELOG.md` → new top entry `## [<version>] - YYYY-MM-DD` with bullets; breaking changes first, each with the migration step.
4. `README.md` usage + API reference match the code.
5. `fvm flutter analyze`, `fvm flutter test` clean; `example/` run on Android and iOS.
6. `fvm flutter pub publish --dry-run` — no errors; warnings read and accepted or fixed.
7. Commit `release: Bump version to <version>`.
8. **Only on explicit request (`R4`)**: merge to `master`, tag `v<version>`, `fvm flutter pub publish`, push.

## CHANGELOG format

Matches the existing file:

```
## [1.0.0] - 2026-10-19

- **Breaking:** <what changed and how to migrate>.
- Added <feature>.
- Fixed <bug>.
```

## Don't

- ❌ Publish, tag or push without being asked.
- ❌ Change `version` without a matching CHANGELOG entry.
- ❌ Ship a breaking constraint change in a minor/patch.
- ❌ Add `publish_to: none` to the root `pubspec.yaml` (the example app has it, the plugin must not).
