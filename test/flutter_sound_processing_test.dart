import 'dart:typed_data';

import 'package:flutter_sound_processing/flutter_sound_processing.dart';
import 'package:flutter_sound_processing/flutter_sound_processing_method_channel.dart';
import 'package:flutter_sound_processing/flutter_sound_processing_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterSoundProcessingPlatform
    with MockPlatformInterfaceMixin
    implements FlutterSoundProcessingPlatform {
  final result = Float64List.fromList([0.5, 1.5]);
  Map<String, Object>? received;

  @override
  Future<Float64List?> getFeatureMatrix({
    required List<double> signals,
    required int sampleRate,
    required int hopLength,
    required int nMels,
    required int fftSize,
    required int mfcc,
  }) async {
    received = {
      'signals': signals,
      'sampleRate': sampleRate,
      'hopLength': hopLength,
      'nMels': nMels,
      'fftSize': fftSize,
      'mfcc': mfcc,
    };
    return result;
  }
}

void main() {
  final initialPlatform = FlutterSoundProcessingPlatform.instance;

  test('default instance is MethodChannelFlutterSoundProcessing', () {
    expect(initialPlatform, isA<MethodChannelFlutterSoundProcessing>());
  });

  group('FlutterSoundProcessing', () {
    late MockFlutterSoundProcessingPlatform mock;

    setUp(() {
      mock = MockFlutterSoundProcessingPlatform();
      FlutterSoundProcessingPlatform.instance = mock;
    });

    tearDown(() => FlutterSoundProcessingPlatform.instance = initialPlatform);

    test('getFeatureMatrix forwards every parameter and the result', () async {
      final result = await FlutterSoundProcessing().getFeatureMatrix(
        signals: [0.25, -0.75],
        sampleRate: 22050,
        hopLength: 256,
        nMels: 64,
        fftSize: 1024,
        mfcc: 20,
      );

      expect(mock.received, {
        'signals': [0.25, -0.75],
        'sampleRate': 22050,
        'hopLength': 256,
        'nMels': 64,
        'fftSize': 1024,
        'mfcc': 20,
      });
      expect(result, same(mock.result));
    });
  });
}
