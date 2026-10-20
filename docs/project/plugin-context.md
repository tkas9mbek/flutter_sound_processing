# Plugin Context: calculateMFCCs

> Read with `AGENTS.md` and `docs/ai-context/`. When reusing this setup for another plugin, replace every section and keep the headings.

<!-- Source snapshot: 2026-10-19, pubspec 1.0.0, branch release/1.0.0 cut from master, toolchain Flutter 3.47.7 via FVM. Update when this changes. -->

## Product

`flutter_sound_processing` calculates **MFCCs** (mel-frequency cepstral coefficients) from raw audio samples on-device, so Flutter apps can feed speech/audio ML models without a Dart DSP implementation. Android and iOS only. It does not record, play or decode audio — it takes already-decoded samples.

Published on pub.dev. Repository: `tkas9mbek/flutter_sound_processing`. License: MIT.

## API

| | 0.1.0 (current code) | 1.0.0 (target) |
|---|---|---|
| Method | `getFeatureMatrix` | `calculateMFCCs` — rename, **breaking** (`R1`) |
| Parameters | `signals: List<double>`, `sampleRate`, `hopLength`, `nMels`, `fftSize`, `mfcc` (`int`, all required) | same, unless the plan changes them |
| Returns | `Future<Float64List?>` | `Future<Float64List?>` |

Until the rename lands in code, the channel method name and the Dart/Java/Swift identifiers are still `getFeatureMatrix`. The rename touches all three sides plus README, CHANGELOG, `example/` and the platform interface (`P3`, `P5`) — plan it with `planner`.

Returned layout: native `[rows][cols]` MFCC matrix flattened as `data[row + rows * col]` (column-major) on both platforms. Dimensions are not returned; the caller derives them from the parameters.

## Channel contract

Channel `flutter_sound_processing`. Argument keys:

| Key | Dart parameter |
|---|---|
| `values` | `signals` |
| `sample_rate` | `sampleRate` |
| `mfcc` | `mfcc` |
| `n_fft` | `fftSize` |
| `n_mels` | `nMels` |
| `hop_length` | `hopLength` |

## Native implementations

| Platform | Language | Library | Entry |
|---|---|---|---|
| Android | Java | `jlibrosa` 1.1.8 (`com.litongjava:jlibrosa` from Maven Central, `junit` excluded), `compileSdk 36`, `minSdk 24`, Java 17, AGP 9.1.0 `buildscript`, `namespace` set | `android/src/main/java/kg/cos9/flutter_sound_processing/FlutterSoundProcessingPlugin.java` |
| iOS | Swift (+ ObjC bridge) | CocoaPod `RosaKit` `~> 0.0.11`, iOS 15.0, Swift 5.0, CocoaPods only (no SwiftPM) | `ios/Classes/SwiftFlutterSoundProcessingPlugin.swift` |

## Known state (verify before relying)

- Toolchain: `.fvmrc` pins Flutter 3.47.7 (Dart 3.13); run every command through `fvm`. `environment` is `sdk: ">=3.9.0 <4.0.0"`, `flutter: ">=3.35.0"`, `flutter_lints ^6.0.0` (raised from Dart 2.12 / Flutter 1.12 in 1.0.0, breaking, `R1`).
- Invalid input is validated on both platforms: `PlatformException` `INVALID_ARGUMENTS` (bad/empty/non-positive args) and `CALCULATION_FAILED` (library exception or empty result). It is never returned as `null`.
- Android: `jlibrosa` throws for signals shorter than roughly 1500 samples at `fftSize 512` (`CALCULATION_FAILED`); iOS behavior for short signals is unverified and RosaKit can trap instead of throwing.
- Both handlers run on the platform main thread (`PLAT-5`).
- Dart tests exist in `test/` (channel contract, delegation); native code is verified by hand through the example's fixed-input check (`T3`, `T4`).
- The example app builds on Flutter 3.47.7 / Java 21 / Xcode 26.3: Android regenerated from the 3.47.7 template (Gradle 9.3.1, AGP 9.1.0, Kotlin 2.4.0, `minSdk = flutter.minSdkVersion` = 24), iOS 15.0 with SwiftPM integration for SwiftPM-capable plugins and CocoaPods for `flutter_sound` and this plugin. It has not been run on a device yet.
- Flutter 3.47.7 warns that this plugin (and `flutter_sound`) has no Swift Package Manager support and that this will become an error in a future Flutter version.
- Android↔iOS numerical parity has never been measured; target ≤ 1e-2 on the fixed-input check.

## Constraints for Agents

- Keep the API small; a new method needs a plan first.
- Don't change native library versions or platform minimums as a side effect.
- Dart, Android and iOS move together (`P3`, `P4`).
- Don't publish, tag or push (`R4`).
