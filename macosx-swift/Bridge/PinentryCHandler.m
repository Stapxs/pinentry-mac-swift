#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import <dlfcn.h>
#import <libproc.h>
#import "pinentry.h"
#import "KeychainSupport.h"
#import "NSStringExtensions.h"
#import "pinentry_mac_swift-Swift.h"

static int pinentry_mac_swift_cmd_handler(pinentry_t pe);
pinentry_cmd_handler_t pinentry_cmd_handler = pinentry_mac_swift_cmd_handler;

int PinentryMacSwiftEvaluateQuality(void *pinentryPointer, const char *passphrase, size_t length) {
    if (!pinentryPointer || !passphrase) {
        return 0;
    }

    return pinentry_inq_quality((pinentry_t)pinentryPointer, passphrase, length);
}

int PinentryMacSwiftCopyParentProcessID(int processID) {
    if (processID <= 1) {
        return 0;
    }

    struct proc_bsdinfo processInfo;
    int bytesRead = proc_pidinfo(processID, PROC_PIDTBSDINFO, 0, &processInfo, PROC_PIDTBSDINFO_SIZE);
    if (bytesRead != PROC_PIDTBSDINFO_SIZE) {
        return 0;
    }

    return processInfo.pbi_ppid;
}

static BOOL PinentryMacSwiftIsAtLeastMacOS(NSInteger majorVersion, NSInteger minorVersion) {
    NSOperatingSystemVersion version = {
        .majorVersion = majorVersion,
        .minorVersion = minorVersion,
        .patchVersion = 0,
    };
    return [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:version];
}

