//
//  AudioInputManager.swift
//  flutter_piano_audio_detection
//
//  Created by 정원영 on 2021/07/06.
//

import Foundation
import UIKit
import AVFoundation

protocol AudioInputManagerDelegate {
    func didOutput(channelData: [Int16])
}

class AudioInputManager: NSObject {

    // MARK: Constants
    let bufferSize: Int
    private let sampleRate: Int
    private let sequenceLength: Int

    var delegate: AudioInputManagerDelegate?

    // MARK: AVAudioEngine
    private var audioEngine: AVAudioEngine = AVAudioEngine()

    // MARK: Instance Variables
    private let conversionQueue = DispatchQueue(label: "conversionQueue")

    private var isRunning = false

    /**
    The initializer initializes the AudioInputManager with the required sample rate for the audio
    output.
    */
    init(sampleRate: Int, sequenceLength: Int) {
        self.sampleRate = sampleRate
        self.sequenceLength = sequenceLength

    // We are setting the buffer size to two times the Sample rate
        bufferSize = (self.sampleRate * self.sequenceLength) / 1000
        super.init()
    }

    func prepareMicrophone() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
          try audioSession.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetoothA2DP, .mixWithOthers])
          try audioSession.setMode(.default)
          try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
          debugPrint("Enable to start audio engine")
          return
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let recordingFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: Double(sampleRate), channels: 1, interleaved: true)
        guard let formatConverter =  AVAudioConverter(from:inputFormat, to: recordingFormat!) else {
            return
        }
    
        print("Preparing")
        // We install a tap on the audio engine and specifying the buffer size and the input format.
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(bufferSize), format: inputFormat) { (buffer, time) in

            self.conversionQueue.async {
            
                // An AVAudioConverter is used to convert the microphone input to the format required for the model.(pcm 16)
                let pcmBuffer = AVAudioPCMBuffer(pcmFormat: recordingFormat!, frameCapacity: AVAudioFrameCount(self.bufferSize))
                var error: NSError? = nil

                let inputBlock: AVAudioConverterInputBlock = {inNumPackets, outStatus in
                    outStatus.pointee = AVAudioConverterInputStatus.haveData
                    return buffer
                }

                formatConverter.convert(to: pcmBuffer!, error: &error, withInputFrom: inputBlock)

                if error != nil {
                    print(error!.localizedDescription)
                }
                else if let channelData = pcmBuffer!.int16ChannelData {

                    let channelDataValue = channelData.pointee
                    let channelDataValueArray = stride(from: 0,
                                                    to: Int(pcmBuffer!.frameLength),
                                                    by: buffer.stride).map{ channelDataValue[$0] }

                    // Converted pcm 16 values are delegated to the controller.
                    self.delegate?.didOutput(channelData: channelDataValueArray)
                }

            }
        }
    }
    /** This method starts tapping the microphone input and converts it into the format for which the model is trained and periodically returns it in the block
    */
    func startTappingMicrophone() {
        if(audioEngine.isRunning || isRunning) {
            print("AudioEngine is Running")
            return;
        }
        audioEngine = AVAudioEngine()
        prepareMicrophone()
        
        audioEngine.prepare()
        print("Audio Engine Prepare")
        do {
            try audioEngine.start()
        }
        catch {
            print(error.localizedDescription)
        }
        print("Audio Engine Start")
        isRunning = true
    }

    func stopTappingMicrophone() {
        audioEngine.stop()
        print("Audio Engine Stop")
        audioEngine.reset()
        print("Audio Engine Reset")
        isRunning = false
    }
}
