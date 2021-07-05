import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_piano_audio_detection/flutter_piano_audio_detection.dart';

void main() {
  const MethodChannel channel = MethodChannel('flutter_piano_audio_detection');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await FlutterPianoAudioDetection.platformVersion, '42');
  });
}
