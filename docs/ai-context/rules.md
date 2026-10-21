# Rules — AI Context

Style rules `S1`–`S6` are in the [AGENTS.md](../../AGENTS.md) Code Style table. Lints come from `analysis_options.yaml` (`flutter_lints`; `android/` and `ios/` are excluded from the analyzer).

## Comments

- None unless the *why* is non-obvious (units, layout, platform quirk, invariant); never restate what the code says.
- Lines stay under 120 chars (code itself follows `dart format`).
- `///` on every public API member: 1–3 lines + parameters with units.
- Where Dart and native code must change together (channel keys, return layout, error codes), put a warning comment on BOTH sides naming the counterpart file.
- `ios/Classes/MfccCalculator.swift` cites jlibrosa 1.1.8 `AudioFeatureExtraction.java` line numbers per stage (`:N`); keep them accurate when editing.
- Good: "Flattened column-major (`data[row + rows * col]`) so Android and iOS return the same layout."

## Naming

| Kind | Convention | Example |
|------|-----------|---------|
| Class / File / Const | `PascalCase` / `snake_case` / `lowerCamelCase` | `FlutterSoundProcessing` / `flutter_sound_processing.dart` / `defaultHopLength` |
| Platform interface | `<Plugin>Platform` | `FlutterSoundProcessingPlatform` |
| Channel implementation | `MethodChannel<Plugin>` | `MethodChannelFlutterSoundProcessing` |
| Public method | verb + noun, mirrors the native method name (`calculateMFCCsFromPcm16` is Dart-only and reuses `calculateMFCCs`) | `calculateMFCCs`, `calculateMFCCsFromFile` |
| Channel argument key | `snake_case` | `sample_rate`, `n_fft` |
| Error code | `UPPER_SNAKE`, one constant per platform file, identical strings | `INVALID_ARGUMENTS`, `FILE_TOO_LONG` |
| Native helper | same name on both platforms | `AudioFileDecoder.java` / `AudioFileDecoder.swift`, `Resampler.java` / `Resampler.swift` |
| Test file | `<source_file>_test.dart` in `test/` | `flutter_sound_processing_method_channel_test.dart` |

No `Impl`/`Helper`/`Manager`/`Util` suffixes; file name == class name.

## Pubspec

1. `dependencies`: Flutter SDK first, then alphabetical; `dev_dependencies` the same, independently.
2. Keep the `environment` constraints and the `flutter.plugin.platforms` block (`package`, `pluginClass`) in sync with the native class names (`FlutterSoundProcessingPlugin` in Java and in the ObjC bridge `ios/Classes/FlutterSoundProcessingPlugin.m`).
3. `pubspec.lock` is not committed (library).
4. Don't add a runtime dependency for something `dart:typed_data` or `dart:math` covers.
5. `.pubignore` lists what stays out of the package (contributor docs, `.claude/`, `work/`, `.fvm*`); keep it in step with `.gitignore`.

## Forbidden

- ❌ `print` / `debugPrint` in `lib/` (the example app may `debugPrint`).
- ❌ `dart:io` `Platform.is*` checks in the public API — platform differences belong in native code.
- ❌ `// ignore:` without a one-line reason.
- ❌ Public members without dartdoc.
- ❌ Committing `build/`, `Pods/`, `.dart_tool/`, `work/`, `.claude/`, local `settings.local.json`.
