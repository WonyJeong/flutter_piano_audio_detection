import 'dart:async';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

enum audioPermissionState { GRANTED, DENIED }
enum tfLiteState { WAIT, PERMISSION_DENIED, ISLODING, SUCCESS, ERROR }
enum recordingState { START, STOP, ERROR }
final String logTag = "FLUTTER_PIANO_AUDIO_DETECTION_PLUGIN : ";

class FlutterPianoAudioDetection {
  tfLiteState _tfLiteState = tfLiteState.WAIT;
  recordingState _recordingState = recordingState.STOP;
  audioPermissionState _audioPermissionState = audioPermissionState.DENIED;

  static const MethodChannel _channel =
      const MethodChannel('flutter_piano_audio_detection');

  static const EventChannel _eventChannel =
      const EventChannel('startAudioRecognition');

  Stream<List<dynamic>> startAudioRecognition() {
    return _eventChannel.receiveBroadcastStream().cast();
  }

  Future<bool> checkPermission() async {
    var _status = await Permission.microphone.status;

    if (_status.isDenied) {
      bool status = await Permission.microphone.request().isGranted;
      status
          ? _audioPermissionState = audioPermissionState.GRANTED
          : _audioPermissionState = audioPermissionState.DENIED;
      return status;
    } else {
      _audioPermissionState = audioPermissionState.GRANTED;
      return true;
    }
  }

  prepare() async {
    if (await checkPermission()) {
      _tfLiteState = tfLiteState.ISLODING;
      bool loadedModel = await _channel.invokeMethod("prepare");
      loadedModel
          ? _tfLiteState = tfLiteState.SUCCESS
          : _tfLiteState = tfLiteState.ERROR;
    } else {
      _tfLiteState = tfLiteState.PERMISSION_DENIED;
    }
  }

  start() async {
    if (_tfLiteState == tfLiteState.SUCCESS) {
      await _channel.invokeMethod("start");
      _recordingState = recordingState.START;
    } else {
      print(logTag + "audio permission denied.");
    }
  }

  stop() async {
    await _channel.invokeMethod("stop");
    _recordingState = recordingState.STOP;
  }

  /// `event` type is List<Map<String, dynamic>>
  ///
  /// Map<String, dynamic> has keys `[key, frame, onset, offset, velocity]`
  ///
  ///`getNotesDetail` is return recognized notes and print `[key, frame, onset, offset, velocity]` details.
  List<String> getNotesDetail(List<dynamic> event) {
    List<String> notes = [];
    event.forEach((element) {
      print(logTag +
          getNoteName(element["key"]) +
          "    " +
          element["frame"].toString() +
          "    " +
          element["onset"].toString() +
          "    " +
          element["offset"].toString());
    });
    return notes;
  }

  ///`getNotes` is return recognized notes.
  List<String> getNotes(List<dynamic> event) {
    List<String> notes = [];
    event.forEach((element) {
      notes.add(getNoteName(element["key"]));
    });
    return notes;
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
  audioPermissionState get getAudioPermissionState => _audioPermissionState;
}
