//
//  ModelDataHandler.swift
//  flutter_piano_audio_detection
//
//  Created by WonyJeong on 2021/07/06.
//

import Foundation
import TensorFlowLite
import UIKit

/// A result from invoking the `Interpreter`.
struct Result {
    let inferenceTime: Double
}

/// Information about a model file or labels file.
typealias FileInfo = (name: String, extension: String)

/// Information about the ConvActions model.
enum ConvActions {
    static let modelInfo: FileInfo = (name: "onsets_frames_wavinput", extension: "tflite")
}

/// This class handles all data preprocessing and makes calls to run inference on a given audio
/// buffer by invoking the TensorFlow Lite `Interpreter`. It then formats the inferences obtained
/// and averages the recognized commands by running them through RecognizeCommands.
class ModelDataHandler {
    // MARK: - Internal Properties
    /// The current thread count used by the TensorFlow Lite Interpreter.
    let threadCount: Int
    let threadCountLimit = 10
    let sampleRate = 16000
    let sequenceLength = 1120

    // MARK: - Private Properties
    private var buffer:[Int] = []
    private let maxInt16AsFloat32: Float32 = 32767.0

    /// TensorFlow Lite `Interpreter` object for performing inference on a given model.
    private var interpreter: Interpreter

    // MARK: - Initialization
    /// A failable initializer for `ModelDataHandler`. A new instance is created if the model and
    /// labels files are successfully loaded from the app's main bundle. Default `threadCount` is 1.
    init?(modelFileInfo: FileInfo, threadCount: Int = 1) {
        let modelFilename = modelFileInfo.name
        // Construct the path to the model file.
        guard let modelPath = Bundle.main.path(
        forResource: modelFilename,
        ofType: modelFileInfo.extension
        ) else {
        print("Failed to load the model file with name: \(modelFilename).")
            return nil
        }

        // Specify the options for the `Interpreter`.
        self.threadCount = threadCount
        var options = Interpreter.Options()
        options.threadCount = threadCount
        do {
        // Create the `Interpreter`.
        interpreter = try Interpreter(modelPath: modelPath, options: options)
        // Allocate memory for the model's input `Tensor`s.
        try interpreter.allocateTensors()
        } catch let error {
            print("Failed to create the interpreter with error: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Internal Methods
    /// Invokes the `Interpreter` and processes and returns the inference results.
    func runModel(onBuffer buffer: [Int16]) -> [Dictionary<String, Any>]? {
        let interval: TimeInterval
        let outputFrame: Tensor
        let outputOnset: Tensor
        let outputOffset: Tensor
        let outputVelocity: Tensor
        
        do {
            // Copy the `[Int16]` buffer data as an array of `Float`s to the audio buffer input `Tensor`'s.
            let audioBufferData = Data(copyingBufferOf: buffer.map { Float($0) / maxInt16AsFloat32 })
            try interpreter.copy(audioBufferData, toInputAt: 0)

            // Run inference by invoking the `Interpreter`.
            let startDate = Date()
            try interpreter.invoke()
            interval = Date().timeIntervalSince(startDate) * 1000

            // Get the output `Tensor` to process the inference results.
            outputFrame = try interpreter.output(at: 0)
            outputOnset = try interpreter.output(at: 1)
            outputOffset = try interpreter.output(at: 2)
            outputVelocity = try interpreter.output(at: 3)
        } catch let error {
            print("Failed to invoke the interpreter with error: \(error.localizedDescription)")
            return nil
        }
        
        // Array length is 32*88
        let frames : [Float32] = [Float32](unsafeData: outputFrame.data) ?? []
        let onsets : [Float32] = [Float32](unsafeData: outputOnset.data) ?? []
        let offsets : [Float32] = [Float32](unsafeData: outputOffset.data) ?? []
        let velocities : [Float32] = [Float32](unsafeData: outputVelocity.data) ?? []
        
        var result : [Dictionary<String, Any>] = []
        
        for i in 0...31 {
            let offset = i * 88
            for j in 0...87 {
                let idx = offset + j
                if(frames[idx] > 0 || onsets[idx] > 0) {
                    let dic : Dictionary<String, Any> = [
                        "key" : j,
                        "frame" : frames[idx],
                        "onset" : onsets[idx],
                        "offset" : offsets[idx],
                        "velocity" : velocities[idx]
                    ]
                    result.append(dic)
                }
            }
        }
        return result
    }
}

// MARK: - Extensions
extension Data {
    /// Creates a new buffer by copying the buffer pointer of the given array.
    ///
    /// - Warning: The given array's element type `T` must be trivial in that it can be copied bit
    ///     for bit with no indirection or reference-counting operations; otherwise, reinterpreting
    ///     data from the resulting buffer has undefined behavior.
    /// - Parameter array: An array with elements of type `T`.
    init<T>(copyingBufferOf array: [T]) {
        self = array.withUnsafeBufferPointer(Data.init)
    }
}

extension Array {
    /// Creates a new array from the bytes of the given unsafe data.
    ///
    /// - Warning: The array's `Element` type must be trivial in that it can be copied bit for bit
    ///     with no indirection or reference-counting operations; otherwise, copying the raw bytes in
    ///     the `unsafeData`'s buffer to a new array returns an unsafe copy.
    /// - Note: Returns `nil` if `unsafeData.count` is not a multiple of
    ///     `MemoryLayout<Element>.stride`.
    /// - Parameter unsafeData: The data containing the bytes to turn into an array.
    init?(unsafeData: Data) {
        guard unsafeData.count % MemoryLayout<Element>.stride == 0 else { return nil }
        #if swift(>=5.0)
        self = unsafeData.withUnsafeBytes { .init($0.bindMemory(to: Element.self)) }
        #else
        self = unsafeData.withUnsafeBytes {
        .init(UnsafeBufferPointer<Element>(
            start: $0,
            count: unsafeData.count / MemoryLayout<Element>.stride
        ))
        }
        #endif  // swift(>=5.0)
    }
}
