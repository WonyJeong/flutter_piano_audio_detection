import 'dart:async';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'note_parser.dart';

enum audioPermissionState { GRANTED, DENIED }
enum tfLiteState { WAIT, PERMISSION_DENIED, ISLODING, SUCCESS, ERROR }
enum recordingState { START, STOP, ERROR }

class FlutterPianoAudioDetection {
  NoteParser noteParser = new NoteParser();
  tfLiteState _tfLiteState = tfLiteState.WAIT;
  recordingState _recordingState = recordingState.STOP;
  audioPermissionState _audioPermissionState = audioPermissionState.DENIED;

  // Method & Event Channel
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
      // .then((value) => _tfLiteState = tfLiteState.SUCCESS)
      // .onError((error, stackTrace) => _tfLiteState = tfLiteState.ERROR);
    } else {
      _tfLiteState = tfLiteState.PERMISSION_DENIED;
    }
  }

  start() async {
    await _channel.invokeMethod("start");
  }

  stop() async {
    await _channel.invokeMethod("stop");
    _channel.setMethodCallHandler((call) async {});
  }

  String getNoteName(int midiNumber) {
    return noteParser.getNoteName(midiNumber);
  }

  tfLiteState get getTfLiteState => _tfLiteState;
  audioPermissionState get getAudioPermissionState => _audioPermissionState;
}
