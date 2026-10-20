import Flutter
import UIKit
import RosaKit

public class SwiftFlutterSoundProcessingPlugin: NSObject, FlutterPlugin {
    // Error codes, messages and argument keys mirror
    // android/src/main/java/kg/cos9/flutter_sound_processing/FlutterSoundProcessingPlugin.java
    // and lib/flutter_sound_processing_method_channel.dart — change all three together.
    private static let invalidArguments = "INVALID_ARGUMENTS"
    private static let calculationFailed = "CALCULATION_FAILED"
    private static let positiveIntKeys = ["sample_rate", "mfcc", "n_fft", "n_mels", "hop_length"]

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_sound_processing", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterSoundProcessingPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "getFeatureMatrix" else {
            result(FlutterMethodNotImplemented)
            return
        }

        guard let arguments = call.arguments as? [String: Any] else {
            result(FlutterError(code: Self.invalidArguments, message: "arguments: expected a map", details: nil))
            return
        }

        if let invalidArgument = Self.invalidArgument(arguments) {
            result(FlutterError(code: Self.invalidArguments, message: invalidArgument, details: nil))
            return
        }

        guard let values = arguments["values"] as? [Double],
              let sampleRate = arguments["sample_rate"] as? Int,
              let mfcc = arguments["mfcc"] as? Int,
              let nFFT = arguments["n_fft"] as? Int,
              let nMels = arguments["n_mels"] as? Int,
              let hopLength = arguments["hop_length"] as? Int else {
            result(FlutterError(code: Self.invalidArguments, message: "Invalid arguments", details: nil))
            return
        }

        let mfccValues = values.mfcc(
            nMFCC: mfcc,
            nFFT: nFFT,
            hopLength: hopLength,
            sampleRate: sampleRate,
            melsCount: nMels
        )

        guard let firstRow = mfccValues.first, !firstRow.isEmpty else {
            result(FlutterError(code: Self.calculationFailed, message: "empty result", details: nil))
            return
        }

        let featureMatrix = Self.flatten(mfccValues)

        let float64List =     FlutterStandardTypedData(float64: featureMatrix.withUnsafeBytes { Data($0) })

        result(float64List)
    }

    /// Returns why the arguments are invalid, or nil if they are valid.
    private static func invalidArgument(_ arguments: [String: Any]) -> String? {
        guard let values = arguments["values"] as? [Double], !values.isEmpty else {
            return "values: expected a non-empty list of doubles"
        }

        for key in positiveIntKeys {
            guard let value = arguments[key] as? Int, value > 0 else {
                return "\(key): expected a positive integer"
            }
        }

        return nil
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
}
