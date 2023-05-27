import 'dart:typed_data';

import 'flutter_sound_processing_platform_interface.dart';

class FlutterSoundProcessing {
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
