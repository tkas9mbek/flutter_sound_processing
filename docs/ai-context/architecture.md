# Architecture — AI Context

Rules `P1`–`P6` are in [AGENTS.md](../../AGENTS.md). Facts about this plugin: [plugin-context.md](../project/plugin-context.md).

## Layers

```
FlutterSoundProcessing                   lib/flutter_sound_processing.dart                 public API, no logic (P1)
  → FlutterSoundProcessingPlatform       lib/flutter_sound_processing_platform_interface.dart   abstract + token-verified instance (P2)
    → MethodChannelFlutterSoundProcessing lib/flutter_sound_processing_method_channel.dart      builds the argument map, calls the channel
      → native plugin                     android/…/FlutterSoundProcessingPlugin.java, ios/Classes/SwiftFlutterSoundProcessingPlugin.swift
```

| Layer | Owns | Never |
|---|---|---|
| Public API | Argument names, dartdoc, defaults | Channel names, platform checks, DSP logic |
| Platform interface | The method signatures every implementation must satisfy | Implementation, imports of `dart:io` platform checks |
| Method channel | `MethodChannel` name, method names, argument keys, result casting | Business logic, validation beyond what native needs |
| Native | Calling the audio library, converting types, flattening the result | Extra public methods not declared in the platform interface |

## Channel contract (`P3`)

Three places must agree — change them in one commit:

| Item | Dart | Android | iOS |
|---|---|---|---|
| Channel name | `MethodChannel('flutter_sound_processing')` | `MethodChannel(…, "flutter_sound_processing")` | `FlutterMethodChannel(name: "flutter_sound_processing")` |
| Method name | `'getFeatureMatrix'` | `call.method.equals(…)` | `call.method == …` |
| Argument keys | map literal in the method channel | `call.argument("…")` | `arguments["…"]` |
| Result | `Float64List?` | `double[]` | `FlutterStandardTypedData(float64:)` |

The method name shown is the 0.1.0 one; 1.0.0 renames it to `calculateMFCCs` (see [plugin-context](../project/plugin-context.md)). Keys are `snake_case` strings; Dart parameter names are `lowerCamelCase` (`fftSize` → `'n_fft'`). Add a comment on both sides naming the counterpart file (`rules.md`).

## Adding a method

1. Planner writes `work/plans/<slug>.md` — API shape, channel keys, return layout, semver impact (`R1`).
2. Dart tests first (`testing.md` `T1`, `T2`) — fail for the expected reason.
3. Platform interface: add the abstract method (a new abstract method is **breaking for third-party platform implementations** — note it in the CHANGELOG).
4. Method channel implementation → public API delegation → dartdoc (`S4`).
5. Android and iOS handlers together (`P4`): same keys, same layout, same behavior for empty/invalid input (`P6`).
6. `example/` — add a call so both platforms can be exercised manually (`T3`).
7. README API reference + CHANGELOG entry (`P5`).

## Don't

- ❌ Put logic in `FlutterSoundProcessing` — it only delegates.
- ❌ Rename a channel/argument key on one side only.
- ❌ Return different matrix layouts per platform.
- ❌ Swallow native exceptions into an empty result.
- ❌ Add a native method that isn't on `FlutterSoundProcessingPlatform`.
- ❌ Bump `jlibrosa` / `RosaKit` or platform minimums as a side effect of another change.
