import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_sound_processing_platform_interface.dart';

/// An implementation of [FlutterSoundProcessingPlatform] that uses method channels.
class MethodChannelFlutterSoundProcessing
    extends FlutterSoundProcessingPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_sound_processing');

  // Method names ('calculateMFCCs', 'calculateMFCCsFromFile') and keys mirror
  // android/.../FlutterSoundProcessingPlugin.java and ios/Classes/SwiftFlutterSoundProcessingPlugin.swift;
  // a native PlatformException propagates unchanged.
  @override
  Future<Float64List?> calculateMFCCs({
    required List<double> signals,
    required int sampleRate,
    required int hopLength,
    required int nMels,
    required int fftSize,
    required int mfcc,
  }) => _invoke('calculateMFCCs', {
    'values': _asFloat64List(signals),
    ..._tuning(sampleRate, hopLength, nMels, fftSize, mfcc),
  });

  @override
  Future<Float64List?> calculateMFCCsFromPcm16({
    required Int16List samples,
    required int sampleRate,
    required int hopLength,
    required int nMels,
    required int fftSize,
    required int mfcc,
  }) {
    // 16-bit PCM → [-1, 1); byte-identical payload to calculateMFCCs(signals: …).
    final values = Float64List(samples.length);

    for (var i = 0; i < samples.length; i++) {
      values[i] = samples[i] / 32768;
    }

    return _invoke('calculateMFCCs', {
      'values': values,
      ..._tuning(sampleRate, hopLength, nMels, fftSize, mfcc),
    });
  }

  @override
  Future<Float64List?> calculateMFCCsFromFile({
    required String path,
    required int sampleRate,
    required int hopLength,
    required int nMels,
    required int fftSize,
    required int mfcc,
  }) => _invoke('calculateMFCCsFromFile', {
    'path': path,
    ..._tuning(sampleRate, hopLength, nMels, fftSize, mfcc),
  });

  Future<Float64List?> _invoke(String method, Map<String, Object> arguments) =>
      methodChannel.invokeMethod<Float64List>(method, arguments);

  Float64List _asFloat64List(List<double> signals) =>
      signals is Float64List ? signals : Float64List.fromList(signals);

  Map<String, Object> _tuning(
    int sampleRate,
    int hopLength,
    int nMels,
    int fftSize,
    int mfcc,
  ) => {
    'sample_rate': sampleRate,
    'mfcc': mfcc,
    'n_fft': fftSize,
    'n_mels': nMels,
    'hop_length': hopLength,
  };
}
