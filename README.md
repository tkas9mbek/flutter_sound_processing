# flutter_sound_processing

Flutter plugin that calculates MFCCs (mel-frequency cepstral coefficients) from raw audio samples natively on Android and iOS. It does not record, play or decode audio — pass already-decoded samples, for example to feed a speech or audio ML model.

## Installation

`flutter pub add flutter_sound_processing`

| Platform | Requirements | Native library |
|---|---|---|
| Dart / Flutter | Dart 3.9 or newer, Flutter 3.35 or newer | — |
| Android | `minSdk` 24 or higher, `compileSdk` 36 or higher, JDK 17 or newer, an Android Gradle Plugin supported by your Flutter release (the plugin declares AGP 9.1.0, the Flutter 3.47 template value) | jlibrosa 1.1.8 (Maven Central) |
| iOS | iOS 15.0 or higher, Swift 5 | [RosaKit](https://github.com/dhrebeniuk/RosaKit) `~> 0.0.11` (CocoaPods) |

## Usage

```dart
import 'package:flutter/services.dart';
import 'package:flutter_sound_processing/flutter_sound_processing.dart';

final processing = FlutterSoundProcessing();

try {
  final mfccs = await processing.getFeatureMatrix(
    signals: samples, // mono samples as doubles
    sampleRate: 16000,
    hopLength: 350,
    nMels: 40,
    fftSize: 512,
    mfcc: 40,
  );
  // mfccs is flattened column-major: data[row + rows * col].
} on PlatformException catch (e) {
  // e.code is 'INVALID_ARGUMENTS' or 'CALCULATION_FAILED', see Errors.
}
```

## API Reference

`getFeatureMatrix` calculates the MFCC matrix of the provided audio samples.

* `signals`: raw mono audio samples (`List<double>`); must not be empty.
* `sampleRate`: sample rate of `signals` in Hz; positive.
* `hopLength`: number of samples between successive frames; positive.
* `nMels`: number of mel filters; positive.
* `fftSize`: FFT window size in samples; positive.
* `mfcc`: number of MFCC coefficients to calculate; positive.
* Returns a `Future<Float64List?>` with the native MFCC matrix flattened column-major (`data[row + rows * col]`), the same layout on Android and iOS. Dimensions are not returned; derive them from the parameters. Errors are thrown, not returned as `null` (see below).

### Errors

Failures complete the future with a `PlatformException`; the codes are the same on Android and iOS.

| Code | When |
|---|---|
| `INVALID_ARGUMENTS` | `signals` is empty, an argument is missing or has the wrong type, or `sampleRate`, `hopLength`, `nMels`, `fftSize` or `mfcc` is not positive. `message` names the argument. |
| `CALCULATION_FAILED` | The native MFCC library failed for valid arguments (for example a signal that is too short for the chosen parameters) or returned an empty matrix. `message` carries the library's reason. |

## Example: fixed-input check

The [example app](example/lib/main.dart) has a **Run fixed-input check** button that computes MFCCs of a fixed signal — `0.5 * sin(2π · 1000 · n / 16000)` for 16000 samples (1 s, 1 kHz) with `sampleRate` 16000, `fftSize` 512, `hopLength` 350, `nMels` 40, `mfcc` 40 — and shows the output length, the first five values and their sum (also written to the console with `debugPrint`). Run it on Android and on iOS to compare both platforms by hand: the lengths must match and the values should agree within a small tolerance. Further buttons exercise a 100-sample signal, an empty signal, `hopLength` 0 and a mistyped argument, and show the resulting error code.

## Contributing
Contributions to FlutterSoundProcessing are welcome! If you find a bug or want to add a new feature, please open an issue or submit a pull request on the [GitHub repository](https://github.com/tkas9mbek/flutter_sound_processing).

## License
This project is licensed under the [MIT License](https://github.com/tkas9mbek/flutter_sound_processing/blob/master/LICENSE).
