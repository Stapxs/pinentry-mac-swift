#import <Cocoa/Cocoa.h>
#import <Security/Security.h>
#import "MacOSXSwiftAppDelegate.h"
#import "pinentry.h"

#if __has_include("config.h")
#import "config.h"
#endif

extern pinentry_cmd_handler_t pinentry_cmd_handler;

#ifdef CODE_SIGN_CHECK
#define MACRO_TO_STRING(m) #m
#define CODE_SIGN_CERT MACRO_TO_STRING(CODE_SIGN_CHECK)
static BOOL isBundleValidSigned(NSBundle *bundle) {
    SecRequirementRef requirement = nil;
    SecStaticCodeRef staticCode = nil;

    SecStaticCodeCreateWithPath((__bridge CFURLRef)[bundle bundleURL], 0, &staticCode);
    SecRequirementCreateWithString(CFSTR("anchor apple generic and cert leaf = H\"" CODE_SIGN_CERT "\""), 0, &requirement);
    OSStatus result = SecStaticCodeCheckValidity(staticCode, 0, requirement);

    if (staticCode) {
        CFRelease(staticCode);
    }
    if (requirement) {
        CFRelease(requirement);
    }
    return result == noErr;
}
#endif

#ifdef FALLBACK_CURSES
#import <pinentry-curses.h>

static int pinentry_mac_swift_is_curses_demanded(void) {
    const char *userData = getenv("PINENTRY_USER_DATA");
    return userData && *userData && strstr(userData, "USE_CURSES=1") != NULL;
}
#endif

int main(int argc, char *argv[]) {
    @autoreleasepool {
#ifdef CODE_SIGN_CHECK
        if (!isBundleValidSigned([NSBundle mainBundle])) {
            NSRunAlertPanel(
                @"Someone tampered with your installation of pinentry-mac-swift!",
                @"To keep you safe, pinentry-mac-swift will exit now.",
                nil,
                nil,
                nil
            );
            return 1;
        }
#endif

        pinentry_init("pinentry-mac-swift");
        pinentry_parse_opts(argc, argv);

#ifdef FALLBACK_CURSES
        if (pinentry_mac_swift_is_curses_demanded()) {
            pinentry_cmd_handler = curses_cmd_handler;
            return pinentry_loop() ? 1 : 0;
        }
#endif

        NSApplication *application = [NSApplication sharedApplication];
        PinentryMacSwiftAppDelegate *delegate = [[PinentryMacSwiftAppDelegate alloc] init];
        application.delegate = delegate;
        [application run];
    }

    return 0;
}
