import AVFoundation
import Flutter
import UIKit
import RosaKit

public class SwiftFlutterSoundProcessingPlugin: NSObject, FlutterPlugin {
    // Method names, error codes, messages and argument keys mirror
    // android/src/main/java/kg/cos9/flutter_sound_processing/FlutterSoundProcessingPlugin.java
    // (with AudioFileDecoder.java, Resampler.java) and lib/flutter_sound_processing_method_channel.dart —
    // change all three together.
    private static let calculateMFCCsMethod = "calculateMFCCs"
    private static let calculateMFCCsFromFileMethod = "calculateMFCCsFromFile"

    private static let invalidArguments = "INVALID_ARGUMENTS"
    private static let calculationFailed = "CALCULATION_FAILED"
    private static let fileNotFound = "FILE_NOT_FOUND"
    private static let unsupportedFormat = "UNSUPPORTED_FORMAT"
    private static let decodeFailed = "DECODE_FAILED"
    private static let fileTooLong = "FILE_TOO_LONG"

    private static let positiveIntKeys = ["sample_rate", "mfcc", "n_fft", "n_mels", "hop_length"]
    private static let maxDurationSeconds = 600

    // Serial queue: decodes and MFCC work run off the main thread, one call at a time (bounds peak memory).
    private let queue = DispatchQueue(label: "kg.cos9.flutter_sound_processing", qos: .userInitiated)

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_sound_processing", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterSoundProcessingPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == Self.calculateMFCCsMethod || call.method == Self.calculateMFCCsFromFileMethod else {
            result(FlutterMethodNotImplemented)
            return
        }

        guard let arguments = call.arguments as? [String: Any] else {
            result(FlutterError(code: Self.invalidArguments, message: "arguments: expected a map", details: nil))
            return
        }

        let fromFile = call.method == Self.calculateMFCCsFromFileMethod
        let invalidInput = fromFile ? Self.invalidPath(arguments["path"]) : Self.invalidValues(arguments["values"])

        if let invalid = invalidInput ?? Self.invalidInts(arguments) {
            result(FlutterError(code: Self.invalidArguments, message: invalid, details: nil))
            return
        }

        let sampleRate = arguments["sample_rate"] as! Int
        let mfcc = arguments["mfcc"] as! Int
        let nFFT = arguments["n_fft"] as! Int
        let nMels = arguments["n_mels"] as! Int
        let hopLength = arguments["hop_length"] as! Int

        if fromFile {
            let url = Self.fileURL(arguments["path"] as! String)!
            runInBackground(result) {
                let signal = try Self.decodeAndResample(url, sampleRate: sampleRate)
                return try Self.calculate(signal, sampleRate: sampleRate, mfcc: mfcc, nFFT: nFFT, nMels: nMels,
                                          hopLength: hopLength)
            }
        } else {
            let values = Self.doubles(arguments["values"] as! FlutterStandardTypedData)
            runInBackground(result) {
                try Self.calculate(values, sampleRate: sampleRate, mfcc: mfcc, nFFT: nFFT, nMels: nMels,
                                   hopLength: hopLength)
            }
        }
    }

    /// Runs `task` on the serial queue; every `result` call happens on the main thread.
    private func runInBackground(_ result: @escaping FlutterResult, _ task: @escaping () throws -> [Double]) {
        queue.async {
            let reply: Any

            do {
                let data = try task()
                reply = FlutterStandardTypedData(float64: data.withUnsafeBytes { Data($0) })
            } catch let error as PluginError {
                reply = FlutterError(code: error.code, message: error.message, details: error.details)
            } catch {
                reply = FlutterError(code: Self.calculationFailed, message: "\(error)", details: nil)
            }

            DispatchQueue.main.async { result(reply) }
        }
    }

    private static func decodeAndResample(_ url: URL, sampleRate: Int) throws -> [Double] {
        let decoded: (mono: [Double], sampleRate: Int)

        do {
            decoded = try AudioFileDecoder.decode(url: url, maxDurationSeconds: maxDurationSeconds)
        } catch let error as AudioFileDecoder.DecodeError {
            throw PluginError(code: errorCode(error), message: "path: \(error.reason)", details: error.detail)
        }

        return Resampler.resample(decoded.mono, inRate: decoded.sampleRate, outRate: sampleRate)
    }

    private static func errorCode(_ error: AudioFileDecoder.DecodeError) -> String {
        switch error {
        case .fileNotFound: return fileNotFound
        case .tooLong: return fileTooLong
        case .unsupported: return unsupportedFormat
        case .decodeFailed: return decodeFailed
        }
    }

    private static func calculate(_ signal: [Double], sampleRate: Int, mfcc: Int, nFFT: Int, nMels: Int,
                                  hopLength: Int) throws -> [Double] {
        let mfccValues = signal.mfcc(
            nMFCC: mfcc,
            nFFT: nFFT,
            hopLength: hopLength,
            sampleRate: sampleRate,
            melsCount: nMels
        )

        guard let firstRow = mfccValues.first, !firstRow.isEmpty else {
            throw PluginError(code: calculationFailed, message: "empty result", details: nil)
        }

        return flatten(mfccValues)
    }

    /// Returns why `values` is invalid, or nil if it is valid.
    private static func invalidValues(_ values: Any?) -> String? {
        guard let typed = values as? FlutterStandardTypedData, typed.type == .float64, typed.elementCount > 0 else {
            return "values: expected a non-empty Float64List"
        }

        return nil
    }

    /// Returns why `path` is invalid, or nil if it is valid.
    private static func invalidPath(_ path: Any?) -> String? {
        guard let path = path as? String, !path.isEmpty else {
            return "path: expected a non-empty string"
        }

        if path.hasPrefix("content://") {
            return "path: content:// URIs are not supported, copy the file into app storage first"
        }

        guard let url = fileURL(path), !url.path.isEmpty else {
            return "path: invalid file:// URL"
        }

        return nil
    }

    /// Returns why one of the positive integer arguments is invalid, or nil if all are valid.
    private static func invalidInts(_ arguments: [String: Any]) -> String? {
        for key in positiveIntKeys {
            guard let value = arguments[key] as? Int, value > 0 else {
                return "\(key): expected a positive integer"
            }
        }

        return nil
    }

    /// Accepts an absolute path or a file:// URL.
    private static func fileURL(_ path: String) -> URL? {
        guard path.hasPrefix("file://") else {
            return URL(fileURLWithPath: path)
        }

        guard let url = URL(string: path), url.isFileURL else {
            return nil
        }

        return url
    }

    private static func doubles(_ typed: FlutterStandardTypedData) -> [Double] {
        var values = [Double](repeating: 0, count: Int(typed.elementCount))
        // Copies bytes instead of rebinding, so an unaligned Data buffer is safe.
        _ = values.withUnsafeMutableBytes { typed.data.copyBytes(to: $0) }
        return values
    }

    // Flattened column-major (data[row + rows * col]) so Android and iOS return the same layout.
    private static func flatten(_ matrix: [[Double]]) -> [Double] {
        let matrixLength = matrix.count
        let matrixWidth = matrix[0].count

        var framePredDaArray = [Double](repeating: 0, count: matrixWidth * matrixLength)

        for i in 0..<matrixLength {
            for j in 0..<matrixWidth {
                framePredDaArray[i + matrixLength * j] = matrix[i][j]
            }
        }

        return framePredDaArray
    }

    private struct PluginError: Error {
        let code: String
        let message: String
        let details: String?
    }
}
