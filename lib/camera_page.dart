import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter_action_classifier/predictor_channel.dart';

// Method for interacting with Native IOS/Android (Only IOS supported currently)
const MethodChannel _cameraConfigurationChannel =
    MethodChannel('samples.flutter.dev/camera_configuration');

const MethodChannel _channel = MethodChannel('predictor_channel');

Future<void> setCameraConfiguration(int resolution) async {
  try {
    final bool success = await _cameraConfigurationChannel
        .invokeMethod('setCameraConfiguration', {'format': resolution});
    if (success) {
      debugPrint('Resolution is $resolution ');
    } else {
      debugPrint('No Resolution $resolution');
    }
  } on PlatformException catch (e) {
    print('Error: ${e.message}');
  }
}

class CameraPage extends StatefulWidget {
  const CameraPage({Key? key}) : super(key: key);

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  bool _isLoading = true;
  late CameraController _cameraController;
  bool _isPaused = false;
  int clipnum = 0;
  bool recording = false;
  late Timer _recordTimer = Timer(Duration.zero, () {}); // Initialize with a dummy timer
  late CameraDescription camera;
  bool _showOverlay = false;

  // Tracking recording state
  String _recordingStep = '';

  @override
  void dispose() {
    _cameraController.dispose();
    _recordTimer.cancel(); // Cancel the timer when disposing
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  /*// Start recording loop until stopped by the user
  Future<void> startRecordingLoop() async {
    recording = true;
    while (recording) {
      await startRecording(1); // Record a 1-second video
      bool predictionResult = await analyzeClip();
      if (predictionResult) {
        // If prediction is positive, record a 4-second video and show overlay
        await startRecording(4);
        showOverlay();
        await Future.delayed(
            const Duration(seconds: 60)); // Show overlay for 2 seconds
        hideOverlay();
      }
    }
  }*/

  // Start recording for specified seconds
  Future<void> startRecording(int durationInSeconds) async {
    setState(() {
      _recordingStep = 'Starting recording...'; // Set overlay message
    });


    if (!_cameraController.value.isInitialized) {
      return;
    }

    await setCameraConfiguration(720); // Set configuration to 720p

    try {
      if (!_cameraController.value.isRecordingVideo) {
        await _cameraController.startVideoRecording();

        setState(() {
          _recordingStep = 'Recording...'; // Update overlay message
        });

        //await Future.delayed(Duration(seconds: durationInSeconds));
        //await stopRecording(noStart: true);
        // Record and stop after n seconds
        _recordTimer =
            Timer.periodic(Duration(seconds: durationInSeconds), (_) {
              stopRecording(noStart: true);
            });
      }
    } catch (e) {
      print('Error recording video: $e');
      setState(() {
        _recordingStep = 'Error during recording'; // Show error
      });
    }
  }

  // Stop recording and return the video path
  Future<void> stopRecording({bool noStart = false}) async {
    setState(() {
      _recordingStep = 'Stopping recording...'; // Set overlay message
    });
    if (_cameraController.value.isRecordingVideo) {
      try {
        final XFile video = await _cameraController.stopVideoRecording();
        // Save the file path from XFile
        String videoPath = video.path;
        print("Video saved to path: $videoPath");

        clipnum += 1;
        print("Clip Num: $clipnum");

        try {
          bool predictionResult = await analyzeClip(videoPath);
          // Delete the temp file
          try {
            final file = File(videoPath);
            await file.delete();
            print('File deleted successfully!');
          } catch (ef) {
            // Handle the exception
            print('Error deleting file: $ef');
          }
          if (predictionResult) {
            // Show overlay when the action is detected
            setState(() {
              _recordingStep =
              'Action detected! Recording additional 200 seconds...';
            });
            // If prediction is positive, record a 4-second video and show overlay
            await startRecording(4);
          }
          if (!noStart && !_isPaused) {
            startRecording(1);
          }
        } catch (ea) {
          print('Failed to predict action [stopRecording()]: $ea');
          setState(() {
            _recordingStep = 'Prediction failed, resuming...';
          });
          if (!noStart && !_isPaused) {
            startRecording(1);
          }
        }
      } catch (es) {
        print('Failed to stop recording [stopRecording()]: $es');
      }
    }
    setState(() {
      _recordingStep = 'Recording stopped'; // Set final overlay message
    });

    /// Infinite Loop Disk Space Issue Recursive
    /// Remove comment at your own risk for debugging
    startRecording(1);
  }

  // Analyze the recorded video clip using makePrediction
  Future<bool> analyzeClip(String videoPath) async {

    try {
      // final result = await _channel
      //     .invokeMethod('makePrediction', {'videoPath': videoPath});
      print('Configuring Processor...');
      setState(() {
        _recordingStep = 'Configuring Processor...';
      });
      await PredictorChannel.configureProcessor(videoPath);

      print('Processor Configured Checking isReadyToMakePrediction...');
      setState(() {
        _recordingStep = 'Processor Configured Checking isReadyToMakePrediction...';
      });
      bool isReady = await PredictorChannel.isReadyToMakePrediction();

      print('isReadyToMakePrediction: ' + isReady.toString());
      setState(() {
        _recordingStep = 'isReadyToMakePrediction: ' + isReady.toString();
      });
      if(isReady) {
        print('Making Prediction...');
        setState(() {
          _recordingStep = 'Making Prediction...';
        });
        final Map<String, dynamic>? predictionResult = await PredictorChannel.makePrediction();

       if (predictionResult != null) {
         String label = predictionResult['label'] as String;
         double confidence = predictionResult['confidence'] as double;

         print('Prediction Label: $label');
         print('Prediction Confidence: $confidence');

         if (label == "positive" && confidence > 0.8) {
           // Do something if the prediction meets criteria
           print("Positive result detected.");
           // Show overlay when the action is detected
           setState(() {
             _recordingStep = 'Action detected! Recording additional 200 seconds...';
           });

           return true; // Assume positive prediction returns true
         } else {
           // Continue recording if the result doesn't meet criteria
           print("Negative result, continuing recording...");
           setState(() {
             _recordingStep = 'Prediction failed, resuming...';
           });
           return false;
         }
         return false;
       } else {
         print('Prediction failed or returned null.');
         setState(() {
           _recordingStep = 'Prediction failed, resuming...';
         });
         return false;
       }
      }
      return false;
    } catch (e) {
      print('Failed to predict action [AnalyzeClip()]: $e');
      setState(() {
        _recordingStep = 'Prediction failed, resuming...';
      });
      return false;
    }
  }

  void togglePauseRecording() {
    setState(() {
      if (_isPaused) {
        _recordingStep = 'Resuming recording...';
        startRecording(1);
      } else {
        _recordingStep = 'Pausing recording...';
        _recordTimer.cancel();
        stopRecording(noStart: true);
      }
      _isPaused = !_isPaused;
    });
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.white,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    } else {
      return Center(
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            CameraPreview(_cameraController),

            // Overlay for recording steps
            Visibility(
              visible: _recordingStep.isNotEmpty,
              child: Positioned(
                top: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.black.withOpacity(0.7),
                  child: Text(
                    _recordingStep,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ),

            // Start button
            Visibility(
              visible: _isPaused,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: Container(
                  width: 140,
                  height: 40,
                  child: FloatingActionButton(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    backgroundColor: const Color(0xffFF4D3C),
                    child: const Text('Start Session', style: TextStyle(fontSize: 16)),
                    onPressed: () {
                      startRecording(1);
                    },
                  ),
                ),
              ),
            ),

            // Pause/Resume and Stop buttons
            Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: Visibility(
                visible: !_isPaused,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pause/Resume button
                    Container(
                      width: 140,
                      height: 40,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: const LinearGradient(colors: [
                            Color(0xffFFAC5F),
                            Color(0xffFF794C),
                            Color(0xffFF4D3C)
                          ])),
                      child: IconButton(
                        onPressed: togglePauseRecording,
                        icon: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_isPaused ? 'Resume' : 'Pause', style: const TextStyle(fontSize: 19)),
                            const SizedBox(width: 6),
                            Container(
                              height: 25,
                              width: 25,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.black, width: 2)),
                              child: Icon(
                                _isPaused ? Icons.play_arrow : Icons.pause,
                                color: Colors.black,
                                size: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 17),

                    // Stop button
                    Container(
                      width: 140,
                      height: 40,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: const LinearGradient(colors: [
                            Color(0xffFFAC5F),
                            Color(0xffFF794C),
                            Color(0xffFF4D3C)
                          ])),
                      child: IconButton(
                        onPressed: () {
                          stopRecording(noStart: true);
                        },
                        icon: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Stop', style: TextStyle(fontSize: 19)),
                            const SizedBox(width: 6),
                            Container(
                              height: 25,
                              width: 25,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.black, width: 2)),
                              child: const Icon(
                                Icons.stop,
                                color: Colors.black,
                                size: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  // Initialize camera
  _initCamera() async {
    final cameras = await availableCameras();
    final back = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back);
    _cameraController = CameraController(back, ResolutionPreset.high);
    await _cameraController.initialize();
    _cameraController.setZoomLevel(1.4);
    setState(() => _isLoading = false);
  }
}
