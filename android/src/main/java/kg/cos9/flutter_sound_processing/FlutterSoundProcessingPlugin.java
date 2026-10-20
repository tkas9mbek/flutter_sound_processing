package kg.cos9.flutter_sound_processing;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.jlibrosa.audio.JLibrosa;

import java.util.List;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/** FlutterSoundProcessingPlugin */
public class FlutterSoundProcessingPlugin implements FlutterPlugin, MethodCallHandler {
  // Error codes, messages and argument keys mirror ios/Classes/SwiftFlutterSoundProcessingPlugin.swift
  // and lib/flutter_sound_processing_method_channel.dart — change all three together.
  private static final String INVALID_ARGUMENTS = "INVALID_ARGUMENTS";
  private static final String CALCULATION_FAILED = "CALCULATION_FAILED";
  private static final String[] POSITIVE_INT_KEYS = {"sample_rate", "mfcc", "n_fft", "n_mels", "hop_length"};

  private static final JLibrosa jLibrosa = new JLibrosa();
  private MethodChannel channel;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "flutter_sound_processing");
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    if (!call.method.equals("getFeatureMatrix")) {
      result.notImplemented();
      return;
    }

    if (!(call.arguments instanceof Map)) {
      result.error(INVALID_ARGUMENTS, "arguments: expected a map", null);
      return;
    }

    final String invalidArgument = invalidArgument((Map<?, ?>) call.arguments);

    if (invalidArgument != null) {
      result.error(INVALID_ARGUMENTS, invalidArgument, null);
      return;
    }

    final List<?> values = call.argument("values");
    final int sampleRate = call.argument("sample_rate");
    final int mfcc = call.argument("mfcc");
    final int nFFT = call.argument("n_fft");
    final int nMels = call.argument("n_mels");
    final int hopLength = call.argument("hop_length");

    final float[][] mfccValues;

    try {
      mfccValues = jLibrosa.generateMFCCFeatures(toFloatArray(values), sampleRate, mfcc, nFFT, nMels, hopLength);
    } catch (RuntimeException e) {
      result.error(CALCULATION_FAILED, String.valueOf(e.getMessage()), null);
      return;
    }

    if (mfccValues == null || mfccValues.length == 0 || mfccValues[0].length == 0) {
      result.error(CALCULATION_FAILED, "empty result", null);
      return;
    }

    result.success(flatten(mfccValues));
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
  }

  /** Returns why the arguments are invalid, or null if they are valid. */
  @Nullable
  private static String invalidArgument(Map<?, ?> arguments) {
    final Object values = arguments.get("values");

    if (!(values instanceof List) || ((List<?>) values).isEmpty()) {
      return "values: expected a non-empty list of doubles";
    }

    for (Object value : (List<?>) values) {
      if (!(value instanceof Number)) {
        return "values: expected a non-empty list of doubles";
      }
    }

    for (String key : POSITIVE_INT_KEYS) {
      final Object value = arguments.get(key);

      if (!(value instanceof Integer) || (Integer) value <= 0) {
        return key + ": expected a positive integer";
      }
    }

    return null;
  }

  private static float[] toFloatArray(List<?> values) {
    final float[] floats = new float[values.size()];

    for (int i = 0; i < values.size(); i++) {
      floats[i] = ((Number) values.get(i)).floatValue();
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
}
