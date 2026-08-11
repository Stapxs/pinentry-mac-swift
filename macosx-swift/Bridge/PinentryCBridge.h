#import <AppKit/AppKit.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import <stddef.h>

int PinentryMacSwiftEvaluateQuality(void *pinentryPointer, const char *passphrase, size_t length);
int PinentryMacSwiftCopyParentProcessID(int processID);
NSView *PinentryMacSwiftCreateGlassContainer(NSView *hostingView, NSRect frame);
BOOL PinentryMacSwiftCanCreateAuthenticationView(void);
NSView *PinentryMacSwiftCreateAuthenticationView(LAContext *context, NSControlSize controlSize);
