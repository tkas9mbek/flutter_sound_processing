import 'dart:typed_data';

import 'flutter_sound_processing_platform_interface.dart';

class FlutterSoundProcessing {
  /// Retrieves the feature matrix from the audio signals.
  ///
  /// [signals] is a list of double values representing the audio signals.
  ///
  /// [sampleRate] specifies the sample rate of the audio signals.
  ///
  /// [hopLength] determines the hop length (in samples) used for analysis.
  ///
  /// [nMels] sets the number of Mel filters to be used in the analysis.
  ///
  /// [fftSize] defines the size of the FFT used for spectral analysis.
  ///
  /// [mfcc] specifies the number of MFCC coefficients to be calculated.
  ///
  /// The method returns a `Future<Float64List>` that resolves to the feature matrix,
  /// or null if there was an error during the calculation.
  Future<Float64List?> getFeatureMatrix({
    required List<double> signals,
    required int sampleRate,
    required int hopLength,
    required int nMels,
    required int fftSize,
    required int mfcc,
  }) =>
      FlutterSoundProcessingPlatform.instance.getFeatureMatrix(
        signals: signals,
        sampleRate: sampleRate,
        hopLength: hopLength,
        nMels: nMels,
        fftSize: fftSize,
        mfcc: mfcc,
      );
}
