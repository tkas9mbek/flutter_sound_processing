# AGENTS.md

> **AI Context**: Canonical rules for any AI coding agent (Claude Code, Codex, Cursor, …) in this repository. Single source of truth — tool-specific files (e.g. `CLAUDE.md`) layer on top, they don't repeat it.

## Read This First

1. Start here for rules, commands, structure.
2. `docs/ai-context/` — per-topic rule-ID references (`P*` plugin structure, `S*` style, `T*` testing, `R*` release). Open the relevant one before touching that area.
3. `docs/project/plugin-context.md` — what this plugin does (MFCC calculation), its channel contract, native dependencies, known state.

## Project Overview

`flutter_sound_processing` — Flutter **plugin** (Dart API + Android Java + iOS Swift) that **calculates MFCCs** (mel-frequency cepstral coefficients) natively from `double` samples, 16-bit PCM or an audio file (decoded natively). Published on pub.dev. Dart calls reach native code through one `MethodChannel`. Android wraps `jlibrosa`; iOS computes the MFCCs in the plugin (`ios/Classes/MfccCalculator.swift`, a term-by-term mirror of jlibrosa's pipeline) and uses `RosaKit` only for the mel filterbank. Files are decoded with `MediaExtractor`/`MediaCodec` (Android) and `AVAudioFile` (iOS). Public API: `calculateMFCCs`, `calculateMFCCsFromPcm16`, `calculateMFCCsFromFile` (`getFeatureMatrix` was renamed to `calculateMFCCs` in 1.0.0).

```
FlutterSoundProcessing  →  FlutterSoundProcessingPlatform  →  MethodChannelFlutterSoundProcessing  →  native plugin
(public API, lib/)         (abstract interface, lib/)         (channel impl, lib/)                    (android/, ios/)
```

---

## Essential Commands

```bash
fvm flutter pub get                   # Install deps
fvm flutter analyze                   # Analyzer
fvm dart format lib test example/lib  # Format
fvm flutter test                      # Unit tests (root)
cd example && fvm flutter run         # Run the example app (needed to exercise native code)
fvm flutter pub publish --dry-run     # Pre-release package check
```

Flutter is pinned with FVM: `.fvmrc` → Flutter 3.47.7 (Dart 3.13). Always run `fvm flutter` / `fvm dart`, never the global SDK. The package floor is Dart `>=3.9.0 <4.0.0`, Flutter `>=3.35.0`; Android `minSdk` 24 / `compileSdk` 36 / Java 17 / AGP 9.1.0; iOS 15.0.

Native code only runs on a device/simulator — `flutter test` cannot reach it. Verify native changes through `example/` on both platforms.

---

## Plugin Structure — `docs/ai-context/architecture.md`

| ID | Rule |
|---|---|
| P1 | Public API is `FlutterSoundProcessing` only; it delegates to `FlutterSoundProcessingPlatform.instance` and holds no logic. |
| P2 | `FlutterSoundProcessingPlatform` extends `PlatformInterface` (token-verified `instance` setter); the default is `MethodChannelFlutterSoundProcessing`. |
| P3 | Channel name, method names and argument keys are a contract with native code — change Dart, Android and iOS in the same commit. |
| P4 | Android and iOS must return the same shape and the same numeric result for the same input. |
| P5 | Public API additions/changes are reflected in `README.md`, the dartdoc, `CHANGELOG.md` and the `example/` app. |
| P6 | Native platform errors surface as `PlatformException` with the documented code — never swallowed silently, never returned as `null`. |

Layout: `lib/` (Dart API) · `android/src/main/java/kg/cos9/flutter_sound_processing/` · `ios/Classes/` (+ `.podspec`) · `example/` (manual test bench) · `test/` (Dart unit tests).

---

## Testing — `docs/ai-context/testing.md`

| ID | Rule |
|---|---|
| T1 | Dart side is tested without native code: mock the `MethodChannel` (`TestDefaultBinaryMessengerBinding`) and assert the method name + argument map. |
| T2 | The public class is tested against a `MockPlatform` (`MockPlatformInterfaceMixin`) — proves delegation. |
| T3 | Every new native method gets a channel-contract test (name, argument keys, return type) and a manual check in `example/` on Android **and** iOS. |
| T4 | Numeric results are checked against a small fixed input with known output (tolerance, not equality). |

---

## Code Style — `docs/ai-context/rules.md`

| ID | Rule |
|---|---|
| S1 | Trailing commas where they improve formatting; `dart format` clean. |
| S2 | Single quotes. |
| S3 | `final` for locals; `var` only when reassigned. |
| S4 | `///` dartdoc on every public member of the API; 1–3 lines + params, no restating the signature. |
| S5 | No `print` — surface problems through exceptions. |
| S6 | File name == class name (`snake_case`); no `Impl`/`Helper`/`Manager`/`Util` suffixes. |

Native code: keep each platform file small and mirrored — same method names, same argument keys, same error codes and messages; `AudioFileDecoder` and `Resampler` exist once per platform with the same name. The one exception is `ios/Classes/MfccCalculator.swift`, which mirrors jlibrosa's `AudioFeatureExtraction` (Android's library) rather than a plugin file. Follow each platform's idiom (Java camelCase, Swift API guidelines).

