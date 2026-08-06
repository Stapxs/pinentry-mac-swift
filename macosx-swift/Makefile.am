# SwiftUI macOS frontend for pinentry.

libexec_PROGRAMS = pinentry-mac-swift.app

XCODE_PROJECT = pinentry-mac-swift.xcodeproj
XCODE_SCHEME = pinentry-mac-swift
XCODE_CONFIGURATION = Release
XCODE_DERIVED_DATA = $(abs_builddir)/DerivedData
XCODE_PRODUCTS = $(abs_builddir)/Products

EXTRA_DIST = \
	Assets.xcassets \
	Bridge \
	Icon.icns \
	Info.plist \
	MacOSXSwiftAppDelegate.h \
	MacOSXSwiftAppDelegate.m \
	MacOSXSwiftMain.m \
	Models \
	PinentryMacSwift-Bridging-Header.h \
	PinentryMacSwiftRuntime.swift \
	Scripts \
	Services \
	ViewModels \
	Views \
	$(XCODE_PROJECT) \
	project.xcworkspace

../pinentry/libpinentry.a ../secmem/libsecmem.a:
	./Scripts/build-pinentry-core-libs.sh

pinentry-mac-swift.app: ../pinentry/libpinentry.a ../secmem/libsecmem.a
	xcodebuild \
		-project "$(XCODE_PROJECT)" \
		-scheme "$(XCODE_SCHEME)" \
		-configuration "$(XCODE_CONFIGURATION)" \
		-derivedDataPath "$(XCODE_DERIVED_DATA)" \
		CONFIGURATION_BUILD_DIR="$(XCODE_PRODUCTS)" \
		ONLY_ACTIVE_ARCH=YES \
		HEADER_SEARCH_PATHS="$(abs_top_srcdir) $(abs_top_srcdir)/pinentry $(abs_top_srcdir)/secmem $(abs_top_srcdir)/macosx /usr/local/MacGPG2/include /opt/homebrew/include" \
		OTHER_CFLAGS="$(COMMON_CFLAGS)" \
			OTHER_LDFLAGS="$(abs_top_builddir)/pinentry/libpinentry.a $(abs_top_builddir)/secmem/libsecmem.a $(COMMON_LIBS) -L/usr/local/MacGPG2/lib -L/opt/homebrew/lib -lassuan -lgpg-error -framework Security -framework LocalAuthentication -framework LocalAuthenticationEmbeddedUI"
	rm -rf $@
	cp -R "$(XCODE_PRODUCTS)/pinentry-mac-swift.app" $@

clean-local:
	rm -rf pinentry-mac-swift.app "$(XCODE_DERIVED_DATA)" "$(XCODE_PRODUCTS)"
