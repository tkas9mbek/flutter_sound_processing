import Flutter
import UIKit
import AudioKit

public class SwiftFlutterSoundProcessingPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_sound_processing", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterSoundProcessingPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    result("iOS " + UIDevice.current.systemVersion)
  }
}
