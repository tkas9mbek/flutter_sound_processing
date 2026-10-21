package kg.cos9.flutter_sound_processing;

/**
 * Windowed-sinc resampler (Hann window, half-width 32 input samples, cutoff at the lower Nyquist).
 *
 * <p>Mirrors ios/Classes/Resampler.swift term by term (same constants, same ascending summation in double) so
 * Android and iOS produce the same samples. Adequate for MFCCs; not a hi-fi resampler.
 */
final class Resampler {
  private static final int HALF_WIDTH = 32;

  private Resampler() {}

  /** Returns [input] unchanged when the rates match. */
  static float[] resample(float[] input, int inRate, int outRate) {
    if (inRate == outRate) {
      return input;
    }

    final int inLength = input.length;
    final int outLength = (int) ((long) inLength * outRate / inRate);
    final double s = Math.min(1.0, (double) outRate / (double) inRate);
    final double halfWidth = HALF_WIDTH;
    final float[] output = new float[outLength];

    for (int m = 0; m < outLength; m++) {
      final double p = (double) m * (double) inRate / (double) outRate;
      final int kStart = (int) Math.ceil(p - halfWidth);
      final int kEnd = (int) Math.floor(p + halfWidth);
      double acc = 0;
      double norm = 0;

      for (int k = kStart; k <= kEnd; k++) {
        final double w = weight(k - p, s, halfWidth);
        norm += w;

        if (k >= 0 && k < inLength) {
          acc += input[k] * w;
        }
      }

      output[m] = (float) (acc / norm);
    }

    return output;
  }

  // w(t) = s * sinc(s * t) * hann(t / L); sinc(u) = sin(pi u) / (pi u), 1 at 0; hann(v) = 0.5 (1 + cos(pi v)), |v| <= 1.
  private static double weight(double t, double s, double halfWidth) {
    final double v = t / halfWidth;

    if (Math.abs(v) > 1.0) {
      return 0.0;
    }

    final double u = s * t;
    final double sinc = u == 0.0 ? 1.0 : Math.sin(Math.PI * u) / (Math.PI * u);

    return s * sinc * 0.5 * (1.0 + Math.cos(Math.PI * v));
  }
}
