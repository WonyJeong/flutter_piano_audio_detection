import Flutter
import UIKit
import TensorFlowLite
import AVFoundation

extension SwiftFlutterPianoAudioDetectionPlugin: AudioInputManagerDelegate {
    func didOutput(channelData: [Int16]) {
        guard let handler = modelDataHandler else {
            return
        }
        bufferSize = (handler.sampleRate * handler.sequenceLength) / 1000

        self.runModel(onBuffer: Array(channelData[0..<bufferSize]))
    }
}

public class SwiftFlutterPianoAudioDetectionPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    // MARK : Flutter Plugin Variables
    private var flutterResult : FlutterResult!
    private var result : [Dictionary<String, Any>]?
    private var arguments : [String : AnyObject]!
    private var events : FlutterEventSink!
    private var registrar : FlutterPluginRegistrar
    

    // MARK: Objects Handling Core Functionality
    private var modelDataHandler: ModelDataHandler? =
        ModelDataHandler(modelFileInfo: ConvActions.modelInfo)
    private var audioInputManager: AudioInputManager?

    // MARK: Instance Variables
    private var prevKeys: [Int] = Array(repeating: 0, count: 88)
    private var bufferSize: Int = 0
    private var threshold: Int = 20

    /// TensorFlow Lite `Interpreter` object for performing inference on a given model.
    private var interpreter: Interpreter!

    //AvAudioEngine used for recording
    private var audioEngine: AVAudioEngine = AVAudioEngine()

    //Microphone variables
    private let conversionQueue = DispatchQueue(label: "conversionQueue")
    private let maxInt16AsFloat32: Float32 = 32767.0

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
        self.arguments = call.arguments as? [String: AnyObject]
        self.flutterResult = result
        switch call.method {
        case "prepare":
            prepare()
            break
        case "start":
            start()
            break
        case "stop":
            stop()
            break
        default:
            self.flutterResult(FlutterMethodNotImplemented)
        }
    }
    
    public func prepare(){
        guard let handler = modelDataHandler else {
            return
        }
        if(audioInputManager != nil) {
            return
        }
        audioInputManager = AudioInputManager(sampleRate: handler.sampleRate, sequenceLength: handler.sequenceLength)
        audioInputManager?.delegate = self
        
        guard let workingAudioInputManager = audioInputManager else {
            return
        }
        workingAudioInputManager.prepareMicrophone()
        self.flutterResult(true)
    }
    
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.events = events
        self.arguments = arguments as? [String: AnyObject]
        return nil
    }
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.events = nil
        return nil
    }
    
    private func start(){
        prevKeys = Array(repeating: 0, count: 88)
        guard let workingAudioInputManager = audioInputManager else { return }
        print("Audio Manager Loaded")
        self.bufferSize = workingAudioInputManager.bufferSize
        workingAudioInputManager.startTappingMicrophone()
    }
    
    private func stop(){
        guard let workingAudioInputManager = audioInputManager else { return }
        workingAudioInputManager.stopTappingMicrophone()
    }
    
    private func runModel(onBuffer buffer: [Int16]) {
        self.result = modelDataHandler?.runModel(onBuffer: buffer)
        guard let flutterResultList = result else { return }
        if (!flutterResultList.isEmpty){
            events(flutterResultList)
        }
    }
}
