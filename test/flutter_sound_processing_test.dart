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
  String? method;
  Map<String, Object>? received;

  Future<Float64List?> _record(
    String name,
    String inputKey,
    Object input, {
    required int sampleRate,
    required int hopLength,
    required int nMels,
    required int fftSize,
    required int mfcc,
  }) async {
    method = name;
    received = {
      inputKey: input,
      'sampleRate': sampleRate,
      'hopLength': hopLength,
      'nMels': nMels,
      'fftSize': fftSize,
      'mfcc': mfcc,
    };
    return result;
  }

  @override
  Future<Float64List?> calculateMFCCs({
    required List<double> signals,
    required int sampleRate,
    required int hopLength,
    required int nMels,
    required int fftSize,
    required int mfcc,
  }) => _record(
    'calculateMFCCs',
    'signals',
    signals,
    sampleRate: sampleRate,
    hopLength: hopLength,
    nMels: nMels,
    fftSize: fftSize,
    mfcc: mfcc,
  );

  @override
  Future<Float64List?> calculateMFCCsFromPcm16({
    required Int16List samples,
    required int sampleRate,
    required int hopLength,
    required int nMels,
    required int fftSize,
    required int mfcc,
  }) => _record(
    'calculateMFCCsFromPcm16',
    'samples',
    samples,
    sampleRate: sampleRate,
    hopLength: hopLength,
    nMels: nMels,
    fftSize: fftSize,
    mfcc: mfcc,
  );

  @override
  Future<Float64List?> calculateMFCCsFromFile({
    required String path,
    required int sampleRate,
    required int hopLength,
    required int nMels,
    required int fftSize,
    required int mfcc,
  }) => _record(
    'calculateMFCCsFromFile',
    'path',
    path,
    sampleRate: sampleRate,
    hopLength: hopLength,
    nMels: nMels,
    fftSize: fftSize,
    mfcc: mfcc,
  );
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

    const tuning = {
      'sampleRate': 22050,
      'hopLength': 256,
      'nMels': 64,
      'fftSize': 1024,
      'mfcc': 20,
    };

    test('calculateMFCCs forwards every parameter and the result', () async {
      final signals = [0.25, -0.75];

      final result = await FlutterSoundProcessing().calculateMFCCs(
        signals: signals,
        sampleRate: 22050,
        hopLength: 256,
        nMels: 64,
        fftSize: 1024,
        mfcc: 20,
      );

      expect(mock.method, 'calculateMFCCs');
      expect(mock.received, {'signals': signals, ...tuning});
      expect(mock.received!['signals'], same(signals));
      expect(result, same(mock.result));
    });

    test(
      'calculateMFCCsFromPcm16 forwards the Int16List unconverted',
      () async {
        final samples = Int16List.fromList([16384, -32768, 1]);

        final result = await FlutterSoundProcessing().calculateMFCCsFromPcm16(
          samples: samples,
          sampleRate: 22050,
          hopLength: 256,
          nMels: 64,
          fftSize: 1024,
          mfcc: 20,
        );

        expect(mock.method, 'calculateMFCCsFromPcm16');
        expect(mock.received, {'samples': samples, ...tuning});
        expect(mock.received!['samples'], same(samples));
        expect(result, same(mock.result));
      },
    );

    test('calculateMFCCsFromFile forwards the path unconverted', () async {
      final result = await FlutterSoundProcessing().calculateMFCCsFromFile(
        path: 'file:///tmp/b.flac',
        sampleRate: 22050,
        hopLength: 256,
        nMels: 64,
        fftSize: 1024,
        mfcc: 20,
      );

      expect(mock.method, 'calculateMFCCsFromFile');
      expect(mock.received, {'path': 'file:///tmp/b.flac', ...tuning});
      expect(result, same(mock.result));
    });
  });
}
