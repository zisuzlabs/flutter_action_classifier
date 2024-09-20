import 'package:flutter/services.dart';

class PredictorChannel {
  static const MethodChannel _channel = MethodChannel('predictor_channel');

  // Method to configure the processor with the video file path
  static Future<void> configureProcessor(String videoPath) async {
    try {
      await _channel.invokeMethod('configureProcessor', {"videoPath": videoPath});
    } on PlatformException catch (e) {
      print("Failed to configure processor: '${e.message}'.");
    }
  }

  // Call isReadyToMakePrediction
  static Future<bool> isReadyToMakePrediction() async {
    try {
      final bool isReady = await _channel.invokeMethod('isReadyToMakePrediction');
      return isReady;
    } on PlatformException catch (e) {
      print("Failed to check readiness: '${e.message}'.");
      return false;
    }
  }

  // Call makePrediction
  static Future<Map<String, dynamic>?> makePrediction() async {
    try {
      final Map<dynamic, dynamic>? result =
      await _channel.invokeMethod<Map<dynamic, dynamic>>('makePrediction');

      // Safely cast the result to Map<String, dynamic>
      if (result != null) {
        final Map<String, dynamic> predictionResult =
        Map<String, dynamic>.from(result); // Cast to the correct type
        return predictionResult;
      }
      return null;
    } on PlatformException catch (e) {
      print("Failed to make prediction [makePrediction()]: '${e.message}'.");
      return null;
    }
  }
}