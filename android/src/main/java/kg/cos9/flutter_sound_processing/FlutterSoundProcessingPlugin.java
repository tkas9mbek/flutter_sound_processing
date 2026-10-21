package kg.cos9.flutter_sound_processing;

import android.net.Uri;
import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.jlibrosa.audio.JLibrosa;

import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/** FlutterSoundProcessingPlugin */
public class FlutterSoundProcessingPlugin implements FlutterPlugin, MethodCallHandler {
  // Method names, error codes, messages and argument keys mirror ios/Classes/SwiftFlutterSoundProcessingPlugin.swift
  // (with AudioFileDecoder.swift, Resampler.swift) and lib/flutter_sound_processing_method_channel.dart —
  // change all three together.
  private static final String CALCULATE_MFCCS = "calculateMFCCs";
  private static final String CALCULATE_MFCCS_FROM_FILE = "calculateMFCCsFromFile";

  private static final String INVALID_ARGUMENTS = "INVALID_ARGUMENTS";
  private static final String CALCULATION_FAILED = "CALCULATION_FAILED";
  private static final String FILE_NOT_FOUND = "FILE_NOT_FOUND";
  private static final String UNSUPPORTED_FORMAT = "UNSUPPORTED_FORMAT";
  private static final String DECODE_FAILED = "DECODE_FAILED";
  private static final String FILE_TOO_LONG = "FILE_TOO_LONG";

  private static final String[] POSITIVE_INT_KEYS = {"sample_rate", "mfcc", "n_fft", "n_mels", "hop_length"};
  private static final int MAX_DURATION_SECONDS = 600;

