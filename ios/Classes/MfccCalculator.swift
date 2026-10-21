import Foundation

/// MFCCs computed the way jlibrosa 1.1.8 does on Android (`AudioFeatureExtraction.extractMFCCFeatures`), term by
/// term, so both platforms return the same values. Line references (`:N`) are to
/// `com/jlibrosa/audio/process/AudioFeatureExtraction.java` in jlibrosa 1.1.8.
///
/// The mel filterbank is passed in (RosaKit's `createMelFilter`, which matches jlibrosa's `melFilter()`). RosaKit's
/// own `mfcc` is not used: it reads a `[[Double]]` as a flat buffer and returns NaN/garbage.
enum MfccCalculator {
    enum Failure: Error, Equatable {
        case tooShort(nFFT: Int)
        case nonPowerOfTwoFFT
        case filterbankMismatch
        case empty
        case nonFinite

        var reason: String {
            switch self {
            case .tooShort(let nFFT):
                return "values: need at least n_fft/2 + 1 = \(nFFT / 2 + 1) samples (n_fft \(nFFT)) for centred framing"
            case .nonPowerOfTwoFFT: return "n_fft: must be a power of two"
            case .filterbankMismatch: return "mel filterbank: expected n_mels rows of n_fft/2 + 1 weights"
            case .empty: return "empty result"
            case .nonFinite: return "result contains NaN or infinity"
            }
        }
    }

    /// Returns `nMFCC × frames` values laid out `data[coef + nMFCC * frame]` (`:130-139`).
    ///
    /// `melFilter` holds `nMels` rows of `nFFT / 2 + 1` weights; `nFFT` must be a power of two.
    static func calculate(_ signal: [Double], nMFCC: Int, nFFT: Int, nMels: Int, hopLength: Int,
                          melFilter: [[Double]]) throws -> [Double] {
        guard nFFT > 0, nFFT & (nFFT - 1) == 0 else {
            throw Failure.nonPowerOfTwoFFT
        }

        guard melFilter.count == nMels, melFilter.allSatisfy({ $0.count == nFFT / 2 + 1 }) else {
            throw Failure.filterbankMismatch
        }

        // jlibrosa receives float[] samples (FlutterSoundProcessingPlugin.java toFloatArray).
        let padded = try reflectPad(signal.map { Double(Float($0)) }, nFFT: nFFT)
        let frames = 1 + (padded.count - nFFT) / hopLength // :613

        guard frames >= 1 else {
            throw Failure.empty
        }

        var melDb = melPower(padded, frames: frames, nFFT: nFFT, hopLength: hopLength, melFilter: melFilter)
        powerToDb(&melDb)
        let result = dct(melDb, frames: frames, nMFCC: nMFCC, nMels: nMels)

        guard !result.isEmpty else {
            throw Failure.empty
        }

        guard result.allSatisfy(\.isFinite) else {
            throw Failure.nonFinite
        }

        return result
    }

    // :505-512 — reflect padding of nFFT/2 samples on each side, edge sample excluded; Java throws
    // ArrayIndexOutOfBoundsException below nFFT/2 + 1 samples.
    private static func reflectPad(_ y: [Double], nFFT: Int) throws -> [Double] {
        let half = nFFT / 2

        guard y.count >= half + 1 else {
            throw Failure.tooShort(nFFT: nFFT)
        }

        var padded = [Double](repeating: 0, count: nFFT + y.count)

        for i in 0..<half {
            padded[half - i - 1] = y[i + 1]
            padded[half + y.count + i] = y[y.count - 2 - i]
        }

        for j in 0..<y.count {
            padded[half + j] = y[j]
        }

        return padded
    }

    // :594-603 — periodic Hann window.
    private static func hannWindow(nFFT: Int) -> [Double] {
        (0..<nFFT).map { i in 0.5 - 0.5 * cos(2.0 * Double.pi * Double(i) / Double(nFFT)) }
    }

