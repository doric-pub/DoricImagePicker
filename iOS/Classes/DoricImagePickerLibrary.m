#import "DoricImagePickerLibrary.h"
#import "DoricImagePickerPlugin.h"

@implementation DoricImagePickerLibrary
- (void)load:(DoricRegistry *)registry {
    NSString *path = [[NSBundle mainBundle] bundlePath];
    NSString *fullPath = [path stringByAppendingPathComponent:@"bundle_doricimagepicker.js"];
    NSString *jsContent = [NSString stringWithContentsOfFile:fullPath encoding:NSUTF8StringEncoding error:nil];
    [registry registerJSBundle:jsContent withName:@"doric-imagepicker"];
    [registry registerNativePlugin:DoricImagePickerPlugin.class withName:@"imagePicker"];
}
@end