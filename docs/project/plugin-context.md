# Plugin Context: calculateMFCCs, calculateMFCCsFromPcm16, calculateMFCCsFromFile

> Read with `AGENTS.md` and `docs/ai-context/`. When reusing this setup for another plugin, replace every section and keep the headings.

<!-- Source snapshot: 2026-10-21, pubspec 1.0.0, branch release/1.0.0 cut from master, toolchain Flutter 3.47.7 via FVM. Update when this changes. -->

## Product

`flutter_sound_processing` calculates **MFCCs** (mel-frequency cepstral coefficients) on-device from `double` samples, 16-bit PCM or an audio file it decodes natively, so Flutter apps can feed speech/audio ML models without a Dart DSP implementation. Android and iOS only. It does not record or play audio, and it does not pick files.

Published on pub.dev. Repository: `tkas9mbek/flutter_sound_processing`. License: MIT.

## API

| Method (1.0.0) | Input | Notes |
|---|---|---|
| `calculateMFCCs` (renamed from `getFeatureMatrix`, **breaking**, `R1`) | `signals: List<double>` | sent as `Float64List` |
| `calculateMFCCsFromPcm16` | `samples: Int16List` | divided by 32768 in Dart, then the same channel call as `calculateMFCCs` |
| `calculateMFCCsFromFile` | `path: String` (absolute path or `file://`; `content://` rejected) | decoded, downmixed to mono, normalised to `[-1, 1)`, resampled to `sampleRate` natively; ≤ 600 s |

All three also take `sampleRate`, `hopLength`, `nMels`, `fftSize`, `mfcc` (`int`, all required, positive) and return `Future<Float64List?>`; failures are `PlatformException`, never `null`. Guaranteed file formats (both platforms): mp3, wav 16-bit PCM, m4a/AAC-LC, flac — detected by content.

Returned layout: native `[rows][cols]` MFCC matrix flattened as `data[row + rows * col]` (column-major) on both platforms, `rows = mfcc`, `frames = length ~/ mfcc`. Dimensions are not returned.

## Channel contract

Channel `flutter_sound_processing`. Native methods `calculateMFCCs` and `calculateMFCCsFromFile` (`calculateMFCCsFromPcm16` is Dart-only). Argument keys:

| Key | Dart parameter | Method |
|---|---|---|
| `values` (`Float64List`) | `signals` / normalised `samples` | `calculateMFCCs` |
| `path` (`String`) | `path` | `calculateMFCCsFromFile` |
| `sample_rate` | `sampleRate` | both |
| `mfcc` | `mfcc` | both |
| `n_fft` | `fftSize` | both |
| `n_mels` | `nMels` | both |
| `hop_length` | `hopLength` | both |

Error codes (identical strings and messages on both platforms): `INVALID_ARGUMENTS`, `FILE_NOT_FOUND`, `FILE_TOO_LONG`, `UNSUPPORTED_FORMAT`, `DECODE_FAILED`, `CALCULATION_FAILED`. Platform-specific diagnostics go into `details`.

## Native implementations

| Platform | Language | Library | Entry |
|---|---|---|---|
| Android | Java | `jlibrosa` 1.1.8 (`com.litongjava:jlibrosa` from Maven Central, `junit` excluded), `compileSdk 36`, `minSdk 24`, Java 17, AGP 9.1.0 `buildscript`, `namespace` set; file decoding with SDK `MediaExtractor`/`MediaCodec` | `android/src/main/java/kg/cos9/flutter_sound_processing/FlutterSoundProcessingPlugin.java` (+ `AudioFileDecoder.java`, `Resampler.java`) |
| iOS | Swift (+ ObjC bridge) | CocoaPod `RosaKit` `~> 0.0.11`, iOS 15.0, Swift 5.0, CocoaPods only (no SwiftPM); file decoding with `AVAudioFile` (`s.frameworks = 'AVFoundation'`) | `ios/Classes/SwiftFlutterSoundProcessingPlugin.swift` (+ `AudioFileDecoder.swift`, `Resampler.swift`) |

## Known state (verify before relying)

- Toolchain: `.fvmrc` pins Flutter 3.47.7 (Dart 3.13); run every command through `fvm`. `environment` is `sdk: ">=3.9.0 <4.0.0"`, `flutter: ">=3.35.0"`, `flutter_lints ^6.0.0` (raised from Dart 2.12 / Flutter 1.12 in 1.0.0, breaking, `R1`).
- Invalid input is validated on both platforms on the platform thread before any file access: `PlatformException` `INVALID_ARGUMENTS` (bad/empty/non-positive args, `content://`), then `FILE_NOT_FOUND`, `UNSUPPORTED_FORMAT`, `FILE_TOO_LONG`, `DECODE_FAILED` for files, and `CALCULATION_FAILED` (library exception or empty result). Never returned as `null`.
- File input: both platforms run the same steps — open, duration cap (600 s), decode, 16-bit / 32768, channel average, windowed-sinc resample (Hann, half-width 32, `s = min(1, out/in)`, weight-normalised) when rates differ. Java and Swift resamplers agree to 2.7e-8 on the 44.1 kHz fixture (host JVM vs macOS run, 2026-10-21). Host Java takes about 5 s to resample 600 s of 44.1 kHz audio; phones will be slower.
- On macOS (host check, not iOS) `AVAudioFile` decodes the committed mp3 to 17280 samples (encoder delay not trimmed; m4a trims to 16000), decodes `.ogg` and `.aiff`, and decodes the random-bytes `garbage.mp3` as one 32 kHz frame instead of failing. iOS and Android behaviour for these is unverified.
- Android: `jlibrosa` throws for signals shorter than roughly 1500 samples at `fftSize 512` (`CALCULATION_FAILED`); iOS behavior for short signals is unverified and RosaKit can trap instead of throwing.
- Work runs off the platform main thread: Android one `ExecutorService` + main `Handler`, iOS one serial `DispatchQueue` + `DispatchQueue.main` (`PLAT-5`). Not yet observed on a device.
- Dart tests exist in `test/` (channel contract, delegation); native code is verified by hand through the example's fixed-input check (`T3`, `T4`).
- The example app builds on Flutter 3.47.7 / Java 21 / Xcode 26.3: Android regenerated from the 3.47.7 template (Gradle 9.3.1, AGP 9.1.0, Kotlin 2.4.0, `minSdk = flutter.minSdkVersion` = 24), iOS 15.0 with SwiftPM integration for SwiftPM-capable plugins and CocoaPods for `flutter_sound` and this plugin. It has not been run on a device yet.
- Flutter 3.47.7 warns that this plugin (and `flutter_sound`) has no Swift Package Manager support and that this will become an error in a future Flutter version.
- Android↔iOS numerical parity has never been measured on devices; target ≤ 1e-2 on the fixed-input check and lossless files, ≤ 5e-2 on interior-frame means for mp3/m4a.

## Constraints for Agents

- Keep the API small; a new method needs a plan first.
- Don't change native library versions or platform minimums as a side effect.
- Dart, Android and iOS move together (`P3`, `P4`).
- Don't publish, tag or push (`R4`).
