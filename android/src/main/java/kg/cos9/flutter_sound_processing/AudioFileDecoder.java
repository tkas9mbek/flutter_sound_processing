package kg.cos9.flutter_sound_processing;

import android.media.AudioFormat;
import android.media.MediaCodec;
import android.media.MediaExtractor;
import android.media.MediaFormat;

import androidx.annotation.Nullable;

import java.io.File;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import java.nio.ShortBuffer;
import java.util.Arrays;

/**
 * Decodes an audio file to mono samples in [-1, 1) at the file's sample rate.
 *
 * <p>Mirrors ios/Classes/AudioFileDecoder.swift: same order of checks (existence, open, duration, decode), same
 * normalisation (16-bit / 32768) and downmix (channel average) and the same failure reasons.
 */
final class AudioFileDecoder {
  private static final long TIMEOUT_US = 10_000;

  private AudioFileDecoder() {}

  static final class Decoded {
    final float[] mono;
    final int sampleRate;

    Decoded(float[] mono, int sampleRate) {
      this.mono = mono;
      this.sampleRate = sampleRate;
    }
  }

  /** The message is the platform-independent reason; [detail] carries the platform's own description. */
  static class DecoderException extends Exception {
    @Nullable final String detail;

    DecoderException(String reason, @Nullable String detail) {
      super(reason);
      this.detail = detail;
    }
  }

  static final class FileNotFound extends DecoderException {
    FileNotFound() {
      super("file not found or not readable", null);
    }
  }

  static final class TooLong extends DecoderException {
    TooLong(int maxDurationSeconds) {
      super("longer than " + maxDurationSeconds + " seconds", null);
    }
  }

  static final class Unsupported extends DecoderException {
    Unsupported(@Nullable String detail) {
      super("unsupported audio format", detail);
    }
  }

  static final class DecodeFailed extends DecoderException {
    DecodeFailed(String reason, @Nullable String detail) {
      super(reason, detail);
    }
  }

  static Decoded decode(String path, int maxDurationSeconds) throws DecoderException {
    final File file = new File(path);

    if (!file.isFile() || !file.canRead()) {
      throw new FileNotFound();
    }

    final MediaExtractor extractor = new MediaExtractor();
    MediaCodec codec = null;

    try {
      try {
        extractor.setDataSource(path);
      } catch (IOException | RuntimeException e) {
        throw new Unsupported(String.valueOf(e.getMessage()));
      }

      MediaFormat format = null;
      String mime = null;

      for (int i = 0; i < extractor.getTrackCount(); i++) {
        final MediaFormat trackFormat = extractor.getTrackFormat(i);
        final String trackMime = trackFormat.getString(MediaFormat.KEY_MIME);

        if (trackMime != null && trackMime.startsWith("audio/")) {
          extractor.selectTrack(i);
          format = trackFormat;
          mime = trackMime;
          break;
        }
      }

      if (format == null) {
        throw new Unsupported("no audio track");
      }

      try {
        codec = MediaCodec.createDecoderByType(mime);
      } catch (IOException | RuntimeException e) {
        throw new Unsupported(mime + ": " + e.getMessage());
      }

      if (format.containsKey(MediaFormat.KEY_DURATION)
          && format.getLong(MediaFormat.KEY_DURATION) > maxDurationSeconds * 1_000_000L) {
        throw new TooLong(maxDurationSeconds);
      }

      try {
        return decodeTrack(extractor, codec, format, maxDurationSeconds);
      } catch (IllegalStateException | IllegalArgumentException e) {
        // MediaCodec.CodecException is an IllegalStateException.
        throw new DecodeFailed("decoding failed", String.valueOf(e.getMessage()));
      }
    } finally {
      if (codec != null) {
        codec.release();
      }

      extractor.release();
    }
  }

