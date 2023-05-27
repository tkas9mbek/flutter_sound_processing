import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_sound_processing_platform_interface.dart';

/// An implementation of [FlutterSoundProcessingPlatform] that uses method channels.
class MethodChannelFlutterSoundProcessing
    extends FlutterSoundProcessingPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_sound_processing');

  @override
  Future<Float64List?> getFeatureMatrix({
    required List<double> signals,
    required int sampleRate,
    required int hopLength,
    required int nMels,
    required int fftSize,
    required int mfcc,
  }) async {
    final arguments = <String, dynamic>{
      'values': signals,
      'sample_rate': sampleRate,
      'mfcc': mfcc,
      'n_fft': fftSize,
      'n_mels': nMels,
      'hop_length': hopLength,
    };

    final featureMatrix = await methodChannel.invokeMethod<Float64List>(
      'getFeatureMatrix',
      arguments,
    );

    return featureMatrix;
  }
}
