# flutter_sound_processing example

A manual test bench for the plugin. `flutter test` cannot reach native code, so this app is how the Android and iOS implementations are exercised and compared: run it on both platforms and compare the lines it prints.

## Run

```bash
cd example
fvm flutter run                # or: fvm flutter run -d <device id>; list devices with fvm flutter devices
```

The repository pins Flutter with FVM (`.fvmrc`); use `fvm flutter`, not the global SDK. The recorder (Start / Pause) needs the microphone permission; the example declares `RECORD_AUDIO` on Android and `NSMicrophoneUsageDescription` on iOS.

## What it prints

Every button runs one call and prints one line, on screen (newest first) and to the console with `debugPrint`:

```
<label> (<elapsed> ms): <result>
```

A successful result is summarised as `length=… frames=… length%N=… first5=[…] sum=… means=[…]`, where `means` are the per-coefficient means over the interior frames (the first and last three frames dropped, so encoder delay and padding do not dominate). A failure prints `PlatformException(<code>, <message>, <details>)`. A progress indicator in the app bar is shown while a call is in flight, which lets you see that the UI stays responsive.

All buttons use the constants at the top of `lib/main.dart`: `sampleRate` 16000, `hopLength` 350, `nMels` 40, `fftSize` 512, `mfcc` 40. The fixed input is `0.5 * sin(2π · 1000 · n / 16000)` for `n = 0 … 15999` (1 s of a 1 kHz sine at 16 kHz); its PCM16 form is `round(x * 32767)`, the same values as the bundled wav files.

## Buttons

**Start / Pause** records from the microphone with `flutter_sound` (PCM16, 16 kHz, mono) and converts every 7839-sample buffer with `calculateMFCCsFromPcm16`, printing the result to the console.

**Fixed-input check**

| Button | What it does | Expected |
|---|---|---|
| Run fixed-input check | `calculateMFCCs` on the fixed input | the reference line below |
| PCM16 fixed input | `calculateMFCCsFromPcm16` on the PCM16 form, plus `maxAbsDiffVsDoubles` against the double result | small difference (PCM quantisation) |
| Dump fixed-input values | the fixed-input result, every value written to the console as `MFCC_DUMP` lines | see below |
| mfcc 50 > nMels | `calculateMFCCs` with `mfcc: 50` | the reference line below |
| 100 samples | a 100-sample sine | `CALCULATION_FAILED` (fewer than 1025 samples) |
| Empty signal | an empty list | `INVALID_ARGUMENTS` |
| hopLength 0 | the fixed input with `hopLength: 0` | `INVALID_ARGUMENTS` |
| Mistyped n_fft | raw channel call with `n_fft` sent as a string | `INVALID_ARGUMENTS` |
| values as List\<double\> | raw channel call with `values` sent as a plain list instead of a `Float64List` | `INVALID_ARGUMENTS` |

**File checks** copy a bundled asset to the temporary directory and run `calculateMFCCsFromFile` on it (decoded natively, resampled to 16 kHz):

| Button | What it does | Expected |
|---|---|---|
| sine_1khz_16k.wav / .flac / .mp3 / .m4a | the 1 kHz sine as a file | wav and flac: same values as the PCM16 fixed input; mp3 and m4a: a few frames more or fewer (encoder delay and padding) and nearly equal `means` |
| sine_1khz_44k1.wav | the same sine at 44.1 kHz, resampled to 16 kHz by the plugin | `length=1840`, values close to the 16 kHz wav |
| wav vs PCM16 | `maxAbsDiff` between the wav result and `calculateMFCCsFromPcm16` on the same samples | about 0 |
| wav as file:// URL | the wav passed as a `file://` URL | same as the wav |
| wav, mfcc 13 | the wav with `mfcc: 13` | `length%13=0` |

**File errors and limits**

| Button | What it does | Expected |
|---|---|---|
| hopLength 0, missing path | invalid argument and a missing file | `INVALID_ARGUMENTS` (arguments are checked before the file) |
| Missing path | `/does/not/exist.wav` | `FILE_NOT_FOUND` |
| content:// path | a `content://` URI | `INVALID_ARGUMENTS` |
| not_audio.txt | a text file | `UNSUPPORTED_FORMAT` |
| garbage.mp3 | 4 KiB of random bytes | `UNSUPPORTED_FORMAT` or `DECODE_FAILED`; iOS may decode it (see below) |
| Generate 11-minute wav | writes an 11-minute 16 kHz wav once, then runs it | `FILE_TOO_LONG`, quickly |
| Generate 9-minute wav | writes a 9-minute wav once, then runs it | a result; takes a while |

**Run on path** runs `calculateMFCCsFromFile` on the absolute path or `file://` URL typed into the text field.

## Reference values

Verified identical on an Android emulator and an iOS simulator:

| Check | Verified output |
|---|---|
| Run fixed-input check | `length=1840 frames=46`, `first5=[-46.173168, 80.053398, -29.104691, -27.313852, -13.540855]`, `sum=-13152.940665` |
| mfcc 50 > nMels | `length=2300`, `sum=-13389.830271` |

The expected codes in the tables above come from the native validation code. The two lines in this table are the only values verified on both platforms; the file-error cases have not been exercised in-app on iOS, and on a macOS host `AVAudioFile` opened `garbage.mp3` as a single frame instead of failing, so iOS may return a result for it.

## MFCC_DUMP

"Dump fixed-input values" writes every value of the fixed-input result to the console on lines of the form

```
MFCC_DUMP run=<ms since epoch> platform=<android|ios> chunk=<i>/<n> offset=<index> total=<length> values=<v v …>
```

with 25 values per line at full round-trip precision. Collect the lines from both platforms (`adb logcat`, the Xcode console, or the `fvm flutter run` output) and compare them positionally with a short script; the Android and iOS values are expected to be identical.

## Assets

`assets/` holds the file fixtures: `sine_1khz_16k.{wav,mp3,m4a,flac}` and `sine_1khz_44k1.wav` (the 1 kHz sine, amplitude 0.5, 1 s), `not_audio.txt` and `garbage.mp3` (4 KiB of random bytes). The 9- and 11-minute wavs are generated at runtime and are not committed. The commands that regenerate the fixtures are in `docs/ai-context/testing.md` in the repository.
