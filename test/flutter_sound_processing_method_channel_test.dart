import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_sound_processing/flutter_sound_processing_method_channel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelFlutterSoundProcessing();
  final channel = platform.methodChannel;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  MethodCall? captured;

  tearDown(() {
    captured = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  void mockReply(Future<Object?> Function(MethodCall call) reply) {
    messenger.setMockMethodCallHandler(channel, (call) {
      captured = call;
      return reply(call);
    });
  }

  test('getFeatureMatrix sends the method name and argument map', () async {
    final expected = Float64List.fromList([1.5, -2.25, 3.125]);
    mockReply((_) async => expected);

    final result = await platform.getFeatureMatrix(
      signals: [0.1, -0.2, 0.3],
      sampleRate: 16000,
      hopLength: 350,
      nMels: 41,
      fftSize: 512,
      mfcc: 13,
    );

    expect(captured!.method, 'getFeatureMatrix');
    expect(captured!.arguments, {
      'values': [0.1, -0.2, 0.3],
      'sample_rate': 16000,
      'mfcc': 13,
      'n_fft': 512,
      'n_mels': 41,
      'hop_length': 350,
    });
    expect(result, isA<Float64List>());
    expect(result, orderedEquals(expected));
  });

  test(
    'getFeatureMatrix rethrows PlatformException from native code',
    () async {
      mockReply(
        (_) async => throw PlatformException(
          code: 'INVALID_ARGUMENTS',
          message: 'values: must not be empty',
        ),
      );

      await expectLater(
        platform.getFeatureMatrix(
          signals: [0.1],
          sampleRate: 16000,
          hopLength: 350,
          nMels: 40,
          fftSize: 512,
          mfcc: 40,
        ),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'INVALID_ARGUMENTS',
          ),
        ),
      );
    },
  );

  test(
    'getFeatureMatrix forwards empty signals without Dart validation',
    () async {
      mockReply((_) async => Float64List(0));

      await platform.getFeatureMatrix(
        signals: const [],
        sampleRate: 16000,
        hopLength: 350,
        nMels: 40,
        fftSize: 512,
        mfcc: 40,
      );

      expect(captured!.method, 'getFeatureMatrix');
      expect((captured!.arguments as Map)['values'], isEmpty);
    },
  );
}
