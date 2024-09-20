import 'dart:async';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:camera/camera.dart';
import 'package:flutter_action_classifier/camera_page.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CameraPage(),
    );
  }
}

class ActionClassifierScreen extends StatefulWidget {


  const ActionClassifierScreen({super.key});

  @override
  _ActionClassifierScreenState createState() => _ActionClassifierScreenState();
}

class _ActionClassifierScreenState extends State<ActionClassifierScreen> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Action Classifier')),
      body: Center(child: Text('Go Back to Camera')),
    );
  }


  @override
  void dispose() {
    super.dispose();
  }
}
