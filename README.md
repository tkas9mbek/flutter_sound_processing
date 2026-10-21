# flutter_sound_processing

Calculates MFCCs (mel-frequency cepstral coefficients) natively on Android and iOS. Give it `double` samples, 16-bit PCM, or an audio file (mp3, wav, m4a/AAC, flac) that it decodes, downmixes and resamples natively; get back the MFCC matrix as one flat `Float64List`. Use it to prepare on-device input for a speech or audio ML model. It does not record or play audio.

Android and iOS return the same values for the same input. Android uses [jlibrosa](https://github.com/Subtitle-Synchronizer/jlibrosa); iOS runs a term-by-term mirror of jlibrosa's pipeline inside the plugin and uses [RosaKit](https://github.com/dhrebeniuk/RosaKit) only for the mel filterbank.

## Installation

```
flutter pub add flutter_sound_processing
```

| Platform | Requirements | Native dependency |
|---|---|---|
| Dart / Flutter | Dart 3.9 or newer, Flutter 3.35 or newer | — |
| Android | `minSdk` 24+, `compileSdk` 36+, JDK 17+, an Android Gradle Plugin supported by your Flutter release (the plugin declares AGP 9.1.0, the Flutter 3.47 template value) | jlibrosa 1.1.8 (Maven Central) |
| iOS | iOS 15.0+, Swift 5, CocoaPods | RosaKit `~> 0.0.11` |

The plugin declares no permissions. Reading shared storage (for example `READ_MEDIA_AUDIO` on Android) is the app's responsibility.

## Quick start

All three methods take the same five tuning parameters; only the input differs.

```dart
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_sound_processing/flutter_sound_processing.dart';

final processing = FlutterSoundProcessing();

// Mono samples as doubles, nominally in [-1, 1].
Future<Float64List?> fromDoubles(List<double> samples) =>
    processing.calculateMFCCs(
      signals: samples,
      sampleRate: 16000,
      hopLength: 350,
      nMels: 40,
      fftSize: 512,
      mfcc: 40,
    );

// 16-bit mono PCM. A List<int> becomes Int16List.fromList(list).
Future<Float64List?> fromPcm16(Int16List samples) =>
    processing.calculateMFCCsFromPcm16(
      samples: samples,
      sampleRate: 16000,
      hopLength: 350,
      nMels: 40,
      fftSize: 512,
      mfcc: 40,
    );

// An audio file the app can read; decoded natively and resampled to sampleRate.
Future<Float64List?> fromFile(String path) =>
    processing.calculateMFCCsFromFile(
      path: path,
      sampleRate: 16000,
      hopLength: 350,
      nMels: 40,
      fftSize: 512,
      mfcc: 40,
    );

Future<void> readResult() async {
  try {
    final data = (await fromFile('/absolute/path/to/speech.mp3'))!;
    final frames = data.length ~/ 40; // rows = mfcc, columns = frames
    final c0f5 = data[0 + 40 * 5]; // coefficient 0 of frame 5: data[row + rows * col]
  } on PlatformException catch (e) {
    // e.code is one of the codes in the Errors table.
  }
}
```

## API reference

Every method returns `Future<Float64List?>`: the MFCC matrix flattened column-major, `data[row + rows * col]`, with `rows = mfcc` and `frames = data.length ~/ mfcc`. The layout and the values are the same on Android and iOS. Failures complete the future with a `PlatformException` (see [Errors](#errors)); `null` is never returned. Decoding and calculation run off the platform main thread, one call at a time.

Shared parameters (all required `int`, all positive):

| Parameter | Meaning |
|---|---|
| `sampleRate` | Sample rate in Hz. The rate of the samples for `calculateMFCCs` and `calculateMFCCsFromPcm16`; the **target** rate for `calculateMFCCsFromFile`. |
| `hopLength` | Samples between successive frames. |
| `nMels` | Number of mel filters. |
| `fftSize` | FFT window size in samples. Validated but currently **ignored**: both platforms use 2048 (see [Known limitations](#known-limitations)). |
| `mfcc` | Number of coefficients (rows). May be larger than `nMels`. |

### `calculateMFCCs({required List<double> signals, ...})`

`signals`: raw mono samples, nominally in `[-1, 1]`; must not be empty. A `Float64List` is sent to native code without copying. Samples are rounded to 32-bit float natively (jlibrosa works in `float`; iOS mirrors it).

### `calculateMFCCsFromPcm16({required Int16List samples, ...})`

`samples`: 16-bit mono PCM; must not be empty. Each sample is divided by 32768 (range `[-1, 1)`), so the result equals `calculateMFCCs` on the normalised values.

### `calculateMFCCsFromFile({required String path, ...})`

* `path`: absolute filesystem path or `file://` URL. The format is detected from the content, not the extension. `content://` URIs are rejected with `INVALID_ARGUMENTS`: copy the file into app storage first (for example `getTemporaryDirectory()` from `path_provider`). On iOS, files from a document picker are security-scoped; call `startAccessingSecurityScopedResource()` or copy the file first, otherwise the call fails with `FILE_NOT_FOUND`.
* The audio is downmixed to mono (channel average), normalised to `[-1, 1)` and, when the file's rate differs from `sampleRate`, resampled natively. Both platforms use the same windowed-sinc resampler; it is adequate for MFCCs, not a hi-fi resampler.
* Files longer than 600 seconds are rejected with `FILE_TOO_LONG` before decoding. Memory use grows with the duration.

#### Supported formats

| Format | Container / codec | Guaranteed on |
|---|---|---|
| `.mp3` | MPEG-1/2 Layer III | Android + iOS |
| `.wav` | RIFF, 16-bit PCM, any channel count/rate | Android + iOS |
| `.m4a` / `.mp4` | AAC-LC | Android + iOS |
| `.flac` | FLAC | Android + iOS |
| `.ogg`, `.aiff`, ALAC, 24-bit wav, … | — | not guaranteed; may work on one platform only (`UNSUPPORTED_FORMAT` / `DECODE_FAILED` otherwise) |

## Errors

The codes are the same on Android and iOS, and so are the messages except for `CALCULATION_FAILED`. `message` starts with the offending argument; `details` carries the platform's own description where there is one. For `calculateMFCCsFromFile` the checks run in the order of the table, and arguments are validated before the file is touched.

| Code | When |
|---|---|
| `INVALID_ARGUMENTS` | `signals` / `samples` is empty, `path` is empty or a `content://` URI, an argument is missing or has the wrong type, or `sampleRate`, `hopLength`, `nMels`, `fftSize` or `mfcc` is not positive. |
| `FILE_NOT_FOUND` | `path` does not exist, is a directory or is not readable. |
| `UNSUPPORTED_FORMAT` | The file cannot be opened as audio, has no audio track, or the platform has no decoder for it. |
| `FILE_TOO_LONG` | The file is longer than 600 seconds (from the file's metadata, before decoding; Android also stops a file without duration metadata at 600 s). |
| `DECODE_FAILED` | The decoder failed after opening the file, produced an unsupported PCM encoding, or decoded no samples. A corrupt file fails with `UNSUPPORTED_FORMAT` or `DECODE_FAILED`, depending on the platform. |
| `CALCULATION_FAILED` | The native MFCC calculation failed for valid arguments (for example a signal shorter than 1025 samples) or returned an empty or non-finite matrix. The message differs between platforms (Android passes on jlibrosa's exception text). |

## Known limitations

* **`fftSize` is ignored.** jlibrosa 1.1.8's `generateMFCCFeatures` never applies its `n_fft` argument and always uses 2048; iOS does the same so that both platforms return the same values. The argument is still validated.
* **Minimum 1025 samples.** Centred framing needs `2048 / 2 + 1` samples; shorter signals (or files) fail with `CALCULATION_FAILED`.
* **Lossy formats can differ in length between platforms.** mp3 and AAC decoders handle encoder delay and padding differently, so the frame count may differ by a few frames between Android and iOS. Not yet verified on an iOS device.
* **File duration cap of 600 seconds.** Longer files are rejected with `FILE_TOO_LONG`.
* **Verification status.** The fixed-input check of the example app returns identical values on an Android emulator and an iOS simulator. The file-error cases have not been exercised in-app on iOS yet.

## Example app

The [example app](https://github.com/tkas9mbek/flutter_sound_processing/tree/master/example) is a manual test bench: a fixed-input check with reference values, a value dump for comparing both platforms, bundled mp3/wav/m4a/flac files, and one button per error code. See its [README](https://github.com/tkas9mbek/flutter_sound_processing/blob/master/example/README.md).

## Contributing

Contributions are welcome. If you find a bug or want to add a feature, open an issue or a pull request on the [GitHub repository](https://github.com/tkas9mbek/flutter_sound_processing).

## License

[MIT](https://github.com/tkas9mbek/flutter_sound_processing/blob/master/LICENSE).
