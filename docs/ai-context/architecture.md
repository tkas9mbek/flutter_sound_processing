# Architecture — AI Context

Rules `P1`–`P6` are in [AGENTS.md](../../AGENTS.md). Facts about this plugin: [plugin-context.md](../project/plugin-context.md).

## Layers

```
FlutterSoundProcessing                   lib/flutter_sound_processing.dart                 public API, no logic (P1)
  → FlutterSoundProcessingPlatform       lib/flutter_sound_processing_platform_interface.dart   abstract + token-verified instance (P2)
    → MethodChannelFlutterSoundProcessing lib/flutter_sound_processing_method_channel.dart      builds the argument map, calls the channel
      → native plugin                     android/…/FlutterSoundProcessingPlugin.java, ios/Classes/SwiftFlutterSoundProcessingPlugin.swift
                                          + AudioFileDecoder, Resampler (one mirrored file each per platform)
                                          + ios/Classes/MfccCalculator.swift (iOS MFCC pipeline; Android's is jlibrosa)
                                          + ios/Classes/FlutterSoundProcessingPlugin.{h,m} (ObjC bridge = pubspec pluginClass)
```

| Layer | Owns | Never |
|---|---|---|
| Public API | Argument names, dartdoc, defaults | Channel names, platform checks, DSP logic |
| Platform interface | The method signatures every implementation must satisfy | Implementation, imports of `dart:io` platform checks |
| Method channel | `MethodChannel` name, method names, argument keys, PCM16 → `Float64List` conversion, result casting | Business logic, validation beyond what native needs |
| Native | Argument validation, decoding/resampling, the MFCC computation (jlibrosa on Android, `MfccCalculator` on iOS), threading, flattening the result | Extra public methods not declared in the platform interface |

## Channel contract (`P3`)

Three places must agree — change them in one commit:

| Item | Dart | Android | iOS |
|---|---|---|---|
| Channel name | `MethodChannel('flutter_sound_processing')` | `MethodChannel(…, "flutter_sound_processing")` | `FlutterMethodChannel(name: "flutter_sound_processing")` |
| Method names | `'calculateMFCCs'` (used by both `calculateMFCCs` and `calculateMFCCsFromPcm16`), `'calculateMFCCsFromFile'` | `switch (call.method)` | `call.method == …` |
| Keys, `calculateMFCCs` | `values: Float64List` + `sample_rate`, `mfcc`, `n_fft`, `n_mels`, `hop_length` (ints) | `double[]` + 5 `Integer` | `FlutterStandardTypedData` (`.float64`) + 5 `Int` |
| Keys, `calculateMFCCsFromFile` | `path: String` + the same 5 ints | `String` + 5 `Integer` | `String` + 5 `Int` |
| Result | `Float64List?` | `double[]` | `FlutterStandardTypedData(float64:)` |
| Error codes | passthrough | `INVALID_ARGUMENTS`, `FILE_NOT_FOUND`, `FILE_TOO_LONG`, `UNSUPPORTED_FORMAT`, `DECODE_FAILED`, `CALCULATION_FAILED` | same strings; same messages except `CALCULATION_FAILED` (Android passes on jlibrosa's exception text, iOS has its own reasons) |
| Order of checks (file) | — | arguments → exists/readable → open (`UNSUPPORTED_FORMAT`) → duration (`FILE_TOO_LONG`) → decode (`DECODE_FAILED`) → MFCC | same |
| Threading | — | validate on the platform thread, work on one `ExecutorService`, `result.*` posted to the main `Handler` | validate on main, work on one serial `DispatchQueue`, `result(…)` on `DispatchQueue.main` |

Three Dart methods map to two native methods: `calculateMFCCsFromPcm16` divides by 32768 in Dart and reuses `'calculateMFCCs'`. Keys are `snake_case` strings; Dart parameter names are `lowerCamelCase` (`fftSize` → `'n_fft'`). The `n_fft` value is validated and then ignored by both platforms (jlibrosa uses 2048; iOS mirrors it with `jlibrosaFFTSize`). Add a comment on both sides naming the counterpart file (`rules.md`).

## Adding a method

1. Write a plan first (`work/plans/<slug>.md`, git-ignored scratch) — API shape, channel keys, return layout, semver impact (`R1`).
2. Dart tests first (`testing.md` `T1`, `T2`) — fail for the expected reason.
3. Platform interface: add the abstract method (a new abstract method is **breaking for third-party platform implementations** — note it in the CHANGELOG).
4. Method channel implementation → public API delegation → dartdoc (`S4`).
5. Android and iOS handlers together (`P4`): same keys, same layout, same behavior for empty/invalid input (`P6`).
6. `example/` — add a button so both platforms can be exercised manually (`T3`), and list it in `example/README.md`.
7. README API reference + CHANGELOG entry (`P5`).

## Don't

- ❌ Put logic in `FlutterSoundProcessing` — it only delegates.
- ❌ Rename a channel/argument key on one side only.
- ❌ Return different matrix layouts per platform.
- ❌ Swallow native exceptions into an empty result.
- ❌ Add a native method that isn't on `FlutterSoundProcessingPlatform`.
- ❌ Bump `jlibrosa` / `RosaKit` or platform minimums as a side effect of another change.
- ❌ Call RosaKit's `mfcc` / `melspectrogram` / `stft` on iOS — `mfcc` is undefined behaviour in 0.0.11 and the spectrogram does not match jlibrosa (see plugin-context); only `createMelFilter` is used.
