import AVFoundation

/// Decodes an audio file to mono samples in [-1, 1) at the file's sample rate.
///
/// Mirrors android/src/main/java/kg/cos9/flutter_sound_processing/AudioFileDecoder.java: same order of checks
/// (existence, open, duration, decode), same normalisation (16-bit / 32768) and downmix (channel average) and the
/// same failure reasons.
enum AudioFileDecoder {
    private static let chunkFrames: AVAudioFrameCount = 65_536

    /// `reason` is platform-independent; `detail` carries the platform's own description.
    enum DecodeError: Error {
        case fileNotFound
        case tooLong(maxDurationSeconds: Int)
        case unsupported(detail: String?)
        case decodeFailed(reason: String, detail: String?)

        var reason: String {
            switch self {
            case .fileNotFound: return "file not found or not readable"
            case .tooLong(let maxDurationSeconds): return "longer than \(maxDurationSeconds) seconds"
            case .unsupported: return "unsupported audio format"
            case .decodeFailed(let reason, _): return reason
            }
        }

        var detail: String? {
            switch self {
            case .fileNotFound, .tooLong: return nil
            case .unsupported(let detail): return detail
            case .decodeFailed(_, let detail): return detail
            }
        }
    }

    static func decode(url: URL, maxDurationSeconds: Int) throws -> (mono: [Double], sampleRate: Int) {
        var isDirectory: ObjCBool = false

        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue,
              FileManager.default.isReadableFile(atPath: url.path) else {
            throw DecodeError.fileNotFound
        }

        let file: AVAudioFile

        do {
            file = try AVAudioFile(forReading: url)
        } catch {
            throw DecodeError.unsupported(detail: error.localizedDescription)
        }

        let fileRate = file.fileFormat.sampleRate

        if fileRate > 0, Double(file.length) / fileRate > Double(maxDurationSeconds) {
            throw DecodeError.tooLong(maxDurationSeconds: maxDurationSeconds)
        }

        // processingFormat is float32 deinterleaved; 16-bit sources arrive as int16 / 32768.
        let format = file.processingFormat
        let channelCount = Int(format.channelCount)
        let sampleRate = Int(format.sampleRate.rounded())

        guard format.commonFormat == .pcmFormatFloat32, channelCount > 0, sampleRate > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkFrames),
              let channels = buffer.floatChannelData else {
            throw DecodeError.decodeFailed(reason: "unsupported PCM encoding", detail: "\(format)")
        }

        var mono = [Double]()
        mono.reserveCapacity(max(0, Int(file.length)))

        while file.framePosition < file.length {
            do {
                try file.read(into: buffer, frameCount: chunkFrames)
            } catch {
                throw DecodeError.decodeFailed(reason: "decoding failed", detail: error.localizedDescription)
            }

            let frames = Int(buffer.frameLength)

            if frames == 0 {
                break
            }

            // mono[i] = (sum over channels of x[c][i]) / channelCount, summed in double.
            for i in 0..<frames {
                var sum = 0.0

                for c in 0..<channelCount {
                    sum += Double(channels[c][i])
                }

                mono.append(sum / Double(channelCount))
            }
        }

        if mono.isEmpty {
            throw DecodeError.decodeFailed(reason: "no audio samples decoded", detail: nil)
        }

        return (mono, sampleRate)
    }
}