static void PinentryMacSwiftPinSubview(NSView *subview, NSView *container) {
    [container addSubview:subview];
    [NSLayoutConstraint activateConstraints:@[
        [subview.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [subview.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [subview.topAnchor constraintEqualToAnchor:container.topAnchor],
        [subview.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];
}

NSView *PinentryMacSwiftCreateGlassContainer(NSView *hostingView, NSRect frame) {
    if (PinentryMacSwiftIsAtLeastMacOS(26, 0)) {
        Class glassEffectViewClass = NSClassFromString(@"NSGlassEffectView");
        if (glassEffectViewClass != Nil) {
            id glassView = [[glassEffectViewClass alloc] initWithFrame:frame];
            if ([glassView isKindOfClass:[NSView class]]) {
                if ([glassView respondsToSelector:@selector(setContentView:)]) {
                    [glassView setValue:hostingView forKey:@"contentView"];
                } else {
                    PinentryMacSwiftPinSubview(hostingView, glassView);
                }

                if ([glassView respondsToSelector:@selector(setCornerRadius:)]) {
                    [glassView setValue:@26.0 forKey:@"cornerRadius"];
                }
                if ([glassView respondsToSelector:@selector(setStyle:)]) {
                    [glassView setValue:@0 forKey:@"style"];
                }
                if ([glassView respondsToSelector:@selector(setTintColor:)]) {
                    [glassView setValue:[NSColor.whiteColor colorWithAlphaComponent:0.12] forKey:@"tintColor"];
                }
                if (
                    PinentryMacSwiftIsAtLeastMacOS(27, 0) &&
                    [glassView respondsToSelector:@selector(setEffectIsInteractive:)]
                ) {
                    [glassView setValue:@YES forKey:@"effectIsInteractive"];
                }

                return glassView;
            }
        }
    }

    NSVisualEffectView *effectView = [[NSVisualEffectView alloc] initWithFrame:frame];
    effectView.material = NSVisualEffectMaterialHUDWindow;
    effectView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    effectView.state = NSVisualEffectStateActive;
    effectView.wantsLayer = YES;
    effectView.layer.cornerRadius = 26;
    effectView.layer.masksToBounds = YES;
    effectView.layer.borderWidth = 1;
    effectView.layer.borderColor = [NSColor.whiteColor colorWithAlphaComponent:0.16].CGColor;

    PinentryMacSwiftPinSubview(hostingView, effectView);
    return effectView;
}

static Class PinentryMacSwiftAuthenticationViewClass(void) {
    static dispatch_once_t onceToken;
    static Class authenticationViewClass = Nil;

    dispatch_once(&onceToken, ^{
        dlopen(
            "/System/Library/Frameworks/LocalAuthenticationEmbeddedUI.framework/Versions/A/LocalAuthenticationEmbeddedUI",
            RTLD_LAZY | RTLD_LOCAL
        );
        authenticationViewClass = NSClassFromString(@"LAAuthenticationView");
    });

    return authenticationViewClass;
}

BOOL PinentryMacSwiftCanCreateAuthenticationView(void) {
    Class authenticationViewClass = PinentryMacSwiftAuthenticationViewClass();
    return authenticationViewClass != Nil &&
        [authenticationViewClass instancesRespondToSelector:@selector(initWithContext:controlSize:)];
}

NSView *PinentryMacSwiftCreateAuthenticationView(LAContext *context, NSControlSize controlSize) {
    if (!context) {
        return nil;
    }

    Class authenticationViewClass = PinentryMacSwiftAuthenticationViewClass();
    SEL initializer = @selector(initWithContext:controlSize:);
    if (authenticationViewClass == Nil ||
        ![authenticationViewClass instancesRespondToSelector:initializer]) {
        return nil;
    }

    id allocatedView = [authenticationViewClass alloc];
    typedef id (*InitializerIMP)(id, SEL, LAContext *, NSControlSize);
    InitializerIMP initializerIMP = (InitializerIMP)[allocatedView methodForSelector:initializer];
    id authenticationView = initializerIMP(allocatedView, initializer, context, controlSize);
    if (![authenticationView isKindOfClass:[NSView class]]) {
        return nil;
    }

    return authenticationView;
}

static NSString *StringFromPinentryCString(char *string) {
    if (!string) {
        return nil;
    }

    return [NSString gpgStringWithCString:string];
}

static NSString *StringFromEnvironment(const char *name) {
    const char *value = getenv(name);
    if (!value || !*value) {
        return nil;
    }

    return [NSString gpgStringWithCString:value];
}

static NSString *CacheIdFromKeyInfo(NSString *keyInfo) {
    if (keyInfo.length <= 2) {
        return nil;
    }

    NSString *cacheMode = [keyInfo substringToIndex:1];
    if ([cacheMode isEqualToString:@"u"]) {
        return nil;
    }

    return [keyInfo substringFromIndex:2];
}

static void FillIdentityFromDescription(CPinentryRequest *request, NSString *description) {
    NSArray *lines = [description componentsSeparatedByString:@"\n"];
    if (lines.count <= 2) {
        return;
    }

    NSString *userID = [[lines objectAtIndex:1] stringBetweenString:@"\"" andString:@"\"" needEnd:YES];
    if (userID.length > 0) {
        request.userID = userID;

        NSString *workString = userID;
        NSUInteger textLength = workString.length;
        NSRange range;

        if ([workString hasSuffix:@">"] && (range = [workString rangeOfString:@" <" options:NSBackwardsSearch]).length > 0) {
            range.location += 2;
            range.length = textLength - range.location - 1;
            request.email = [workString substringWithRange:range];
            workString = [workString substringToIndex:range.location - 2];
            textLength -= range.length + 3;
        }

        range = [workString rangeOfString:@" (" options:NSBackwardsSearch];
        if (range.length > 0 && range.location > 0 && [workString hasSuffix:@")"]) {
            range.location += 2;
            range.length = textLength - range.location - 1;
            request.comment = [workString substringWithRange:range];
            workString = [workString substringToIndex:range.location - 2];
        }

        request.name = workString;
    }

    NSString *keyID = [description stringBetweenString:@"ID " andString:@"," needEnd:YES];
    if (keyID.length == 8 || keyID.length == 16) {
        request.keyID = keyID;
    }
}

static NSString *KeychainLabelForRequest(CPinentryRequest *request) {
    if (request.userID.length == 0) {
        return nil;
    }

    return [NSString stringWithFormat:@"%@ <%@> (%@)", request.name, request.email, request.keyID];
}

static NSString *AutomaticTouchIDPromptForRequest(CPinentryRequest *request) {
    NSString *label = KeychainLabelForRequest(request);
    if (label.length > 0) {
        return [NSString stringWithFormat:@"Unlock %@.", label];
    }

    return @"Unlock your GPG passphrase.";
}

static CPinentryRequest *MakeRequest(pinentry_t pe) {
    CPinentryRequest *request = [[CPinentryRequest alloc] init];
    NSString *description = StringFromPinentryCString(pe->description);

    request.requiresPassphrase = pe->pin != NULL;
    request.title = StringFromPinentryCString(pe->title);
    request.message = description;
    request.errorText = StringFromPinentryCString(pe->error);
    request.promptText = StringFromPinentryCString(pe->prompt);
    request.okText = StringFromPinentryCString(pe->ok);
    request.cancelText = StringFromPinentryCString(pe->cancel);
    request.notOkText = StringFromPinentryCString(pe->notok);
    request.repeatPassphrase = pe->repeat_passphrase != NULL;
    request.qualityBarRequested = pe->quality_bar != NULL;
    request.timeoutSeconds = pe->timeout;
    request.keyInfo = StringFromPinentryCString(pe->keyinfo);
    request.prefersSaveInKeychain = [[NSUserDefaults standardUserDefaults] boolForKey:@"UseKeychain"];
    request.prefersShowTyping = NO;
    request.userData = StringFromEnvironment("PINENTRY_USER_DATA");
    request.ownerPID = pe->owner_pid > 0 ? (NSInteger)pe->owner_pid : 0;
    request.pinentryPointer = pe;

    FillIdentityFromDescription(request, description);
    return request;
}

static int WritePassphraseToPinentry(pinentry_t pe, NSString *passphrase) {
    const char *utf8 = passphrase.UTF8String;
    if (!utf8) {
        return -1;
    }

    int length = (int)strlen(utf8);
    pinentry_setbufferlen(pe, length + 1);
    if (!pe->pin) {
        return -1;
    }

    strcpy(pe->pin, utf8);
    return length;
}

static int pinentry_mac_swift_cmd_handler(pinentry_t pe) {
    @autoreleasepool {
        static NSString *lastCacheIdUsed = nil;
        static BOOL doNotUseKeychain = NO;

        CPinentryRequest *request = MakeRequest(pe);
        NSString *cacheId = CacheIdFromKeyInfo(request.keyInfo);
        NSString *keychainLabel = KeychainLabelForRequest(request);
        BOOL lastTryWasKeychain = lastCacheIdUsed && [cacheId isEqualToString:lastCacheIdUsed];
        lastCacheIdUsed = nil;

        if (
            doNotUseKeychain
        ) {
            cacheId = nil;
        }

        if (
            request.requiresPassphrase &&
            cacheId &&
            !pe->error &&
            !request.repeatPassphrase &&
            !lastTryWasKeychain &&
            hasPassphraseInKeychain(cacheId)
        ) {
            request.attemptsAutomaticTouchID = YES;
            request.automaticTouchIDCacheID = cacheId;
            request.automaticTouchIDPrompt = AutomaticTouchIDPromptForRequest(request);
            request.automaticTouchIDKeychainLabel = keychainLabel;
        } else if (
            request.requiresPassphrase &&
            keychainLabel.length > 0 &&
            !pe->error &&
            !request.repeatPassphrase &&
            hasPassphraseInKeychainWithLabel(keychainLabel)
        ) {
            request.attemptsAutomaticTouchID = YES;
            request.automaticTouchIDPrompt = AutomaticTouchIDPromptForRequest(request);
            request.automaticTouchIDKeychainLabel = keychainLabel;
        }

        CPinentryResponse *response = [PinentryMacSwiftRuntime runRequest:request];

        if (request.requiresPassphrase) {
            if (response.canceled || response.declined) {
                return -1;
            }

            int length = WritePassphraseToPinentry(pe, response.passphrase ?: @"");
            if (length < 0) {
                return -1;
            }

            if (pe->repeat_passphrase && response.repeatOkay) {
                pe->repeat_okay = 1;
            }

            if (response.keychainUnusable) {
                doNotUseKeychain = YES;
                cacheId = nil;
            }

            if (response.pinFromCache) {
                pe->pin_from_cache = 1;
                if (cacheId.length > 0) {
                    lastCacheIdUsed = [cacheId copy];
                }
            }

            if (cacheId && response.saveInKeychain && response.passphrase.length > 0) {
                storePassphraseInKeychain(cacheId, response.passphrase, keychainLabel);
            }

            return length;
        }

        if (response.confirmed) {
            return 1;
        }

        if (response.declined) {
            return 0;
        }

        pe->canceled = 1;
        return 0;
    }
}
