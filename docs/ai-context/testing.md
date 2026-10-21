# Testing — AI Context

Rules `T1`–`T4` are in [AGENTS.md](../../AGENTS.md).

**Core idea:** the Dart side is cheap to test and must be covered; the native side can't run under `flutter test`, so it is verified manually through `example/` on both platforms and kept small.

## Test types

| # | Type | Covers | Where |
|---|------|--------|-------|
| 1 | Channel contract | method name, argument keys/values (`values` is a `Float64List`), return casting, `PlatformException` passthrough for every code, PCM16 ÷ 32768 equivalence (`T1`) | `test/flutter_sound_processing_method_channel_test.dart` (16 tests as of 1.0.0) |
| 2 | Delegation | `FlutterSoundProcessing` forwards every parameter of all three methods to `FlutterSoundProcessingPlatform.instance`, inputs unconverted (`T2`) | `test/flutter_sound_processing_test.dart` (4 tests as of 1.0.0, incl. #3) |
| 3 | Platform-interface default | default instance is the method-channel one | same file as #2 |
| 4 | Native manual check | each method on Android **and** iOS with a known input (`T3`, `T4`) | `example/` — buttons and reference values in `example/README.md` |

## Patterns

Channel contract (as in the test file):

```dart
TestWidgetsFlutterBinding.ensureInitialized();
final platform = MethodChannelFlutterSoundProcessing();
final channel = platform.methodChannel;
final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
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
```

Assert `captured.single.method == 'calculateMFCCs'` (or `'calculateMFCCsFromFile'`), the exact argument map (`values` must be a `Float64List`), and the returned `Float64List`. `calculateMFCCsFromPcm16` is checked by comparing its captured call with `calculateMFCCs` on the same values divided by 32768. Errors: `mockReply((_) async => throw PlatformException(code: …))` and `throwsA(isA<PlatformException>().having((e) => e.code, 'code', …))`.

Delegation: a `MockFlutterSoundProcessingPlatform with MockPlatformInterfaceMixin implements FlutterSoundProcessingPlatform`, assigned to `FlutterSoundProcessingPlatform.instance` in `setUp`; restore the original in `tearDown`. One test per method with distinct values; assert the `Int16List` / `String` arrive `same()` (unconverted).

## Native manual check (`T3`/`T4`)

Run `cd example && fvm flutter run` on an Android device/emulator and on an iOS simulator/device. Use the example's fixed input (1 kHz sine, 16000 Hz, 1 s; `fftSize` 512, `hopLength` 350, `nMels` 40, `mfcc` 40) and compare the printed `length`, `first5` and `sum` with the reference values in `example/README.md` (`length=1840`, identical on both platforms as of 1.0.0). For a positional comparison use "Dump fixed-input values" (`MFCC_DUMP` console lines, 25 values each) on both platforms and diff the two dumps with a script. Also try an empty list (`INVALID_ARGUMENTS`), a signal shorter than 1025 samples (`CALCULATION_FAILED`; `fftSize` is ignored, the effective FFT size is 2048) and `hopLength 0` (`INVALID_ARGUMENTS`) — behavior must match the documented API (`P6`).

File input uses the fixtures in `example/assets/` (1 kHz sine, amplitude 0.5, 1 s; PCM16 `round(x * 32767)`, half away from zero): `sine_1khz_16k.{wav,mp3,m4a,flac}`, `sine_1khz_44k1.wav` (resampler), `not_audio.txt`, `garbage.mp3` (4 KiB random bytes). wav and flac must equal the PCM16 fixed input; mp3 and m4a are compared on `means` only (encoder delay changes the frame count). Regenerate them from `example/assets/` with Python 3 and ffmpeg (record the ffmpeg/LAME versions — encoder delay depends on them):

```bash
python3 -I - <<'PY'
import math, struct, wave
def sine(rate, name):
    w = wave.open(name, 'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
    frames = bytearray()
    for n in range(rate):
        x = 0.5 * math.sin(2 * math.pi * 1000 * n / rate) * 32767
        frames += struct.pack('<h', int(x + 0.5) if x >= 0 else int(x - 0.5))
    w.writeframes(bytes(frames)); w.close()
sine(16000, 'sine_1khz_16k.wav')
sine(44100, 'sine_1khz_44k1.wav')
PY
ffmpeg -y -i sine_1khz_16k.wav -c:a libmp3lame -b:a 128k sine_1khz_16k.mp3
ffmpeg -y -i sine_1khz_16k.wav -c:a aac -b:a 128k sine_1khz_16k.m4a
ffmpeg -y -i sine_1khz_16k.wav -c:a flac sine_1khz_16k.flac
printf 'not an audio file\n' > not_audio.txt
head -c 4096 /dev/urandom > garbage.mp3
```

The 9- and 11-minute wavs for the duration cap are generated at runtime by the example, not committed.

Record in the PR/branch which platforms were exercised and which buttons (`TEST-3`); anything not run on a platform is documented as "not verified on <platform>", not assumed.

## Don't

- ❌ Assert exact float equality for DSP output.
- ❌ Test the same delegation on every parameter in separate tests — one test passing distinct values is enough.
- ❌ Add a native unit-test harness unless the plan asks for it (heavy for a plugin this size); host harnesses live in `work/` (git-ignored).
- ❌ Leave the platform `instance` replaced after a test.
