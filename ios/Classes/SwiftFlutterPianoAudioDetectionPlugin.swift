import Flutter
import UIKit

public class SwiftFlutterPianoAudioDetectionPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    
    private var result : FlutterResult!
    private var events : FlutterEventSink!
    private var registrar : FlutterPluginRegistrar
    
    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftFlutterPianoAudioDetectionPlugin(registrar: registrar)
        
        let channel = FlutterMethodChannel(name: "flutter_piano_audio_detection", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        let eventChannel = FlutterEventChannel(name: "startAudioRecognition", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        self.result = result
        switch call.method {
        case "prepare":
            loadModel(registrar: registrar)
            break
        case "start":
            break
        case "stop":
            break
        default:
            result(FlutterMethodNotImplemented)
        }
      
    }
    
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.events = events
        return nil
    }
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.events = nil
        return nil
    }
    
    private func loadModel(registrar : FlutterPluginRegistrar){
        print("loadModel Event Test")
//        let isAsset =
    }
    
}