  private static final JLibrosa jLibrosa = new JLibrosa();
  private MethodChannel channel;
  // One worker serialises decodes and MFCC work off the platform thread, bounding peak memory to one call.
  private ExecutorService executor;
  private Handler mainHandler;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "flutter_sound_processing");
    channel.setMethodCallHandler(this);
    executor = Executors.newSingleThreadExecutor();
    mainHandler = new Handler(Looper.getMainLooper());
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    switch (call.method) {
      case CALCULATE_MFCCS:
      case CALCULATE_MFCCS_FROM_FILE:
        break;
      default:
        result.notImplemented();
        return;
    }

    if (!(call.arguments instanceof Map)) {
      result.error(INVALID_ARGUMENTS, "arguments: expected a map", null);
      return;
    }

    final Map<?, ?> arguments = (Map<?, ?>) call.arguments;
    final boolean fromFile = call.method.equals(CALCULATE_MFCCS_FROM_FILE);
    final String invalidArgument = fromFile ? invalidPath(arguments.get("path")) : invalidValues(arguments.get("values"));
    final String invalid = invalidArgument != null ? invalidArgument : invalidInts(arguments);

    if (invalid != null) {
      result.error(INVALID_ARGUMENTS, invalid, null);
      return;
    }

    final int sampleRate = (Integer) arguments.get("sample_rate");
    final int mfcc = (Integer) arguments.get("mfcc");
    final int nFFT = (Integer) arguments.get("n_fft");
    final int nMels = (Integer) arguments.get("n_mels");
    final int hopLength = (Integer) arguments.get("hop_length");

    if (fromFile) {
      final String path = filePath((String) arguments.get("path"));
      runInBackground(result, () -> {
        final float[] signal = decodeAndResample(path, sampleRate);
        return calculate(signal, sampleRate, mfcc, nFFT, nMels, hopLength);
      });
    } else {
      final double[] values = (double[]) arguments.get("values");
      runInBackground(result, () -> calculate(toFloatArray(values), sampleRate, mfcc, nFFT, nMels, hopLength));
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
    executor.shutdownNow();
  }

  /** Runs [task] on the worker; every result call is posted back to the platform thread. */
  private void runInBackground(Result result, Task task) {
    executor.execute(() -> {
      try {
        final double[] data = task.run();
        mainHandler.post(() -> result.success(data));
      } catch (PluginError e) {
        mainHandler.post(() -> result.error(e.code, e.getMessage(), e.details));
      } catch (RuntimeException e) {
        final String message = String.valueOf(e.getMessage());
        mainHandler.post(() -> result.error(CALCULATION_FAILED, message, null));
      }
    });
  }

  private static float[] decodeAndResample(String path, int sampleRate) throws PluginError {
    final AudioFileDecoder.Decoded decoded;

    try {
      decoded = AudioFileDecoder.decode(path, MAX_DURATION_SECONDS);
    } catch (AudioFileDecoder.DecoderException e) {
      throw new PluginError(errorCode(e), "path: " + e.getMessage(), e.detail);
    }

    return Resampler.resample(decoded.mono, decoded.sampleRate, sampleRate);
  }

  private static String errorCode(AudioFileDecoder.DecoderException e) {
    if (e instanceof AudioFileDecoder.FileNotFound) {
      return FILE_NOT_FOUND;
    }

    if (e instanceof AudioFileDecoder.TooLong) {
      return FILE_TOO_LONG;
    }

    if (e instanceof AudioFileDecoder.Unsupported) {
      return UNSUPPORTED_FORMAT;
    }

    return DECODE_FAILED;
  }

  private static double[] calculate(float[] signal, int sampleRate, int mfcc, int nFFT, int nMels, int hopLength)
      throws PluginError {
    final float[][] mfccValues;

    try {
      mfccValues = jLibrosa.generateMFCCFeatures(signal, sampleRate, mfcc, nFFT, nMels, hopLength);
    } catch (RuntimeException e) {
      throw new PluginError(CALCULATION_FAILED, String.valueOf(e.getMessage()), null);
    }

    if (mfccValues == null || mfccValues.length == 0 || mfccValues[0].length == 0) {
      throw new PluginError(CALCULATION_FAILED, "empty result", null);
    }

    return flatten(mfccValues);
  }

  /** Returns why [values] is invalid, or null if it is valid. */
  @Nullable
  private static String invalidValues(Object values) {
    if (!(values instanceof double[]) || ((double[]) values).length == 0) {
      return "values: expected a non-empty Float64List";
    }

    return null;
  }

  /** Returns why [path] is invalid, or null if it is valid. */
  @Nullable
  private static String invalidPath(Object path) {
    if (!(path instanceof String) || ((String) path).isEmpty()) {
      return "path: expected a non-empty string";
    }

    if (((String) path).startsWith("content://")) {
      return "path: content:// URIs are not supported, copy the file into app storage first";
    }

    final String filePath = filePath((String) path);

    if (filePath == null || filePath.isEmpty()) {
      return "path: invalid file:// URL";
    }

    return null;
  }

  /** Returns why one of the positive integer arguments is invalid, or null if all are valid. */
  @Nullable
  private static String invalidInts(Map<?, ?> arguments) {
    for (String key : POSITIVE_INT_KEYS) {
      final Object value = arguments.get(key);

      if (!(value instanceof Integer) || (Integer) value <= 0) {
        return key + ": expected a positive integer";
      }
    }

    return null;
  }

  /** Accepts an absolute path or a file:// URL; returns the filesystem path. */
  @Nullable
  private static String filePath(String path) {
    return path.startsWith("file://") ? Uri.parse(path).getPath() : path;
  }

  private static float[] toFloatArray(double[] values) {
    final float[] floats = new float[values.length];

    for (int i = 0; i < values.length; i++) {
      floats[i] = (float) values[i];
    }

    return floats;
  }

  // Flattened column-major (data[row + rows * col]) so Android and iOS return the same layout.
  private static double[] flatten(float[][] matrix) {
    final int matrixLength = matrix.length;
    final int matrixWidth = matrix[0].length;

    final double[] framePredDaArray = new double[matrixWidth * matrixLength];

    for (int i = 0; i < matrixLength; i++) {
      for (int j = 0; j < matrixWidth; j++) {
        framePredDaArray[i + matrixLength * j] = matrix[i][j];
      }
    }

    return framePredDaArray;
  }

  private interface Task {
    double[] run() throws PluginError;
  }

  private static final class PluginError extends Exception {
    final String code;
    @Nullable final String details;

    PluginError(String code, String message, @Nullable String details) {
      super(message);
      this.code = code;
      this.details = details;
    }
  }
}
