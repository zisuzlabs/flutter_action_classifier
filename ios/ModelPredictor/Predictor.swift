//
//  Predictor.swift
//  BowlerDetection
//
//  Created by Zisuz Labs LLC on 9/17/24.
//

import Foundation
import CoreML
import Vision

@available(iOS 14.0, *)
class Predictor {
    /// Trial Action classifier model.
    let trialActionClassifier = try? TrialActionClassifier_1()

    /// Vision body pose request.
    let humanBodyPoseRequest = VNDetectHumanBodyPoseRequest()

    /// Getting poses from a video.
    var processor: VNVideoProcessor?
    var poses: [VNRecognizedPointsObservation?] = []
    var predictionWindowSize = 60
    var startTime = CMTime.zero
    var endTime = CMTime.indefinite

    init() {
        // Reserve capacity for the poses array
        poses.reserveCapacity(predictionWindowSize)
    }

    /// Configure the video processor with the request.
    func configureProcessor(videoPath: String) {
        print("Configuring processor with video at path: \(videoPath)")
        let videoURL = URL(fileURLWithPath: videoPath)
       
        // Initialize the VNVideoProcessor with the videoURL
        processor = try? VNVideoProcessor(url: videoURL)
        
        // Ensure the processor is available before configuring
        guard let processor = processor else {
            print("Processor not initialized.")
            return
        }

        // Create and add the body pose request to the processor
        let request = VNDetectHumanBodyPoseRequest { request, error in
            if let error = error {
                print("Error in body pose request: \(error)")
                return
            }

            // Get the recognized poses
            if let results = request.results as? [VNRecognizedPointsObservation] {
                self.poses.append(contentsOf: results)
            }
        }

        do {
            // Replace deprecated `add(_:withProcessingOptions:)` with `addRequest(_:processingOptions:)`
            let processingOptions = VNVideoProcessor.RequestProcessingOptions() // Configure if necessary
            try processor.addRequest(request, processingOptions: processingOptions)
            try processor.analyze(with: CMTimeRange(start: startTime, end: endTime))
        } catch {
            print("Error configuring VNVideoProcessor: \(error)")
        }
    }

    /// Check if the system is ready to make a prediction.
    var isReadyToMakePrediction: Bool {
        //poses.count == predictionWindowSize
        return poses.count > 0
    }

    /// Make a model prediction when the window is full.
    func makePrediction() throws -> PredictionOutput {
        // Ensure that we only have exactly 60 poses (trim if necessary)
        if poses.count > predictionWindowSize {
            poses = Array(poses.suffix(predictionWindowSize))
        } else if poses.count < predictionWindowSize {
            // Pad with empty poses if fewer than expected
            poses += Array(repeating: nil, count: predictionWindowSize - poses.count)
        }
    
        // Prepare model input: convert each pose to a multi-array, and concatenate multi-arrays.
        let poseMultiArrays: [MLMultiArray] = try poses.map { person in
            guard let person = person else {
                // Pad 0s when no person detected.
                return zeroPaddedMultiArray()
            }
            return try person.keypointsMultiArray()
        }

        // Concatenate the multi-arrays for model input
        let modelInput = MLMultiArray(concatenating: poseMultiArrays, axis: 0, dataType: .float)

        // Perform prediction
        guard let fitnessClassifier = trialActionClassifier else {
            throw NSError(domain: "PredictorError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Model not available"])
        }

        let predictions = try fitnessClassifier.prediction(poses: modelInput)

        // Reset poses window by removing the first poses
        poses.removeFirst(predictionWindowSize / 2)

        // Return prediction output
        return PredictionOutput(
            label: predictions.label,
            confidence: predictions.labelProbabilities[predictions.label] ?? 0
        )
    }
}

/// Zero-padded multi-array function (assuming you have this function defined somewhere in your code).
@available(iOS 14.0, *)
func zeroPaddedMultiArray() -> MLMultiArray {
    // Implementation of zero padding for the multi-array (depending on your input size and dimensions)
    // Example:
    return try! MLMultiArray(shape: [1, 3, 18], dataType: .float) // Adjust shape according to your needs
}

/// Struct to handle Prediction Output
struct PredictionOutput {
    let label: String
    let confidence: Double
}
