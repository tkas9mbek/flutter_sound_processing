import Foundation

/// Windowed-sinc resampler (Hann window, half-width 32 input samples, cutoff at the lower Nyquist).
///
/// Mirrors android/src/main/java/kg/cos9/flutter_sound_processing/Resampler.java term by term (same constants,
/// same ascending summation in double) so Android and iOS produce the same samples. Adequate for MFCCs; not a
/// hi-fi resampler.
enum Resampler {
    private static let halfWidth = 32

    /// Returns `input` unchanged when the rates match.
    static func resample(_ input: [Double], inRate: Int, outRate: Int) -> [Double] {
        if inRate == outRate {
            return input
        }

        let inLength = input.count
        let outLength = Int(Int64(inLength) * Int64(outRate) / Int64(inRate))
        let s = min(1.0, Double(outRate) / Double(inRate))
        let halfWidth = Double(Self.halfWidth)
        var output = [Double](repeating: 0, count: outLength)

        for m in 0..<outLength {
            let p = Double(m) * Double(inRate) / Double(outRate)
            let kStart = Int((p - halfWidth).rounded(.up))
            let kEnd = Int((p + halfWidth).rounded(.down))
            var acc = 0.0
            var norm = 0.0

            for k in kStart...kEnd {
                let w = weight(Double(k) - p, s: s, halfWidth: halfWidth)
                norm += w

                if k >= 0 && k < inLength {
                    acc += input[k] * w
                }
            }

            output[m] = acc / norm
        }

        return output
    }

    // w(t) = s * sinc(s * t) * hann(t / L); sinc(u) = sin(pi u) / (pi u), 1 at 0; hann(v) = 0.5 (1 + cos(pi v)), |v| <= 1.
    private static func weight(_ t: Double, s: Double, halfWidth: Double) -> Double {
        let v = t / halfWidth

        if abs(v) > 1.0 {
            return 0.0
        }

        let u = s * t
        let sinc = u == 0.0 ? 1.0 : sin(Double.pi * u) / (Double.pi * u)

        return s * sinc * 0.5 * (1.0 + cos(Double.pi * v))
    }
}
