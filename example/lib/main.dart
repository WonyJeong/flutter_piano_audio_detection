import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_piano_audio_detection/flutter_piano_audio_detection.dart';
import 'dart:async';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final isRecording = ValueNotifier<bool>(false);
  FlutterPianoAudioDetection fpad = new FlutterPianoAudioDetection();
  Stream<List<dynamic>>? result;

  String noteOn = "x";

  @override
  void initState() {
    super.initState();
    fpad.prepare();
  }

  Future<bool> _fetch() async {
    return fpad.getTfLiteState == tfLiteState.SUCCESS ? true : false;
  }

  void prepare() {
    fpad.prepare();
  }

  void start() {
    fpad.start();
    getResult();
  }

  void stop() {
    fpad.stop();
  }

  void getResult() {
    result = fpad.startAudioRecognition();

    result!.listen((event) {
      List<String> notes = [];
      event.forEach((element) {
        // print(element);
        int tempnum = element;
        notes.add(fpad.getNoteName(tempnum - 20));
        // print(fpad.getNoteName(tempnum));
      });
      if (notes.length > 0) print(notes);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter Pitch Tracker'),
        ),
        body: Center(
          child: FutureBuilder<bool>(
            future: _fetch(),
            builder: (BuildContext context, AsyncSnapshot snapshot) {
              // print(snapshot);
              if (!snapshot.hasData || !snapshot.data) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    CircularProgressIndicator(),
                    Padding(padding: EdgeInsets.only(bottom: 20)),
                    Text(
                      "Loading",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  ],
                );
              } else {
                return Container();
              }
            },
          ),
        ),
        floatingActionButton: Container(
          child: ValueListenableBuilder(
            valueListenable: isRecording,
            builder: (context, value, widget) {
              if (value == false) {
                return FloatingActionButton(
                  onPressed: () {
                    isRecording.value = true;
                    start();
                  },
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.mic),
                );
              } else {
                return FloatingActionButton(
                  onPressed: () {
                    isRecording.value = false;
                    stop();
                  },
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.adjust),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}
