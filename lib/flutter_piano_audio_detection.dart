import 'dart:async';
import 'package:flutter/services.dart';

enum tfLiteState { WAIT, PERMISSION_DENIED, ISLODING, SUCCESS, ERROR }
enum recordingState { START, STOP, ERROR }
final String logTag = "FLUTTER_PIANO_AUDIO_DETECTION_PLUGIN : ";

class FlutterPianoAudioDetection {
  tfLiteState _tfLiteState = tfLiteState.WAIT;
  recordingState _recordingState = recordingState.STOP;

  static const MethodChannel _channel =
      const MethodChannel('flutter_piano_audio_detection');

  static const EventChannel _eventChannel =
      const EventChannel('startAudioRecognition');

  Stream<List<dynamic>> startAudioRecognition() {
    return _eventChannel.receiveBroadcastStream().cast();
  }

  prepare() async {
    try {
      await _channel.invokeMethod("prepare");
    } catch (e) {
      print('${logTag} : ${e}');
    }
  }

  start() async {
    try {
      await _channel.invokeMethod("start");
    } catch (e) {
      print('${logTag} : ${e}');
    }
  }

  stop() async {
    try {
      await _channel.invokeMethod("stop");
    } catch (e) {
      print('${logTag} : ${e}');
    }
  }

  /// `event` type is List<Map<String, dynamic>>
  ///
  /// Map<String, dynamic> has keys `[key, frame, onset, offset, velocity]`
  ///
  ///`getNotesDetail` is return recognized notes and print `[key, frame, onset, offset, velocity]` details.
  Map<String, String> getNotesDetail(List<dynamic> event) {
    Map<String, String> result = Map();
    event.forEach((element) {
      result['key'] = getNoteName(element["key"]);
      result['frame'] = element["frame"].toString();
      result['onset'] = element["onset"].toString();
      result['offset'] = element["offset"].toString();
      result['velocity'] = element["velocity"].toString();
    });
    return result;
  }

  ///`getNotes` is return recognized notes.
  List<String> getNotes(List<dynamic> event) {
    Set<String> notes = {};
    event.forEach((element) {
      notes.add(getNoteName(element["key"]));
    });
    List<String> result = notes.toList();
    result.sort();
    return result;
  }

  List<int> getKeyNumber(List<dynamic> event) {
    Set<int> notes = {};
    event.forEach((element) {
      notes.add(element["key"]);
    });
    List<int> result = notes.toList();
    result.sort();
    return result;
  }

  String getNoteName(int n) {
    int offset = n % 12;
    String octave =
        offset < 3 ? (n ~/ 12).toString() : (n ~/ 12 + 1).toString();
    List<String> notes = [
      "A",
      "A#",
      "B",
      "C",
      "C#",
      "D",
      "D#",
      "E",
      "F",
      "F#",
      "G",
      "G#"
    ];
    return notes[n % 12] + octave;
  }

  tfLiteState get getTfLiteState => _tfLiteState;
  recordingState get getRecordingState => _recordingState;
}
