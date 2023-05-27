package kg.cos9.flutter_sound_processing;

import androidx.annotation.NonNull;

import com.jlibrosa.audio.JLibrosa;

import java.util.ArrayList;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/** FlutterSoundProcessingPlugin */
public class FlutterSoundProcessingPlugin implements FlutterPlugin, MethodCallHandler {
  private static final JLibrosa jLibrosa = new JLibrosa();
  private MethodChannel channel;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "flutter_sound_processing");
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    if (call.method.equals("getFeatureMatrix")) {
      result.success(getFeatureMatrix(call.argument("values"),
              call.argument("sample_rate"),
              call.argument("mfcc"),
              call.argument("n_fft"),
              call.argument("n_mels"),
              call.argument("hop_length")));
    } else {
      result.notImplemented();
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
  }

  private double[] getFeatureMatrix(ArrayList<Double> values,
                                    int mSampleRate,
                                    int nMFCC,
                                    int n_fft,
                                    int n_mels,
                                    int hop_length) {
    float[] magValues = new float[values.size()];

    for (int i = 0; i < values.size(); i++) {
      magValues[i] = values.get(i).floatValue();
    }

    float[][] floatMatrix = jLibrosa.generateMFCCFeatures(magValues,
            mSampleRate,
            nMFCC,
            n_fft,
            n_mels,
            hop_length);

    int matrixLength = floatMatrix.length;
    int matrixWidth = floatMatrix[0].length;

    double[] framePredDaArray = new double[matrixWidth * matrixLength];

    for (int i = 0; i < matrixLength; i++) {
      for (int j = 0; j < matrixWidth; j++) {
        framePredDaArray[i + matrixLength * j] = floatMatrix[i][j];
      }
    }

    return framePredDaArray;
  }
}
