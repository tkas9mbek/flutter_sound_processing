import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_sound_processing/flutter_sound_processing.dart';
import 'package:permission_handler/permission_handler.dart';

const int bufferSize = 7839;
const int sampleRate = 16000;
const int hopLength = 350;
const int nMels = 40;
const int fftSize = 512;
const int mfcc = 40;

/// 1 s of a 1 kHz sine at [sampleRate]; the shared Android/iOS parity fixture.
const int fixtureLength = 16000;

/// Raw channel used only to send a mistyped argument that the typed API cannot express.
const debugChannel = MethodChannel('flutter_sound_processing');

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _flutterSoundProcessingPlugin = FlutterSoundProcessing();
  final _mRecorder = FlutterSoundRecorder();
  final signals = List<double>.filled(bufferSize, 0);
  late StreamSubscription _mRecordingDataSubscription;
  late StreamController<Uint8List> _recordingDataController;
  int indexSignal = 0;
  bool running = false;
  final checkOutput = <String>[];

  @override
  void initState() {
    super.initState();
  }

  @override
  Future<void> dispose() async {
    await closeRecorder();

    super.dispose();
  }

  Future<void> closeRecorder() async {
    await _mRecordingDataSubscription.cancel();
    await _recordingDataController.close();
    await _mRecorder.closeRecorder();
  }

  Future<void> start() async {
    final status = await Permission.microphone.request();

    if (!status.isGranted) {
      return;
    }

    setState(() {
      running = true;
    });

    _recordingDataController = StreamController<Uint8List>();
    await _mRecorder.openRecorder();

    _mRecordingDataSubscription = _recordingDataController.stream.listen((
      samples,
    ) async {
      final byteData = ByteData.sublistView(samples);

      for (var offset = 0; offset < samples.length; offset += 2) {
        signals[indexSignal] = byteData
            .getInt16(offset, Endian.little)
            .toDouble();
        indexSignal++;

        if (indexSignal == bufferSize) {
          indexSignal = 0;

          final featureMatrix = await _flutterSoundProcessingPlugin
              .getFeatureMatrix(
                signals: signals,
                fftSize: fftSize,
                hopLength: hopLength,
                nMels: nMels,
                mfcc: mfcc,
                sampleRate: sampleRate,
              );

          debugPrint('${featureMatrix?.toList()}');
        }
      }
    });

    await _mRecorder.startRecorder(
      toStream: _recordingDataController.sink,
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: sampleRate,
    );
  }

  void pause() {
    _mRecordingDataSubscription.pause();

    setState(() {
      running = false;
    });
  }

  List<double> sine(int count) => List<double>.generate(
    count,
    (n) => 0.5 * math.sin(2 * math.pi * 1000 * n / sampleRate),
  );

  Future<Float64List?> calculate(List<double> input, {int hop = hopLength}) =>
      _flutterSoundProcessingPlugin.getFeatureMatrix(
        signals: input,
        sampleRate: sampleRate,
        hopLength: hop,
        nMels: nMels,
        fftSize: fftSize,
        mfcc: mfcc,
      );

  String summarize(Float64List? result) {
    if (result == null) {
      return 'null';
    }

    final first = result.take(5).map((v) => v.toStringAsFixed(6)).join(', ');
    final sum = result.fold<double>(0, (total, v) => total + v);

    return 'length=${result.length} first5=[$first] '
        'sum=${sum.toStringAsFixed(6)}';
  }

  Future<void> runCheck(
    String label,
    Future<Float64List?> Function() calculation,
  ) async {
    String line;

    try {
      line = '$label: ${summarize(await calculation())}';
    } on PlatformException catch (e) {
      line = '$label: PlatformException(${e.code}, ${e.message})';
    }

    debugPrint(line);

    if (!mounted) {
      return;
    }

    setState(() => checkOutput.insert(0, line));
  }

  Widget checkButton(String label, Future<Float64List?> Function() calc) =>
      OutlinedButton(
        onPressed: () => runCheck(label, calc),
        child: Text(label),
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Plugin example app')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ElevatedButton(
              onPressed: running ? pause : start,
              child: Text(running ? 'Pause' : 'Start'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Fixed-input check:0.5*sin(2*pi*1000*n/$sampleRate), '
              'n_fft $fftSize, hop $hopLength, n_mels $nMels, mfcc $mfcc',
            ),
            Wrap(
              spacing: 8,
              children: [
                checkButton(
                  'Run fixed-input check',
                  () => calculate(sine(fixtureLength)),
                ),
                checkButton('100 samples', () => calculate(sine(100))),
                checkButton('Empty signal', () => calculate(const [])),
                checkButton(
                  'hopLength 0',
                  () => calculate(sine(fixtureLength), hop: 0),
                ),
                checkButton(
                  'Mistyped n_fft',
                  () => debugChannel
                      .invokeMethod<Float64List>('getFeatureMatrix', {
                        'values': sine(100),
                        'sample_rate': sampleRate,
                        'mfcc': mfcc,
                        'n_fft': '$fftSize',
                        'n_mels': nMels,
                        'hop_length': hopLength,
                      }),
                ),
              ],
            ),
            for (final line in checkOutput) SelectableText(line),
          ],
        ),
      ),
    );
  }
}
