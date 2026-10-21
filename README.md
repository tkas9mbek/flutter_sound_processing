# flutter_sound_processing

Flutter plugin that calculates MFCCs (mel-frequency cepstral coefficients) natively on Android and iOS — from `double` samples, from 16-bit PCM integers, or from an audio file (mp3, wav, m4a/AAC, flac) that it decodes, downmixes and resamples natively. It does not record or play audio; use it, for example, to feed a speech or audio ML model.

## Installation

`flutter pub add flutter_sound_processing`

| Platform | Requirements | Native library |
|---|---|---|
| Dart / Flutter | Dart 3.9 or newer, Flutter 3.35 or newer | — |
| Android | `minSdk` 24 or higher, `compileSdk` 36 or higher, JDK 17 or newer, an Android Gradle Plugin supported by your Flutter release (the plugin declares AGP 9.1.0, the Flutter 3.47 template value) | jlibrosa 1.1.8 (Maven Central) |
| iOS | iOS 15.0 or higher, Swift 5 | [RosaKit](https://github.com/dhrebeniuk/RosaKit) `~> 0.0.11` (CocoaPods) |

## Usage

```dart
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_sound_processing/flutter_sound_processing.dart';

final processing = FlutterSoundProcessing();

try {
  // Mono samples as doubles, nominally in [-1, 1].
  final fromDoubles = await processing.calculateMFCCs(
    signals: samples,
    sampleRate: 16000,
    hopLength: 350,
    nMels: 40,
    fftSize: 512,
    mfcc: 40,
  );

  // 16-bit mono PCM; a List<int> becomes Int16List.fromList(list).
  final fromPcm16 = await processing.calculateMFCCsFromPcm16(
    samples: Int16List.fromList(pcmInts),
    sampleRate: 16000,
    hopLength: 350,
    nMels: 40,
    fftSize: 512,
    mfcc: 40,
  );

  // An audio file the app already holds; resampled to sampleRate.
  final fromFile = await processing.calculateMFCCsFromFile(
    path: '/absolute/path/to/speech.mp3',
    sampleRate: 16000,
    hopLength: 350,
    nMels: 40,
    fftSize: 512,
    mfcc: 40,
  );

  // Flattened column-major: data[row + rows * col], rows = mfcc.
  final frames = fromFile!.length ~/ 40;
} on PlatformException catch (e) {
  // e.code is one of the codes in Errors.
}
```

## API Reference

All three methods return a `Future<Float64List?>` with the native MFCC matrix flattened column-major (`data[row + rows * col]`), with `rows = mfcc` and `frames = result.length ~/ mfcc`, the same layout on Android and iOS. Errors are thrown as `PlatformException`, never returned as `null` (see [Errors](#errors)). Decoding and calculation run off the platform main thread; calls are processed one at a time.

Shared parameters (all required, all positive):

* `sampleRate`: sample rate in Hz — of the samples for `calculateMFCCs` / `calculateMFCCsFromPcm16`, the **target** rate for `calculateMFCCsFromFile`.
* `hopLength`: number of samples between successive frames.
* `nMels`: number of mel filters.
* `fftSize`: FFT window size in samples.
* `mfcc`: number of MFCC coefficients to calculate.

### `calculateMFCCs`

* `signals`: raw mono audio samples (`List<double>`), nominally in `[-1, 1]`; must not be empty. A `Float64List` is sent without copying.

### `calculateMFCCsFromPcm16`

* `samples`: 16-bit mono PCM (`Int16List`); must not be empty. Each sample is divided by 32768 (range `[-1, 1)`), so the result equals `calculateMFCCs` on the normalised values. Pass a `List<int>` as `Int16List.fromList(list)`.

### `calculateMFCCsFromFile`

* `path`: absolute filesystem path or `file://` URL of the audio file. The format is detected from the content, not the extension. `content://` URIs are rejected with `INVALID_ARGUMENTS` — copy the file into app storage (for example `getTemporaryDirectory()` from `path_provider`) first. On iOS, files from a document picker are security-scoped: call `startAccessingSecurityScopedResource()` or copy the file first, otherwise the call fails with `FILE_NOT_FOUND`.
* The audio is downmixed to mono (channel average), normalised to `[-1, 1)` and, when the file's rate differs from `sampleRate`, resampled natively with the same windowed-sinc resampler on both platforms (adequate for MFCCs, not a hi-fi resampler).
* Files longer than 600 seconds are rejected with `FILE_TOO_LONG` before decoding (Android also stops decoding at 600 s when the file has no duration metadata). Memory use grows with the duration, most on iOS.
* The plugin declares no storage permission; reading shared storage (`READ_MEDIA_AUDIO` on Android) is the app's responsibility.

#### Supported formats

| Format | Container / codec | Guaranteed on |
|---|---|---|
| `.mp3` | MPEG-1/2 Layer III | Android + iOS |
| `.wav` | RIFF, 16-bit PCM, any channel count/rate | Android + iOS |
| `.m4a` / `.mp4` | AAC-LC | Android + iOS |
| `.flac` | FLAC | Android + iOS |
| `.ogg`, `.aiff`, ALAC, 24-bit wav, … | — | not guaranteed; may work on one platform only (`UNSUPPORTED_FORMAT` / `DECODE_FAILED` otherwise) |

Lossy formats (mp3, AAC) can decode to slightly different lengths on Android and iOS because the platform decoders handle encoder delay and padding differently, so the frame count may differ by a few frames.

### Errors

Failures complete the future with a `PlatformException`; the codes and messages are the same on Android and iOS, and `message` starts with the offending argument. For `calculateMFCCsFromFile` the checks run in the order of the table; arguments are validated before the file is touched.

| Code | When |
|---|---|
| `INVALID_ARGUMENTS` | `signals` / `samples` is empty, `path` is empty or a `content://` URI, an argument is missing or has the wrong type, or `sampleRate`, `hopLength`, `nMels`, `fftSize` or `mfcc` is not positive. |
| `FILE_NOT_FOUND` | `path` does not exist, is a directory or is not readable. |
| `UNSUPPORTED_FORMAT` | The file cannot be opened as audio, has no audio track, or the platform has no decoder for it. `details` carries the platform's description. |
| `FILE_TOO_LONG` | The file is longer than 600 seconds (checked from the file's metadata before decoding). |
| `DECODE_FAILED` | The decoder failed after opening the file, produced an unsupported PCM encoding, or decoded no samples. A corrupt file fails with either `UNSUPPORTED_FORMAT` or `DECODE_FAILED`, depending on the platform. |
| `CALCULATION_FAILED` | The native MFCC library failed for valid arguments (for example a signal too short for `fftSize`) or returned an empty matrix. `message` carries the library's reason. |

## Example: fixed-input and file checks

The [example app](example/lib/main.dart) has a **Run fixed-input check** button that computes MFCCs of a fixed signal — `0.5 * sin(2π · 1000 · n / 16000)` for 16000 samples (1 s, 1 kHz) with `sampleRate` 16000, `fftSize` 512, `hopLength` 350, `nMels` 40, `mfcc` 40 — and shows the output length, the first five values, their sum and the per-coefficient means over the interior frames (also written to the console with `debugPrint`). Run it on Android and on iOS to compare both platforms by hand: the lengths must match and the values should agree within a small tolerance. Further buttons run the same sine as PCM16 and as bundled mp3 / wav / m4a / flac / 44.1 kHz wav files, exercise the error codes (missing file, `content://`, a text file, random bytes, a generated 11-minute wav) and accept an arbitrary path; a progress indicator in the app bar shows the UI stays responsive while a call runs.

## Contributing
Contributions to FlutterSoundProcessing are welcome! If you find a bug or want to add a new feature, please open an issue or submit a pull request on the [GitHub repository](https://github.com/tkas9mbek/flutter_sound_processing).

## License
This project is licensed under the [MIT License](https://github.com/tkas9mbek/flutter_sound_processing/blob/master/LICENSE).
