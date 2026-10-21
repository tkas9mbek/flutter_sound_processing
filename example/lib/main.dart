import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_sound_processing/flutter_sound_processing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

const int bufferSize = 7839;
const int sampleRate = 16000;
const int hopLength = 350;
const int nMels = 40;
const int fftSize = 512;
const int mfcc = 40;

/// 1 s of a 1 kHz sine at [sampleRate]; the shared Android/iOS parity fixture.
const int fixtureLength = 16000;

/// Frames dropped at each end before averaging, so encoder delay/padding does not dominate the means.
const int edgeFrames = 3;

/// Raw channel used only to send arguments that the typed API cannot express.
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
  final pcm = Int16List(bufferSize);
  late StreamSubscription _mRecordingDataSubscription;
  late StreamController<Uint8List> _recordingDataController;
  final pathController = TextEditingController();
  int indexSignal = 0;
  bool running = false;
  int inFlight = 0;
  final checkOutput = <String>[];

  @override
  void initState() {
    super.initState();
  }

  @override
  Future<void> dispose() async {
    pathController.dispose();
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

      for (var offset = 0; offset + 1 < samples.length; offset += 2) {
        pcm[indexSignal] = byteData.getInt16(offset, Endian.little);
        indexSignal++;

        if (indexSignal == bufferSize) {
          indexSignal = 0;

          final featureMatrix = await _flutterSoundProcessingPlugin
              .calculateMFCCsFromPcm16(
                samples: Int16List.fromList(pcm),
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

  /// The PCM16 form of [sine]: `round(x * 32767)`, as in the committed wav fixtures.
  Int16List sinePcm16(int count) =>
      Int16List.fromList(sine(count).map((x) => (x * 32767).round()).toList());

  Future<Float64List?> calculate(List<double> input, {int hop = hopLength}) =>
      _flutterSoundProcessingPlugin.calculateMFCCs(
        signals: input,
        sampleRate: sampleRate,
        hopLength: hop,
        nMels: nMels,
        fftSize: fftSize,
        mfcc: mfcc,
      );

  Future<Float64List?> calculateFile(
    String path, {
    int hop = hopLength,
    int coefficients = mfcc,
  }) => _flutterSoundProcessingPlugin.calculateMFCCsFromFile(
    path: path,
    sampleRate: sampleRate,
    hopLength: hop,
    nMels: nMels,
    fftSize: fftSize,
    mfcc: coefficients,
  );

  /// Copies a bundled asset into the temporary directory and returns its absolute path.
  Future<String> copyAsset(String name) async {
    final data = await rootBundle.load('assets/$name');
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$name');

    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    report('copied $name to ${file.path}');

    return file.path;
  }

  /// Writes (once) a [seconds]-long 16 kHz mono PCM16 wav of the 1 kHz sine and returns its path.
  Future<String> generateWav(int seconds) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/sine_1khz_16k_${seconds}s.wav');
    final second = Uint8List.view(sinePcm16(sampleRate).buffer);
    final dataLength = second.length * seconds;

    if (await file.exists() && await file.length() == 44 + dataLength) {
      return file.path;
    }

    final header = ByteData(44)
      ..setUint32(0, 0x52494646) // 'RIFF'
      ..setUint32(4, 36 + dataLength, Endian.little)
      ..setUint32(8, 0x57415645) // 'WAVE'
      ..setUint32(12, 0x666d7420) // 'fmt '
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little) // PCM
      ..setUint16(22, 1, Endian.little) // mono
      ..setUint32(24, sampleRate, Endian.little)
      ..setUint32(28, sampleRate * 2, Endian.little)
      ..setUint16(32, 2, Endian.little)
      ..setUint16(34, 16, Endian.little)
      ..setUint32(36, 0x64617461) // 'data'
      ..setUint32(40, dataLength, Endian.little);
    final sink = file.openWrite()..add(header.buffer.asUint8List());

    for (var i = 0; i < seconds; i++) {
      sink.add(second);
    }

    await sink.close();
    report('generated ${seconds}s wav at ${file.path}');

    return file.path;
  }

  String summarize(Float64List? result, {int coefficients = mfcc}) {
    if (result == null) {
      return 'null';
    }

    final first = result.take(5).map((v) => v.toStringAsFixed(6)).join(', ');
    final sum = result.fold<double>(0, (total, v) => total + v);
    final frames = result.length ~/ coefficients;

    return 'length=${result.length} frames=$frames '
        'length%$coefficients=${result.length % coefficients} first5=[$first] '
        'sum=${sum.toStringAsFixed(6)} '
        'means=${interiorMeans(result, coefficients)}';
  }

  /// Per-coefficient means over frames [edgeFrames] … frames − edgeFrames − 1 (layout `data[row + rows * col]`).
  String interiorMeans(Float64List result, int coefficients) {
    final frames = result.length ~/ coefficients;

    if (frames <= 2 * edgeFrames) {
      return 'n/a';
    }

    final means = List<String>.generate(coefficients, (row) {
      var total = 0.0;

      for (var col = edgeFrames; col < frames - edgeFrames; col++) {
        total += result[row + coefficients * col];
      }

      return (total / (frames - 2 * edgeFrames)).toStringAsFixed(4);
    });

    return '[${means.join(', ')}]';
  }

  String maxAbsDiff(Float64List? a, Float64List? b) {
    if (a == null || b == null || a.length != b.length) {
      return 'n/a (lengths ${a?.length} vs ${b?.length})';
    }

    var diff = 0.0;

    for (var i = 0; i < a.length; i++) {
      diff = math.max(diff, (a[i] - b[i]).abs());
    }

    return diff.toStringAsExponential(3);
  }

  void report(String line) {
    debugPrint(line);

    if (!mounted) {
      return;
    }

    setState(() => checkOutput.insert(0, line));
  }

  Future<void> runCheck(String label, Future<String> Function() check) async {
    setState(() => inFlight++);
    final stopwatch = Stopwatch()..start();
    String line;

    try {
      line = await check();
    } on PlatformException catch (e) {
      line = 'PlatformException(${e.code}, ${e.message}, ${e.details})';
    } catch (e) {
      line = 'error $e';
    }

    if (mounted) {
      setState(() => inFlight--);
    }

    report('$label (${stopwatch.elapsedMilliseconds} ms): $line');
  }

  Widget checkButton(String label, Future<Float64List?> Function() calc) =>
      textCheckButton(label, () async => summarize(await calc()));

  Widget textCheckButton(String label, Future<String> Function() check) =>
      OutlinedButton(
        onPressed: () => runCheck(label, check),
        child: Text(label),
      );

  Widget fileButton(String asset) =>
      checkButton(asset, () async => calculateFile(await copyAsset(asset)));

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
          actions: [
            if (inFlight > 0)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ElevatedButton(
              onPressed: running ? pause : start,
              child: Text(running ? 'Pause' : 'Start'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Fixed-input check: 0.5*sin(2*pi*1000*n/$sampleRate), '
              'n_fft $fftSize, hop $hopLength, n_mels $nMels, mfcc $mfcc',
            ),
            Wrap(
              spacing: 8,
              children: [
                checkButton(
                  'Run fixed-input check',
                  () => calculate(sine(fixtureLength)),
                ),
                textCheckButton('PCM16 fixed input', () async {
                  final doubles = await calculate(sine(fixtureLength));
                  final pcm16 = await _flutterSoundProcessingPlugin
                      .calculateMFCCsFromPcm16(
                        samples: sinePcm16(fixtureLength),
                        sampleRate: sampleRate,
                        hopLength: hopLength,
                        nMels: nMels,
                        fftSize: fftSize,
                        mfcc: mfcc,
                      );

                  return '${summarize(pcm16)} '
                      'maxAbsDiffVsDoubles=${maxAbsDiff(pcm16, doubles)}';
                }),
                checkButton('100 samples', () => calculate(sine(100))),
                checkButton('Empty signal', () => calculate(const [])),
                checkButton(
                  'hopLength 0',
                  () => calculate(sine(fixtureLength), hop: 0),
                ),
                checkButton(
                  'Mistyped n_fft',
                  () =>
                      debugChannel.invokeMethod<Float64List>('calculateMFCCs', {
                        'values': Float64List.fromList(sine(100)),
                        'sample_rate': sampleRate,
                        'mfcc': mfcc,
                        'n_fft': '$fftSize',
                        'n_mels': nMels,
                        'hop_length': hopLength,
                      }),
                ),
                checkButton(
                  'values as List<double>',
                  () =>
                      debugChannel.invokeMethod<Float64List>('calculateMFCCs', {
                        'values': sine(fixtureLength),
                        'sample_rate': sampleRate,
                        'mfcc': mfcc,
                        'n_fft': fftSize,
                        'n_mels': nMels,
                        'hop_length': hopLength,
                      }),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'File checks: assets copied to the temporary directory, '
              'decoded natively, resampled to $sampleRate Hz',
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final asset in [
                  'sine_1khz_16k.wav',
                  'sine_1khz_16k.flac',
                  'sine_1khz_16k.mp3',
                  'sine_1khz_16k.m4a',
                  'sine_1khz_44k1.wav',
                ])
                  fileButton(asset),
                textCheckButton('wav vs PCM16', () async {
                  final file = await calculateFile(
                    await copyAsset('sine_1khz_16k.wav'),
                  );
                  final pcm16 = await _flutterSoundProcessingPlugin
                      .calculateMFCCsFromPcm16(
                        samples: sinePcm16(fixtureLength),
                        sampleRate: sampleRate,
                        hopLength: hopLength,
                        nMels: nMels,
                        fftSize: fftSize,
                        mfcc: mfcc,
                      );

                  return 'maxAbsDiff=${maxAbsDiff(file, pcm16)}';
                }),
                checkButton(
                  'wav as file:// URL',
                  () async => calculateFile(
                    Uri.file(await copyAsset('sine_1khz_16k.wav')).toString(),
                  ),
                ),
                textCheckButton('wav, mfcc 13', () async {
                  final result = await calculateFile(
                    await copyAsset('sine_1khz_16k.wav'),
                    coefficients: 13,
                  );

                  return summarize(result, coefficients: 13);
                }),
              ],
            ),
            const SizedBox(height: 24),
            const Text('File errors and limits'),
            Wrap(
              spacing: 8,
              children: [
                checkButton(
                  'hopLength 0, missing path',
                  () => calculateFile('/does/not/exist.wav', hop: 0),
                ),
                checkButton(
                  'Missing path',
                  () => calculateFile('/does/not/exist.wav'),
                ),
                checkButton(
                  'content:// path',
                  () => calculateFile('content://media/external/audio/1'),
                ),
                fileButton('not_audio.txt'),
                fileButton('garbage.mp3'),
                checkButton(
                  'Generate 11-minute wav',
                  () async => calculateFile(await generateWav(11 * 60)),
                ),
                checkButton(
                  'Generate 9-minute wav',
                  () async => calculateFile(await generateWav(9 * 60)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: pathController,
              decoration: const InputDecoration(
                labelText: 'Absolute path or file:// URL',
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: checkButton(
                'Run on path',
                () => calculateFile(pathController.text.trim()),
              ),
            ),
            const SizedBox(height: 24),
            for (final line in checkOutput) SelectableText(line),
          ],
        ),
      ),
    );
  }
}
