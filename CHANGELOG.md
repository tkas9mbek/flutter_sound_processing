## [1.0.0] - 2026-10-19

- **Breaking:** Raised the minimum Dart SDK from 2.12 to 3.9 and the minimum Flutter SDK from 1.12 to 3.35 (`environment: sdk: ">=3.9.0 <4.0.0"`, `flutter: ">=3.35.0"`). Upgrade the app to Flutter 3.35 or newer (`flutter upgrade`) and set the app's `environment.sdk` lower bound to 3.9 or higher.
- **Breaking:** Raised the Android `minSdk` from 16 to 24 (the Flutter 3.47 template value). Set `minSdk = flutter.minSdkVersion` (24 on current Flutter) or any value of 24 or higher in `android/app/build.gradle(.kts)`.
- **Breaking:** Raised the iOS deployment target from 11.0 to 15.0 (the Flutter 3.47 template value). Set `platform :ios, '15.0'` (or higher) in `ios/Podfile` and `IPHONEOS_DEPLOYMENT_TARGET = 15.0` in the Runner target, then run `pod install`.
- **Breaking:** The Android library now declares Android Gradle Plugin 9.1.0 in its `buildscript` (previously 7.2.0) and compiles with Java 17 source/target (previously 11), matching the Flutter 3.47 plugin template. Build the app with JDK 17 or newer and an AGP version supported by your Flutter release (the Flutter 3.47 app template uses AGP 9.1.0 with Gradle 9.3.1); if the build fails on the plugin's Gradle setup, upgrade `com.android.application` in `android/settings.gradle(.kts)` and the Gradle wrapper accordingly.
- **Breaking:** The Android library now declares `namespace 'kg.cos9.flutter_sound_processing'` in `android/build.gradle` and no longer sets `package` in `AndroidManifest.xml`, as Android Gradle Plugin 8 requires. Apps must build with an AGP that supports the `namespace` DSL (AGP 7.x or newer); upgrade the app's AGP if the build fails on `namespace`.
- **Breaking:** Raised the Android `compileSdk` from 31 to 36 (the `flutter.compileSdkVersion` of Flutter 3.38 and 3.47). Apps must compile against SDK 36 or higher: set `compileSdk = flutter.compileSdkVersion` (or `36`) in `android/app/build.gradle(.kts)`.
- Added Dart unit tests for the method-channel contract and the `FlutterSoundProcessing` delegation.
- Added a fixed-input check to the example app (1 kHz sine, 16 kHz, 1 s) to compare Android and iOS output by hand.
- Fixed invalid-input handling: an empty `signals` list, a missing or mistyped argument, or a non-positive `sampleRate`, `hopLength`, `nMels`, `fftSize` or `mfcc` now fails with `PlatformException` code `INVALID_ARGUMENTS` on both Android and iOS. Failures inside the native library, or an empty result, fail with `CALCULATION_FAILED`. Previously Android surfaced these as a generic `error` code and iOS could crash on an empty signal.
- Fixed the `getFeatureMatrix` documentation: errors are thrown as `PlatformException`, never returned as `null`.
- Android now resolves `jlibrosa` 1.1.8 from Maven Central (`com.litongjava:jlibrosa:1.1.8`) instead of a vendored `-SNAPSHOT` jar. The bytecode of the six `com.jlibrosa` classes is identical, so results do not change. The unused `junit` transitive dependency is excluded.
- Pinned the iOS dependency `RosaKit` to `~> 0.0.11` (previously unpinned).

## [0.0.1-beta] - 2023-05-27

- Added `getFeatureMatrix` method for calculating feature matrices from audio signals for Android.

## [0.0.2-beta] - 2023-05-27

- Updated the README with additional instructions, usage examples, and important information.

## [0.1.0] - 2023-06-18

- Added iOS implementation for `getFeatureMatrix` method.