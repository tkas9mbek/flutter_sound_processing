# Code Review — AI Context

Concise checklist. Report format: `work/review.md` (git-ignored scratch; never link to it from committed docs).

## Severity

| Symbol | Meaning |
|--------|---------|
| 🔴 Blocking | Must fix before merge/release |
| 🟡 Mild | TODO acceptable |
| 🟢 Suggestion | Nice to have (incl. low-stakes formatting nits) |
| 💬 Comment | Cannot be changed retroactively — commit/branch names, shipped API |

Rules tagged `[lint]` are auto-enforced — skip in manual review.

## API (public surface and Dart layers)

| ID | Severity | Rule |
|---|---|---|
| API-1 | 🔴 | `FlutterSoundProcessing` only delegates (`P1`) |
| API-2 | 🔴 | Platform interface keeps the token-verified `instance` setter (`P2`) |
| API-3 | 🔴 | A change to exported signatures is flagged in the CHANGELOG and justifies the semver bump (`R1`) |
| API-4 | 🟡 | New abstract method on the platform interface is noted as breaking for external implementations |
| API-5 | 🟡 | Parameter names/types match the README API reference |
| API-6 | 🟢 | Sensible defaults for tuning params instead of making every parameter required (only if non-breaking) |

## PLAT (platform / channel)

| ID | Severity | Rule |
|---|---|---|
| PLAT-1 | 🔴 | Channel name, method name and argument keys identical in Dart, Android, iOS (`P3`) |
| PLAT-2 | 🔴 | Android and iOS return the same shape and layout (`P4`) |
| PLAT-3 | 🔴 | Invalid/empty input yields the documented `PlatformException` code on both platforms, not a native crash or `null` (`P6`) |
| PLAT-4 | 🔴 | No change to `minSdk`, iOS deployment target, Dart/Flutter constraint or native library versions without an explicit plan and CHANGELOG note |
| PLAT-5 | 🟡 | Heavy computation does not block the platform main thread |
| PLAT-6 | 🟡 | `pubspec.yaml` plugin block matches native class names |
| PLAT-7 | 🟢 | Native files mirror each other's structure and naming (`ios/Classes/MfccCalculator.swift` mirrors jlibrosa instead; its Java line references stay accurate) |

## TEST

| ID | Severity | Rule |
|---|---|---|
| TEST-1 | 🔴 | New/changed channel method has a contract test (`T1`) |
| TEST-2 | 🟡 | Delegation covered for new parameters (`T2`) |
| TEST-3 | 🟡 | Branch states which platforms were exercised in `example/` (`T3`) |
| TEST-4 | 🟢 | Numeric asserts use tolerance (`T4`) |

## DOC

| ID | Severity | Rule |
|---|---|---|
| DOC-1 | 🔴 | Public members have dartdoc (`S4`) |
| DOC-2 | 🟡 | README usage + API reference updated (`P5`) |
| DOC-3 | 🟡 | CHANGELOG entry present for user-visible change |
| DOC-4 | 🟢 | `example/` demonstrates the new/changed API; `example/README.md` lists the button |

## REL (release)

| ID | Severity | Rule |
|---|---|---|
| REL-1 | 🔴 | `pubspec.yaml` version == top CHANGELOG entry == branch `release/<version>` (`R2`) |
| REL-2 | 🔴 | `fvm flutter pub publish --dry-run` clean (`R3`) |
| REL-3 | 🟡 | Breaking changes listed first in the CHANGELOG entry with the migration step |

## STYLE

| ID | Severity | Rule |
|---|---|---|
| STYLE-1 | 🟢 `[lint]` | `dart format`, trailing commas, single quotes |
| STYLE-2 | 🟡 | No `print`, no commented-out code, no dead helpers |
| STYLE-3 | 🟡 | Names follow `rules.md` (no `Impl`/`Helper`/`Util`) |
| STYLE-4 | 🟢 | Comments explain why, ≤120 chars (`rules.md`) |

## Report format

```
# Review: <branch>

## API            (table: # | Severity | Rule | File:line | Finding → see (N))
## PLAT
## TEST
## DOC
## REL
## STYLE

(N) code blocks referenced from the tables — no code inside table cells.

Counts: 🔴 n · 🟡 n · 🟢 n · 💬 n
Verdict: ✅ Approve | ⚠️ Approve with TODOs | ❌ Changes required
```

Clean sections say "No issues found." Don't manufacture findings.
