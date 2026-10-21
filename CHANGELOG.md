## [1.0.0] - 2026-10-19

First stable release. Upgrading from 0.1.0: apply the breaking changes below (each has its migration step), then use the new input methods if you need them.

### Breaking

- `getFeatureMatrix` is renamed to `calculateMFCCs` in `FlutterSoundProcessing`, `FlutterSoundProcessingPlatform` and the method-channel method name; parameters and result are unchanged. Migration: replace `getFeatureMatrix(` with `calculateMFCCs(`.
- `FlutterSoundProcessingPlatform` declares two new abstract methods, `calculateMFCCsFromPcm16` and `calculateMFCCsFromFile`. Migration (third-party platform implementations only): implement both and rename `getFeatureMatrix`. Apps using the bundled implementation are affected only by the rename.
- The channel argument `values` is sent as a `Float64List` (`double[]` on Android, `FlutterStandardTypedData` float64 on iOS) instead of a list of doubles; a plain list is rejected with `INVALID_ARGUMENTS`. Migration (custom native implementations of the `flutter_sound_processing` channel only): accept the typed array. The Dart parameter is still `List<double>`.
- Minimum Dart SDK 3.9 and Flutter 3.35 (previously Dart 2.12 and Flutter 1.12). Migration: `flutter upgrade` to Flutter 3.35 or newer and set the app's `environment.sdk` lower bound to `3.9.0` or higher.
- Android `minSdk` 24 (previously 16). Migration: `minSdk = flutter.minSdkVersion` (24 on current Flutter) or any value of 24 or higher in `android/app/build.gradle(.kts)`.
- Android `compileSdk` 36 (previously 31). Migration: `compileSdk = flutter.compileSdkVersion` (or `36`) in `android/app/build.gradle(.kts)`.
- Android build setup: the plugin declares Android Gradle Plugin 9.1.0 in its `buildscript` (previously 7.2.0), compiles with Java 17 (previously 11) and declares `namespace 'kg.cos9.flutter_sound_processing'` instead of a manifest `package`, matching the Flutter 3.47 plugin template. Migration: build with JDK 17 or newer and an AGP that supports the `namespace` DSL (the Flutter 3.47 app template uses AGP 9.1.0 with Gradle 9.3.1); if the build fails on the plugin's Gradle setup, upgrade `com.android.application` in `android/settings.gradle(.kts)` and the Gradle wrapper.
- iOS deployment target 15.0 (previously 11.0). Migration: `platform :ios, '15.0'` (or higher) in `ios/Podfile` and `IPHONEOS_DEPLOYMENT_TARGET = 15.0` in the Runner target, then run `pod install`.

### Added

- `calculateMFCCsFromFile`: decodes an mp3, wav (16-bit PCM), m4a/AAC-LC or flac file natively (format detected by content), downmixes it to mono, normalises it to `[-1, 1)` and resamples it to `sampleRate` with the same windowed-sinc resampler on Android and iOS. Accepts an absolute path or a `file://` URL; `content://` URIs are rejected; files longer than 600 seconds are rejected.
- `calculateMFCCsFromPcm16`: calculates MFCCs from 16-bit PCM (`Int16List`), each sample divided by 32768; the result equals `calculateMFCCs` on the normalised values.
- Error codes `FILE_NOT_FOUND`, `FILE_TOO_LONG`, `UNSUPPORTED_FORMAT` and `DECODE_FAILED` for file input, with the same codes and messages on Android and iOS.
- Decoding and MFCC calculation run off the platform main thread on both platforms (one background worker, calls processed in order) instead of blocking the UI thread.
- Example app: a fixed-input check (1 kHz sine, 16 kHz, 1 s) with reference values to compare Android and iOS, a full value dump for positional comparison, PCM16 and bundled mp3/wav/m4a/flac runs, one button per error code, and recorded audio converted with `calculateMFCCsFromPcm16` (previously it passed unnormalised integer values as doubles).

### Fixed

- iOS returned NaN or arbitrary values that changed on every run, from every method: RosaKit 0.0.11's `mfcc` reads a `[[Double]]` as a flat buffer (undefined behaviour). iOS now computes reflect padding, windowing, FFT, power spectrum, dB conversion and DCT in the plugin (`ios/Classes/MfccCalculator.swift`), mirroring jlibrosa's pipeline on Android term by term; RosaKit is used only for the mel filterbank and its version is unchanged. Android and iOS now return identical values for the example's fixed input (Android emulator and iOS simulator). Signals shorter than 1025 samples fail with `CALCULATION_FAILED` on iOS as on Android, and a non-finite result fails with `CALCULATION_FAILED` instead of being returned.
- Invalid input: an empty `signals` list, a missing or mistyped argument, or a non-positive `sampleRate`, `hopLength`, `nMels`, `fftSize` or `mfcc` now fails with `PlatformException` code `INVALID_ARGUMENTS` on both Android and iOS; a failure inside the native calculation, or an empty result, fails with `CALCULATION_FAILED`. Previously Android surfaced these as a generic `error` code and iOS could crash on an empty signal.
- Documentation of `calculateMFCCs` (formerly `getFeatureMatrix`): errors are thrown as `PlatformException`, never returned as `null`.
- Android resolves jlibrosa 1.1.8 from Maven Central (`com.litongjava:jlibrosa:1.1.8`, `junit` excluded) instead of a vendored `-SNAPSHOT` jar; the `com.jlibrosa` bytecode is identical, so results do not change.
- The iOS dependency `RosaKit` is pinned to `~> 0.0.11` (previously unpinned).

### Known issues

- `fftSize` is ignored on both platforms: jlibrosa 1.1.8's `generateMFCCFeatures` never applies its `n_fft` argument and always uses 2048, and iOS does the same so that both platforms return the same values. The argument is still validated (must be positive). As a consequence every signal needs at least 1025 samples.
- Lossy formats (mp3, AAC) can decode to slightly different lengths on Android and iOS because the platform decoders handle encoder delay and padding differently, so the frame count may differ by a few frames. Not yet verified on an iOS device.

## [0.0.1-beta] - 2023-05-27

- Added `getFeatureMatrix` method for calculating feature matrices from audio signals for Android.

## [0.0.2-beta] - 2023-05-27

- Updated the README with additional instructions, usage examples, and important information.

## [0.1.0] - 2023-06-18

- Added iOS implementation for `getFeatureMatrix` method.