    // :538-587 (power spectrum re² + im² of bins 0…nFFT/2, :571, :582), then :168-180 (mel product, ascending k);
    // one frame at a time. Layout mel[band * frames + frame].
    private static func melPower(_ padded: [Double], frames: Int, nFFT: Int, hopLength: Int,
                                 melFilter: [[Double]]) -> [Double] {
        let window = hannWindow(nFFT: nFFT)
        let fft = FFT(count: nFFT)
        let bins = nFFT / 2 + 1
        var mel = [Double](repeating: 0, count: melFilter.count * frames)
        var re = [Double](repeating: 0, count: nFFT)
        var im = [Double](repeating: 0, count: nFFT)
        var power = [Double](repeating: 0, count: bins)

        for t in 0..<frames {
            let start = t * hopLength

            for l in 0..<nFFT {
                re[l] = window[l] * padded[start + l] // :552, :619
                im[l] = 0
            }

            fft.forward(re: &re, im: &im)

            for k in 0..<bins {
                power[k] = re[k] * re[k] + im[k] * im[k]
            }

            for (band, weights) in melFilter.enumerated() {
                var sum = 0.0

                for k in 0..<bins {
                    sum += weights[k] * power[k]
                }

                mel[band * frames + t] = sum
            }
        }

        return mel
    }

    // :631-661 — 10·log10 (as ln/ln 10, :866-868), −100 dB at or below 1e-10, then top_db 80 against the
    // maximum of the whole matrix (initialised to −100); no ref scaling. NaN maps to −100 as in Java.
    private static func powerToDb(_ values: inout [Double]) {
        var maxValue = -100.0

        for i in values.indices {
            let magnitude = abs(values[i])
            values[i] = magnitude > 1e-10 ? 10.0 * (log(magnitude) / log(10.0)) : -100.0

            if values[i] > maxValue {
                maxValue = values[i]
            }
        }

        for i in values.indices where values[i] < maxValue - 80.0 {
            values[i] = maxValue - 80.0
        }
    }

    // :670-686 — orthonormal DCT-II basis, rows 0..<nMFCC (not capped at nMels); :148-160 — product over ascending
    // mel bands; :135 — float cast of each value. Output layout data[coef + nMFCC * frame].
    private static func dct(_ melDb: [Double], frames: Int, nMFCC: Int, nMels: Int) -> [Double] {
        let samples = (0..<nMels).map { j in Double(1 + 2 * j) * Double.pi / (2.0 * Double(nMels)) }
        var basisRow = [Double](repeating: 0, count: nMels)
        var output = [Double](repeating: 0, count: nMFCC * frames)

        for i in 0..<nMFCC {
            for j in 0..<nMels {
                basisRow[j] = i == 0
                    ? 1.0 / sqrt(Double(nMels))
                    : cos(Double(i) * samples[j]) * sqrt(2.0 / Double(nMels))
            }

            for t in 0..<frames {
                var sum = 0.0

                for k in 0..<nMels {
                    sum += basisRow[k] * melDb[k * frames + t]
                }

                output[i + nMFCC * t] = Double(Float(sum))
            }
        }

        return output
    }

    /// Iterative radix-2 FFT: unnormalised forward transform X[k] = Σ x[t]·e^(−2πi·kt/n), the semantics of
    /// commons-math3 `FastFourierTransformer(DftNormalization.STANDARD)` with `TransformType.FORWARD` (:559-564).
    struct FFT {
        private let count: Int
        private let cosTable: [Double]
        private let sinTable: [Double]

        /// `count` must be a power of two.
        init(count: Int) {
            self.count = count
            cosTable = (0..<count / 2).map { k in cos(2.0 * Double.pi * Double(k) / Double(count)) }
            sinTable = (0..<count / 2).map { k in -sin(2.0 * Double.pi * Double(k) / Double(count)) }
        }

        /// Transforms in place; `re` and `im` both hold `count` values.
        func forward(re: inout [Double], im: inout [Double]) {
            guard count > 1 else {
                return
            }

            var j = 0

            for i in 1..<count {
                var bit = count >> 1

                while j & bit != 0 {
                    j ^= bit
                    bit >>= 1
                }

                j |= bit

                if i < j {
                    re.swapAt(i, j)
                    im.swapAt(i, j)
                }
            }

            var length = 2

            while length <= count {
                let half = length / 2
                let tableStep = count / length

                for k in 0..<half {
                    let wr = cosTable[k * tableStep]
                    let wi = sinTable[k * tableStep]
                    var a = k

                    while a < count {
                        let b = a + half
                        let tr = re[b] * wr - im[b] * wi
                        let ti = re[b] * wi + im[b] * wr
                        re[b] = re[a] - tr
                        im[b] = im[a] - ti
                        re[a] += tr
                        im[a] += ti
                        a += length
                    }
                }

                length <<= 1
            }
        }
    }
}
