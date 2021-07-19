# FlutterPianoAudioDetection Plugin
[![pub package](https://img.shields.io/pub/v/flutter_piano_audio_detection.svg?label=version&color=blue)](https://pub.dev/packages/flutter_piano_audio_detection)
[![likes](https://badges.bar/flutter_piano_audio_detection/likes)](https://pub.dev/packages/flutter_piano_audio_detection/score)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![style: effective dart](https://img.shields.io/badge/style-effective_dart-40c4ff.svg)](https://pub.dev/packages/effective_dart)

<br>

Flutter Piano Audio Detection implemented with Tensorflow Lite Model ([Google Magenta](https://github.com/magenta/magenta/tree/main/magenta/models/onsets_frames_transcription/realtime))

- [x] Android Implementation 
- [x] iOS/iPadOS Implementation

To keep this project alive, consider giving a star or a like. Contributors are also welcome.

<br>

## Setting up a Flutter app with flutter_piano_audio_detection

### 1. Setting Tensorflow model file into your project
> First, Add tensorflow lite file in your project. Copy the downloaded [onsets_frames_wavinput.tflite](https://storage.googleapis.com/magentadata/models/onsets_frames_transcription/tflite/onsets_frames_wavinput.tflite).   

> Android : Copy the downloaded file YourApp/android/app/src/main/assets   
> iOS : Navigator -> Build Phases -> Copy Bundle Resourse    

If you have experience installing other plugins, it should be very simple.
<br>

### 2. iOS Installation & Permissions

1. Add the permissions below to your info.plist. This could be found in  <YourApp>/ios/Runner folder. For example:

```
    <key>NSMicrophoneUsageDescription</key>
    <string>Your Text</string>
```
<br>
  2. Add the following to your Podfile file.     
  Since the AudioModule library is sensitive to the iOS version, please apply the ios version in the Podfile to 12.1. and This plugin depends on [permission_handler flutter plugin](https://pub.dev/packages/permission_handler).   
  
``` Podfile 
    platform :ios, '12.1' // or higher version.
    
    // ...
 
    post_install do |installer|
      installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
          config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
            '$(inherited)',
            ## dart: PermissionGroup.microphone
            'PERMISSION_MICROPHONE=1',
          ]
        end
      end
    end
```
<br>
  
### 3. Android Installation & Permissions
1. Add the permissions below to your AndroidManifest. This could be found in  <YourApp>/android/app/src folder. For example:

```
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```
  
  <br>

2. Edit the following below to your build.gradle. This could be found in YourApp/app/src/For example:

```Gradle
aaptOptions {
        noCompress 'tflite'
  }
```

<br>


## How to use this plugin
Please look at the [example](https://github.com/WonyJeong/flutter_piano_audio_detection/tree/main/example) on how to implement these futures.

1. Add line in pubspec.yaml
```
  dependencies:
    flutter_piano_audio_detection: ${version}
```

2. Usage in Flutter Code
  
```dart
  import 'package:flutter_piano_audio_detection/flutter_piano_audio_detection.dart';
  // ...
  
  class _YourAppState extends State<MyApp> {
    FlutterPianoAudioDetection fpad = new FlutterPianoAudioDetection();
  
    Stream<List<dynamic>>? result;
    List<String> notes = [];
    
    // ...
    
    @override
    void initState() {
      super.initState();
      fpad.prepare();
    }
  
    void start() {
      fpad.start(); // Start Engine 
      getResult();  // Event Subscription
    }

    void stop() {
      fpad.stop();  // Stop Engine
    }

    void getResult() {
      result = fpad.startAudioRecognition();
      result!.listen((event) {
        setState(() {
          notes = fpad.getNotes(event); // notes = [C3, D3]
        });
      });
    }
    // ...
  }
```
  
## License

MIT
  
## Reference
- TensorflowLite https://www.tensorflow.org/lite?hl=ko
