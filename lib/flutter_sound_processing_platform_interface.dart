import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_sound_processing_method_channel.dart';

abstract class FlutterSoundProcessingPlatform extends PlatformInterface {
  /// Constructs a FlutterSoundProcessingPlatform.
  FlutterSoundProcessingPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterSoundProcessingPlatform _instance = MethodChannelFlutterSoundProcessing();

  /// The default instance of [FlutterSoundProcessingPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterSoundProcessing].
  static FlutterSoundProcessingPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterSoundProcessingPlatform] when
  /// they register themselves.
  static set instance(FlutterSoundProcessingPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<Float64List?> getFeatureMatrix({
    required List<double> signals,
    required int sampleRate,
    required int hopLength,
    required int nMels,
    required int fftSize,
    required int mfcc,
  });
}
