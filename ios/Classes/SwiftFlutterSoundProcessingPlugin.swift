import Flutter
import UIKit
import RosaKit

public class SwiftFlutterSoundProcessingPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_sound_processing", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterSoundProcessingPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "getFeatureMatrix" {
            guard let arguments = call.arguments as? [String: Any],
                  let values = arguments["values"] as? [Double],
                  let sampleRate = arguments["sample_rate"] as? Int,
                  let mfcc = arguments["mfcc"] as? Int,
                  let nFFT = arguments["n_fft"] as? Int,
                  let nMels = arguments["n_mels"] as? Int,
                  let hopLength = arguments["hop_length"] as? Int else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
                return
            }
            
            let featureMatrix = calculateFeatureMatrix(values: values, sampleRate: sampleRate, mfcc: mfcc, nFFT: nFFT, nMels: nMels, hopLength: hopLength)
            
            let float64List =     FlutterStandardTypedData(float64: featureMatrix.withUnsafeBytes { Data($0) })

            result(float64List)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func calculateFeatureMatrix(values: [Double], sampleRate: Int, mfcc: Int, nFFT: Int, nMels: Int, hopLength: Int) -> [Double] {
        let mfccValues = values.mfcc(
            nMFCC: mfcc,
            nFFT: nFFT,
            hopLength: hopLength,
            sampleRate: sampleRate,
            melsCount: nMels
        )
        
        let matrixLength = mfccValues.count
        let matrixWidth = mfccValues[0].count
        
        var framePredDaArray = [Double](repeating: 0, count: matrixWidth * matrixLength)
        
        for i in 0..<matrixLength {
            for j in 0..<matrixWidth {
                framePredDaArray[i + matrixLength * j] = mfccValues[i][j]
            }
        }
        
        return framePredDaArray
    }
}
