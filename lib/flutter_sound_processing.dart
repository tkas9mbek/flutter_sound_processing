import 'dart:typed_data';

import 'flutter_sound_processing_platform_interface.dart';

/// Calculates MFCCs (mel-frequency cepstral coefficients) natively on Android and iOS.
///
/// Every method returns the native MFCC matrix flattened column-major (`data[row + rows * col]`)
/// with `rows = mfcc` and `frames = result.length ~/ mfcc`, the same layout on Android and iOS.
/// Decoding and calculation run off the platform main thread. Errors are not reported as `null`:
/// the future completes with a `PlatformException` whose code is the same on both platforms.
class FlutterSoundProcessing {
  /// Calculates the MFCC matrix of [signals] natively.
  ///
  /// [signals] are raw mono audio samples, nominally in `[-1, 1]`; [sampleRate] is their rate in Hz;
  /// [hopLength] is in samples; [nMels] is the number of mel filters; [mfcc] is the number of
  /// coefficients. [fftSize] (in samples) is validated but currently has no effect on either
  /// platform: jlibrosa on Android ignores it and uses a fixed 2048, and iOS does the same so both
  /// return the same values. Fails with `INVALID_ARGUMENTS` when [signals] is empty or an integer
  /// parameter is not positive, and `CALCULATION_FAILED` when the native calculation fails or returns
  /// an empty matrix (for example a signal shorter than 1025 samples, half the 2048 FFT plus one).
  Future<Float64List?> calculateMFCCs({
    required List<double> signals,
    required int sampleRate,
    required int hopLength,
    required int nMels,
    required int fftSize,
    required int mfcc,
  }) => FlutterSoundProcessingPlatform.instance.calculateMFCCs(
    signals: signals,
    sampleRate: sampleRate,
    hopLength: hopLength,
    nMels: nMels,
    fftSize: fftSize,
    mfcc: mfcc,
  );

  /// Calculates the MFCC matrix of 16-bit mono PCM [samples].
  ///
  /// Each sample is divided by 32768 (range `[-1, 1)`) and the result equals [calculateMFCCs] on the
  /// normalised values; pass a `List<int>` as `Int16List.fromList(list)`. The other parameters and
  /// the error codes are those of [calculateMFCCs].
  Future<Float64List?> calculateMFCCsFromPcm16({
    required Int16List samples,
    required int sampleRate,
    required int hopLength,
    required int nMels,
    required int fftSize,
    required int mfcc,
  }) => FlutterSoundProcessingPlatform.instance.calculateMFCCsFromPcm16(
    samples: samples,
    sampleRate: sampleRate,
    hopLength: hopLength,
    nMels: nMels,
    fftSize: fftSize,
    mfcc: mfcc,
  );

  /// Decodes the audio file at [path] natively and calculates its MFCC matrix.
  ///
  /// [path] is an absolute filesystem path or a `file://` URL of an mp3, wav (16-bit PCM),
  /// m4a/AAC-LC or flac file, detected by content; `content://` URIs are rejected — copy the file
  /// into app storage first. The audio is downmixed to mono, normalised to `[-1, 1)` and resampled to
  /// the target [sampleRate] in Hz; files longer than 600 s are rejected. The other parameters are
  /// those of [calculateMFCCs].
  ///
  /// Error codes, checked in this order: `INVALID_ARGUMENTS` (before any file access),
  /// `FILE_NOT_FOUND`, `UNSUPPORTED_FORMAT`, `FILE_TOO_LONG`, `DECODE_FAILED` (a corrupt file fails
  /// with `UNSUPPORTED_FORMAT` or `DECODE_FAILED`), `CALCULATION_FAILED`.
  Future<Float64List?> calculateMFCCsFromFile({
    required String path,
    required int sampleRate,
    required int hopLength,
    required int nMels,
    required int fftSize,
    required int mfcc,
  }) => FlutterSoundProcessingPlatform.instance.calculateMFCCsFromFile(
    path: path,
    sampleRate: sampleRate,
    hopLength: hopLength,
    nMels: nMels,
    fftSize: fftSize,
    mfcc: mfcc,
  );
}
