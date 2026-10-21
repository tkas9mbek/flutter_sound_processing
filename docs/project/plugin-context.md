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
| iOS | Swift (+ ObjC bridge) | CocoaPod `RosaKit` `~> 0.0.11` (mel filterbank `createMelFilter` only), iOS 15.0, Swift 5.0, CocoaPods only (no SwiftPM); file decoding with `AVAudioFile` (`s.frameworks = 'AVFoundation'`) | `ios/Classes/SwiftFlutterSoundProcessingPlugin.swift` (+ `MfccCalculator.swift` — the MFCC pipeline, `AudioFileDecoder.swift`, `Resampler.swift`) |

## Known state (verify before relying)

- Toolchain: `.fvmrc` pins Flutter 3.47.7 (Dart 3.13); run every command through `fvm`. `environment` is `sdk: ">=3.9.0 <4.0.0"`, `flutter: ">=3.35.0"`, `flutter_lints ^6.0.0` (raised from Dart 2.12 / Flutter 1.12 in 1.0.0, breaking, `R1`).
- Invalid input is validated on both platforms on the platform thread before any file access: `PlatformException` `INVALID_ARGUMENTS` (bad/empty/non-positive args, `content://`), then `FILE_NOT_FOUND`, `UNSUPPORTED_FORMAT`, `FILE_TOO_LONG`, `DECODE_FAILED` for files, and `CALCULATION_FAILED` (library exception or empty result). Never returned as `null`.
- File input: both platforms run the same steps — open, duration cap (600 s), decode, 16-bit / 32768, channel average, windowed-sinc resample (Hann, half-width 32, `s = min(1, out/in)`, weight-normalised) when rates differ. Java and Swift resamplers agree to 2.7e-8 on the 44.1 kHz fixture (host JVM vs macOS run, 2026-10-21). Host Java takes about 5 s to resample 600 s of 44.1 kHz audio; phones will be slower.
- On macOS (host check, not iOS) `AVAudioFile` decodes the committed mp3 to 17280 samples (encoder delay not trimmed; m4a trims to 16000), decodes `.ogg` and `.aiff`, and decodes the random-bytes `garbage.mp3` as one 32 kHz frame instead of failing. iOS and Android behaviour for these is unverified.
- `fftSize` is ignored on both platforms: jlibrosa 1.1.8 `JLibrosa.generateMFCCFeatures(float[], int, int, int, int, int)` never calls `setN_fft` (checked with `javap` on the 1.1.8 jar; source lines 226-240), so `AudioFeatureExtraction` keeps its default `n_fft = 2048`. The jar returns bit-identical results for n_fft 512 and 2048. iOS mirrors this (`jlibrosaFFTSize` in `SwiftFlutterSoundProcessingPlugin.swift`). `fftSize` is still validated (positive).
- Short signals: reflect padding needs `n_fft/2 + 1` = 1025 samples (effective n_fft 2048) on both platforms; shorter signals fail with `CALCULATION_FAILED`. Android's message is jlibrosa's `ArrayIndexOutOfBoundsException` text (e.g. `Index 1024 out of bounds for length 1024`), iOS's is `values: need at least n_fft/2 + 1 = 1025 samples (n_fft 2048) for centred framing`. 1025 samples give 3 frames. Host-verified 2026-10-21.
- RosaKit 0.0.11 `[Double].mfcc` is undefined behaviour: `Sources/Rosa/ArrayLibRosaExtensions.swift:113-119` calls `withUnsafeMutableBytes` on the `[[Double]]` dB matrix (the outer array's buffer of row references) and PocketFFT's DCT reads `cols × rows` doubles from it, which gives NaN or ~1e200 values that change on every run. Its mel spectrogram also differs from jlibrosa (magnitude instead of power, `:99`; zero instead of reflect padding, `Sources/NumKit/ArrayExtensions.swift:37-45`; per-band instead of global `top_db`, `:106`). The plugin therefore uses only RosaKit's public `createMelFilter` (same filterbank as jlibrosa's `melFilter()`). `ios/Classes/MfccCalculator.swift` mirrors jlibrosa's `AudioFeatureExtraction` term by term: float-rounded input, reflect padding, periodic Hann, unnormalised radix-2 FFT, power spectrum, mel product, `powerToDb` (amin 1e-10 → −100 dB, global `top_db` 80), orthonormal DCT-II, float-rounded output. A non-finite result fails with `CALCULATION_FAILED` on iOS (stricter than Android). A NaN/Inf input sample is not an error on either platform: its frames become −100 dB.
- Work runs off the platform main thread: Android one `ExecutorService` + main `Handler`, iOS one serial `DispatchQueue` + `DispatchQueue.main` (`PLAT-5`). Not yet observed on a device.
- Dart tests exist in `test/` (channel contract, delegation); native code is verified by hand through the example's fixed-input check (`T3`, `T4`).
- The example app builds on Flutter 3.47.7 / Java 21 / Xcode 26.3: Android regenerated from the 3.47.7 template (Gradle 9.3.1, AGP 9.1.0, Kotlin 2.4.0, `minSdk = flutter.minSdkVersion` = 24), iOS 15.0 with SwiftPM integration for SwiftPM-capable plugins and CocoaPods for `flutter_sound` and this plugin. It has not been run on a device yet.
- Flutter 3.47.7 warns that this plugin (and `flutter_sound`) has no Swift Package Manager support and that this will become an error in a future Flutter version.
- Android↔iOS parity, host-measured 2026-10-21. Setup: `MfccCalculator.swift` unchanged plus RosaKit's `createMelFilter`, built with `swiftc -O` on macOS, against the jlibrosa 1.1.8 + commons-math3 3.6.1 jars on JVM 21. Results: bit-identical on the fixed-input check (1840/1840 values, max abs diff 0; `first5=[-46.173168, 80.053398, -29.104691, -27.313852, -13.540855] sum=-13152.940665`, equal to the Android device output), on a chirp + noise signal, with `mfcc 50`, with 1025 samples and with hop 100000. Max abs diff 1.8e-14 with one NaN/Inf sample. 200/200 repeated runs were identical on the main thread and a serial queue, plus 8 concurrent runs. On-device parity (simulator/emulator) is not yet measured; target ≤ 1e-2 on the fixed-input check and lossless files, ≤ 5e-2 on interior-frame means for mp3/m4a.

## Constraints for Agents

- Keep the API small; a new method needs a plan first.
- Don't change native library versions or platform minimums as a side effect.
- Dart, Android and iOS move together (`P3`, `P4`).
- Don't publish, tag or push (`R4`).
