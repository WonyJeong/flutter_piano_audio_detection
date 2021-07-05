#import "FlutterPianoAudioDetectionPlugin.h"
#if __has_include(<flutter_piano_audio_detection/flutter_piano_audio_detection-Swift.h>)
#import <flutter_piano_audio_detection/flutter_piano_audio_detection-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_piano_audio_detection-Swift.h"
#endif

@implementation FlutterPianoAudioDetectionPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterPianoAudioDetectionPlugin registerWithRegistrar:registrar];
}
@end
