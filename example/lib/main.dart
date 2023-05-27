import 'dart:typed_data';

import 'package:flutter/material.dart';
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
  final signals = List<double>.filled(
    bufferSize,
    0,
  );
  late StreamSubscription _mRecordingDataSubscription;
  late StreamController<Food> _recordingDataController;
  int indexSignal = 0;
  bool running = false;

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

    _recordingDataController = StreamController<Food>();
    await _mRecorder.openRecorder();

    _mRecordingDataSubscription = _recordingDataController.stream.listen(
      (dynamic buffer) async {
        if (buffer is FoodData && buffer.data != null) {
          final samples = Uint8List.fromList(buffer.data!);
          final byteData = samples.buffer.asByteData();

          for (var offset = 0; offset < samples.length; offset += 2) {
            signals[indexSignal] =
                byteData.getInt16(offset, Endian.little).toDouble();
            indexSignal++;

            if (indexSignal == bufferSize) {
              indexSignal = 0;

              final featureMatrix =
                  await _flutterSoundProcessingPlugin.getFeatureMatrix(
                signals: signals,
                fftSize: fftSize,
                hopLength: hopLength,
                nMels: nMels,
                mfcc: mfcc,
                sampleRate: sampleRate,
              );

              print(featureMatrix?.toList());
            }
          }
        }
      },
    );

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: ElevatedButton(
            onPressed: running ? pause : start,
            child: Text(running ? 'Pause' : 'Start'),
          ),
        ),
      ),
    );
  }
}
