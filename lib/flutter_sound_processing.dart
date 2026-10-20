import 'dart:typed_data';

import 'flutter_sound_processing_platform_interface.dart';

class FlutterSoundProcessing {
  /// Calculates the MFCC (mel-frequency cepstral coefficient) matrix of [signals] natively.
  ///
  /// [signals] are raw mono audio samples; [sampleRate] is in Hz; [hopLength] and [fftSize] are in
  /// samples; [nMels] is the number of mel filters; [mfcc] is the number of coefficients.
  ///
  /// Returns the native matrix flattened column-major (`data[row + rows * col]`), the same layout on
  /// Android and iOS; dimensions are not returned. Errors are not reported as `null`: the future
  /// completes with a `PlatformException` with code `INVALID_ARGUMENTS` when [signals] is empty or an
  /// integer parameter is not positive, and `CALCULATION_FAILED` when the native library fails or
  /// returns an empty matrix.
  Future<Float64List?> getFeatureMatrix({
    required List<double> signals,
    required int sampleRate,
    required int hopLength,
    required int nMels,
    required int fftSize,
    required int mfcc,
  }) => FlutterSoundProcessingPlatform.instance.getFeatureMatrix(
    signals: signals,
    sampleRate: sampleRate,
    hopLength: hopLength,
    nMels: nMels,
    fftSize: fftSize,
    mfcc: mfcc,
  );
}