---

## Git — `docs/ai-context/git.md`

Branches: `<category>/[<TICKET-ID>_]<kebab-case>`, category ∈ `feature/fix/refactor/research/release`. `master` is the stable branch (tip = last published version); `release/<version>` collects work for the next version.
Commits: `type: Capitalized imperative` (or `TICKET-ID: …`) — ≤72 chars, no trailing period, one logical change each. `type` ∈ `feature|feat, fix, refactor, research, release, docs, style, test, chore`.

---

## Release — `docs/ai-context/release.md`

| ID | Rule |
|---|---|
| R1 | Version follows semver: breaking API/min-SDK change → major, new API → minor, fix → patch. |
| R2 | `pubspec.yaml` version, the top `CHANGELOG.md` entry and the git tag are the same version. |
| R3 | `fvm flutter pub publish --dry-run` is clean before tagging. |
| R4 | Never publish or push tags without an explicit user request. |

---

## Hard Rules Checklist

1. Check `docs/ai-context/` before coding in an unfamiliar area.
2. Never create files unless necessary; never proactively create docs unless asked.
3. Keep Dart, Android and iOS in sync (`P3`, `P4`) — a one-platform change is incomplete unless the task says otherwise.
4. Sort `pubspec.yaml` deps: SDK first, then alphabetical.
5. Don't raise `environment` constraints, native dependency versions or `minSdk`/iOS deployment target without a plan that says so — they are breaking for consumers.
6. `work/` (plans, analysis, review reports) and `.claude/` are git-ignored scratch — never commit them and never link to them from committed docs.

---

## Documentation Map

| File | Topic |
|---|---|
| [docs/ai-context/architecture.md](docs/ai-context/architecture.md) | Plugin layers, channel contract, adding a method |
| [docs/ai-context/rules.md](docs/ai-context/rules.md) | Style, naming, forbidden patterns |
| [docs/ai-context/testing.md](docs/ai-context/testing.md) | Dart tests, native verification via `example/` |
| [docs/ai-context/code_review.md](docs/ai-context/code_review.md) | Severity-tagged rule-ID checklist |
| [docs/ai-context/git.md](docs/ai-context/git.md) | Branch / commit / PR format |
| [docs/ai-context/release.md](docs/ai-context/release.md) | Versioning, changelog, pub.dev publish |
| [docs/project/plugin-context.md](docs/project/plugin-context.md) | This plugin's API, native deps, known state |
| [README.md](README.md) · [CHANGELOG.md](CHANGELOG.md) · [example/README.md](example/README.md) | The pub.dev-facing docs (`P5`); `AGENTS.md`, `CLAUDE.md` and `docs/` are excluded from the package by `.pubignore` |
