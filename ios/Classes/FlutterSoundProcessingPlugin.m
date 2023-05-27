#import "FlutterSoundProcessingPlugin.h"
#if __has_include(<flutter_sound_processing/flutter_sound_processing-Swift.h>)
#import <flutter_sound_processing/flutter_sound_processing-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_sound_processing-Swift.h"
#endif

@implementation FlutterSoundProcessingPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterSoundProcessingPlugin registerWithRegistrar:registrar];
}
@end