  private static Decoded decodeTrack(MediaExtractor extractor, MediaCodec codec, MediaFormat format,
      int maxDurationSeconds) throws DecoderException {
    codec.configure(format, null, null, 0);
    codec.start();

    // Channel count, rate and encoding come from the decoder's output format (HE-AAC doubles the rate).
    final OutputFormat outputFormat = new OutputFormat(codec.getOutputFormat());
    final MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
    float[] mono = new float[1 << 16];
    int length = 0;
    boolean inputDone = false;
    boolean outputDone = false;

    while (!outputDone) {
      if (!inputDone) {
        final int inputIndex = codec.dequeueInputBuffer(TIMEOUT_US);

        if (inputIndex >= 0) {
          final ByteBuffer inputBuffer = codec.getInputBuffer(inputIndex);
          final int size = inputBuffer == null ? -1 : extractor.readSampleData(inputBuffer, 0);

          if (size < 0) {
            codec.queueInputBuffer(inputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM);
            inputDone = true;
          } else {
            codec.queueInputBuffer(inputIndex, 0, size, extractor.getSampleTime(), 0);
            extractor.advance();
          }
        }
      }

      final int outputIndex = codec.dequeueOutputBuffer(info, TIMEOUT_US);

      if (outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
        outputFormat.update(codec.getOutputFormat());
      } else if (outputIndex >= 0) {
        final ByteBuffer outputBuffer = codec.getOutputBuffer(outputIndex);

        if (outputBuffer != null && info.size > 0) {
          outputFormat.check();
          outputBuffer.position(info.offset);
          outputBuffer.limit(info.offset + info.size);
          final ByteBuffer bytes = outputBuffer.slice().order(ByteOrder.LITTLE_ENDIAN);
          final int frames = info.size / (outputFormat.bytesPerSample() * outputFormat.channelCount);

          if (length + frames > mono.length) {
            mono = Arrays.copyOf(mono, Math.max(mono.length * 2, length + frames));
          }

          downmix(bytes, outputFormat, frames, mono, length);
          length += frames;
        }

        codec.releaseOutputBuffer(outputIndex, false);
        outputDone = (info.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0;

        // Enforces the cap when the container has no duration metadata.
        if ((long) length > (long) maxDurationSeconds * outputFormat.sampleRate) {
          throw new TooLong(maxDurationSeconds);
        }
      }
    }

    if (length == 0) {
      throw new DecodeFailed("no audio samples decoded", null);
    }

    return new Decoded(Arrays.copyOf(mono, length), outputFormat.sampleRate);
  }

  // mono[i] = (sum over channels of x[c][i]) / channelCount, summed in double; 16-bit samples / 32768.
  private static void downmix(ByteBuffer bytes, OutputFormat format, int frames, float[] mono, int offset) {
    final int channels = format.channelCount;

    if (format.encoding == AudioFormat.ENCODING_PCM_FLOAT) {
      final FloatBuffer samples = bytes.asFloatBuffer();

      for (int i = 0; i < frames; i++) {
        double sum = 0;

        for (int c = 0; c < channels; c++) {
          sum += samples.get(i * channels + c);
        }

        mono[offset + i] = (float) (sum / channels);
      }
    } else {
      final ShortBuffer samples = bytes.asShortBuffer();

      for (int i = 0; i < frames; i++) {
        double sum = 0;

        for (int c = 0; c < channels; c++) {
          sum += samples.get(i * channels + c) / 32768.0;
        }

        mono[offset + i] = (float) (sum / channels);
      }
    }
  }

  private static final class OutputFormat {
    int channelCount;
    int sampleRate;
    int encoding;

    OutputFormat(MediaFormat format) {
      update(format);
    }

    void update(MediaFormat format) {
      channelCount = format.containsKey(MediaFormat.KEY_CHANNEL_COUNT)
          ? format.getInteger(MediaFormat.KEY_CHANNEL_COUNT) : 0;
      sampleRate = format.containsKey(MediaFormat.KEY_SAMPLE_RATE)
          ? format.getInteger(MediaFormat.KEY_SAMPLE_RATE) : 0;
      encoding = format.containsKey(MediaFormat.KEY_PCM_ENCODING)
          ? format.getInteger(MediaFormat.KEY_PCM_ENCODING) : AudioFormat.ENCODING_PCM_16BIT;
    }

    void check() throws DecodeFailed {
      if (encoding != AudioFormat.ENCODING_PCM_16BIT && encoding != AudioFormat.ENCODING_PCM_FLOAT) {
        throw new DecodeFailed("unsupported PCM encoding", "encoding " + encoding);
      }

      if (channelCount <= 0 || sampleRate <= 0) {
        throw new DecodeFailed("unsupported PCM encoding", "output format without channel count or sample rate");
      }
    }

    int bytesPerSample() {
      return encoding == AudioFormat.ENCODING_PCM_FLOAT ? 4 : 2;
    }
  }
}
