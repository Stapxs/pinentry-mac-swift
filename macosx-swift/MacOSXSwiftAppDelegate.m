#import "MacOSXSwiftAppDelegate.h"
#import "pinentry.h"

@implementation PinentryMacSwiftAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [[NSUserDefaults standardUserDefaults] addSuiteNamed:@"org.gpgtools.common"];
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"UseKeychain": @YES}];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        int result = pinentry_loop();
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSApp terminate:nil];
            exit(result ? 1 : 0);
        });
    });
}

@end
