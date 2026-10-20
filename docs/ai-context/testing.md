# Testing — AI Context

Rules `T1`–`T4` are in [AGENTS.md](../../AGENTS.md).

**Core idea:** the Dart side is cheap to test and must be covered; the native side can't run under `flutter test`, so it is verified manually through `example/` on both platforms and kept small.

## Test types

| # | Type | Covers | Where |
|---|------|--------|-------|
| 1 | Channel contract | method name, argument keys/values, return casting (`T1`) | `test/flutter_sound_processing_method_channel_test.dart` |
| 2 | Delegation | `FlutterSoundProcessing` forwards every parameter to `FlutterSoundProcessingPlatform.instance` (`T2`) | `test/flutter_sound_processing_test.dart` |
| 3 | Platform-interface default | default instance is the method-channel one | same file as #2 |
| 4 | Native manual check | each method on Android **and** iOS with a known input (`T3`, `T4`) | `example/` |

## Patterns

Channel contract:

```dart
TestWidgetsFlutterBinding.ensureInitialized();
final channel = MethodChannelFlutterSoundProcessing().methodChannel;
MethodCall? captured;

setUp(() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    captured = call;
    return Float64List.fromList([1, 2, 3]);
  });
});

tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    .setMockMethodCallHandler(channel, null));
```

Assert `captured!.method == 'getFeatureMatrix'`, the exact argument map, and the returned `Float64List`.

Delegation: a `MockFlutterSoundProcessingPlatform with MockPlatformInterfaceMixin implements FlutterSoundProcessingPlatform`, assigned to `FlutterSoundProcessingPlatform.instance` in `setUp`; restore the original in `tearDown`.

## Native manual check (`T3`/`T4`)

Run `cd example && fvm flutter run` on an Android device/emulator and on an iOS simulator/device. Use one short fixed signal (e.g. a 1 kHz sine, 22050 Hz, 1 s) and record the first values and the output length; they must match across platforms within a small tolerance. Also try an empty list and a signal shorter than `fftSize` — behavior must match the documented API (`P6`).

## Don't

- ❌ Assert exact float equality for DSP output.
- ❌ Test the same delegation on every parameter in separate tests — one test passing distinct values is enough.
- ❌ Add a native unit-test harness unless the plan asks for it (heavy for a plugin this size).
- ❌ Leave the platform `instance` replaced after a test.
