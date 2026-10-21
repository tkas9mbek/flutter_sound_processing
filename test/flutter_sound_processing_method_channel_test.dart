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

  final captured = <MethodCall>[];

  tearDown(() {
    captured.clear();
    messenger.setMockMethodCallHandler(channel, null);
  });

  void mockReply(Future<Object?> Function(MethodCall call) reply) {
    messenger.setMockMethodCallHandler(channel, (call) {
      captured.add(call);
      return reply(call);
    });
  }

  Map<Object?, Object?> argumentsOf(MethodCall call) =>
      call.arguments as Map<Object?, Object?>;

  Matcher throwsPlatformCode(String code) =>
      throwsA(isA<PlatformException>().having((e) => e.code, 'code', code));

  group('calculateMFCCs', () {
    test('sends the method name, Float64List values and the keys', () async {
      final expected = Float64List.fromList([1.5, -2.25, 3.125]);
      mockReply((_) async => expected);

      final result = await platform.calculateMFCCs(
        signals: [0.1, -0.2, 0.3],
        sampleRate: 16000,
        hopLength: 350,
        nMels: 41,
        fftSize: 512,
        mfcc: 13,
      );

      final call = captured.single;
      final arguments = argumentsOf(call);
      expect(call.method, 'calculateMFCCs');
      expect(arguments.keys, unorderedEquals(_mfccKeys));
      expect(arguments['values'], isA<Float64List>());
      expect(arguments['values'], orderedEquals([0.1, -0.2, 0.3]));
      expect(arguments['sample_rate'], 16000);
      expect(arguments['mfcc'], 13);
      expect(arguments['n_fft'], 512);
      expect(arguments['n_mels'], 41);
      expect(arguments['hop_length'], 350);
      expect(result, isA<Float64List>());
      expect(result, orderedEquals(expected));
    });

    test('sends a Float64List argument with equal contents', () async {
      mockReply((_) async => Float64List(0));
      final signals = Float64List.fromList([0.25, -0.5, 0.75]);

      await platform.calculateMFCCs(
        signals: signals,
        sampleRate: 16000,
        hopLength: 350,
        nMels: 40,
        fftSize: 512,
        mfcc: 40,
      );

      final values = argumentsOf(captured.single)['values'];
      expect(values, isA<Float64List>());
      expect(values, orderedEquals(signals));
    });

    test('forwards empty signals without Dart validation', () async {
      mockReply((_) async => Float64List(0));

      await platform.calculateMFCCs(
        signals: const [],
        sampleRate: 16000,
        hopLength: 350,
        nMels: 40,
        fftSize: 512,
        mfcc: 40,
      );

      final values = argumentsOf(captured.single)['values'];
      expect(values, isA<Float64List>());
      expect(values, isEmpty);
    });

    test('rethrows PlatformException from native code', () async {
      mockReply(
        (_) async => throw PlatformException(
          code: 'INVALID_ARGUMENTS',
          message: 'values: must not be empty',
        ),
      );

      await expectLater(
        platform.calculateMFCCs(
          signals: [0.1],
          sampleRate: 16000,
          hopLength: 350,
          nMels: 40,
          fftSize: 512,
          mfcc: 40,
        ),
        throwsPlatformCode('INVALID_ARGUMENTS'),
      );
    });
  });

  group('calculateMFCCsFromPcm16', () {
    test(
      'sends the same call as calculateMFCCs with samples / 32768',
      () async {
        mockReply((_) async => Float64List(0));

        await platform.calculateMFCCsFromPcm16(
          samples: Int16List.fromList([16384, -32768, 1, 0]),
          sampleRate: 22050,
          hopLength: 256,
          nMels: 64,
          fftSize: 1024,
          mfcc: 20,
        );
        await platform.calculateMFCCs(
          signals: [0.5, -1.0, 1 / 32768, 0.0],
          sampleRate: 22050,
          hopLength: 256,
          nMels: 64,
          fftSize: 1024,
          mfcc: 20,
        );

        expect(captured, hasLength(2));
        final fromPcm16 = argumentsOf(captured[0]);
        final fromDoubles = argumentsOf(captured[1]);
        expect(captured[0].method, 'calculateMFCCs');
        expect(captured[1].method, 'calculateMFCCs');
        expect(fromPcm16.keys, unorderedEquals(fromDoubles.keys));
        expect(fromPcm16['values'], isA<Float64List>());
        expect(
          fromPcm16['values'],
          orderedEquals(fromDoubles['values'] as Float64List),
        );
        for (final key in _intKeys) {
          expect(fromPcm16[key], fromDoubles[key], reason: key);
        }
      },
    );

    test('sends empty samples as an empty Float64List', () async {
      mockReply((_) async => Float64List(0));

      await platform.calculateMFCCsFromPcm16(
        samples: Int16List(0),
        sampleRate: 16000,
        hopLength: 350,
        nMels: 40,
        fftSize: 512,
        mfcc: 40,
      );

      final call = captured.single;
      expect(call.method, 'calculateMFCCs');
      expect(argumentsOf(call)['values'], isA<Float64List>());
      expect(argumentsOf(call)['values'], isEmpty);
    });

    test('rethrows PlatformException from native code', () async {
      mockReply(
        (_) async => throw PlatformException(code: 'INVALID_ARGUMENTS'),
      );

      await expectLater(
        platform.calculateMFCCsFromPcm16(
          samples: Int16List(0),
          sampleRate: 16000,
          hopLength: 350,
          nMels: 40,
          fftSize: 512,
          mfcc: 40,
        ),
        throwsPlatformCode('INVALID_ARGUMENTS'),
      );
    });
  });

  group('calculateMFCCsFromFile', () {
    test('sends the method name, the path and the keys', () async {
      final expected = Float64List.fromList([4.5, -0.125]);
      mockReply((_) async => expected);

      final result = await platform.calculateMFCCsFromFile(
        path: '/tmp/a.mp3',
        sampleRate: 16000,
        hopLength: 350,
        nMels: 41,
        fftSize: 512,
        mfcc: 13,
      );

      final call = captured.single;
      expect(call.method, 'calculateMFCCsFromFile');
      expect(call.arguments, {
        'path': '/tmp/a.mp3',
        'sample_rate': 16000,
        'mfcc': 13,
        'n_fft': 512,
        'n_mels': 41,
        'hop_length': 350,
      });
      expect(result, isA<Float64List>());
      expect(result, orderedEquals(expected));
    });

    for (final path in ['', 'file:///x.wav']) {
      test('forwards "$path" unchanged', () async {
        mockReply((_) async => Float64List(0));

        await platform.calculateMFCCsFromFile(
          path: path,
          sampleRate: 16000,
          hopLength: 350,
          nMels: 40,
          fftSize: 512,
          mfcc: 40,
        );

        expect(argumentsOf(captured.single)['path'], path);
      });
    }

    for (final code in [
      'INVALID_ARGUMENTS',
      'FILE_NOT_FOUND',
      'UNSUPPORTED_FORMAT',
      'DECODE_FAILED',
      'FILE_TOO_LONG',
      'CALCULATION_FAILED',
    ]) {
      test('rethrows PlatformException $code from native code', () async {
        mockReply((_) async => throw PlatformException(code: code));

        await expectLater(
          platform.calculateMFCCsFromFile(
            path: '/tmp/a.mp3',
            sampleRate: 16000,
            hopLength: 350,
            nMels: 40,
            fftSize: 512,
            mfcc: 40,
          ),
          throwsPlatformCode(code),
        );
      });
    }
  });
}

const _intKeys = ['sample_rate', 'mfcc', 'n_fft', 'n_mels', 'hop_length'];

const _mfccKeys = ['values', ..._intKeys];
