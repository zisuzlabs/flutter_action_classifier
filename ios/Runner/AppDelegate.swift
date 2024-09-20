import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    @objc func setCameraFps(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let device = AVCaptureDevice.default(for: .video) {
            do {
                try device.lockForConfiguration()
                if let arguments = call.arguments as? [String: Any],
                   let format = arguments["format"] as? Int
                {
                    switch format {
                    case 720:
                        device.activeFormat = device.formats[18]
                        device.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: 60)
                        device.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: 60)
                        print(device.activeFormat.videoSupportedFrameRateRanges.first!.maxFrameRate)
                    case 1080:
                        device.activeFormat = device.formats[30]
                        device.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: 60)
                        device.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: 60)
                        print(device.activeFormat.videoSupportedFrameRateRanges.first!.maxFrameRate)
                    case 2160:
                        device.activeFormat = device.formats[55]
                        device.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: 60)
                        device.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: 60)
                        print(device.activeFormat.videoSupportedFrameRateRanges.first!.maxFrameRate)
                    case 1080120:
                        device.activeFormat = device.formats[36]
                        device.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: 120)
                        device.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: 120)
                        print(device.activeFormat.videoSupportedFrameRateRanges.first!.maxFrameRate)
                    default:
                        break
                    }
                    let movieOutput = AVCaptureMovieFileOutput()
                    let connection = movieOutput.connection(with: AVMediaType.video)
                    if (connection?.isVideoOrientationSupported) ?? false {
                        connection?.videoOrientation = .portrait
                    }
                    if (connection?.isVideoStabilizationSupported) ?? false {
                        connection?.preferredVideoStabilizationMode = AVCaptureVideoStabilizationMode.standard
                    }

                    device.unlockForConfiguration()
                    result(true) // Return success
                }
            } catch {
                result(false) // Return failure
            }
        } else {
            result(false) // Return failure
        }
    }

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
        let cameraFpsChannel = FlutterMethodChannel(name: "samples.flutter.dev/camera_configuration",
                                                    binaryMessenger: controller.binaryMessenger)
        cameraFpsChannel.setMethodCallHandler(setCameraFps(_:result:))

        let predictorChannel = FlutterMethodChannel(name: "predictor_channel", binaryMessenger: controller.binaryMessenger)
        let predictor = Predictor() // Create an instance of the Predictor class

        predictorChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "configureProcessor":
                if let args = call.arguments as? [String: Any],
                   let videoPath = args["videoPath"] as? String
                {
                    predictor.configureProcessor(videoPath: videoPath)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing video path", details: nil))
                }

            case "isReadyToMakePrediction":
                let isReady = predictor.isReadyToMakePrediction
                result(isReady)

            case "makePrediction":
                do {
                    let prediction = try predictor.makePrediction()
//                    result([
//                        "label": prediction.label,
//                        "confidence": prediction.confidence
//                    ])
                    let resultData: [String: Any] = [
                        "label": prediction.label,
                        "confidence": prediction.confidence
                    ]
                    result(resultData) // Return a properly typed dictionary
                } catch {
                    result(FlutterError(code: "PREDICTION_ERROR", message: "Error making prediction", details: nil))
                }

            default:
                result(FlutterMethodNotImplemented)
            }
        }
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
