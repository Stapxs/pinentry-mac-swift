import AppKit
import Darwin
import Foundation
import SwiftUI

private let windowMinimumContentSize = NSSize(width: 300, height: 0)
private let windowMaximumContentSize = NSSize(width: 420, height: 640)
private let windowShadowOutset: CGFloat = 18

private final class PinentryPanelWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
private final class PinentryHostingController: NSHostingController<PrototypeWindowView> {
    var preferredSizeDidChange: ((NSSize) -> Void)?

    init(coordinator: WindowPresentationCoordinator) {
        super.init(rootView: PrototypeWindowView(coordinator: coordinator))
        if #available(macOS 13.0, *) {
            sizingOptions = [.preferredContentSize, .intrinsicContentSize]
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var preferredContentSize: NSSize {
        didSet {
            guard preferredContentSize != oldValue else {
                return
            }

            preferredSizeDidChange?(preferredContentSize)
        }
    }
}

@objc(CPinentryRequest)
final class CPinentryRequest: NSObject {
    @objc var requiresPassphrase = false
    @objc var title: String?
    @objc var message: String?
    @objc var errorText: String?
    @objc var promptText: String?
    @objc var okText: String?
    @objc var cancelText: String?
    @objc var notOkText: String?
    @objc var repeatPassphrase = false
    @objc var qualityBarRequested = false
    @objc var timeoutSeconds = 0
    @objc var keyInfo: String?
    @objc var prefersSaveInKeychain = false
    @objc var prefersShowTyping = false
    @objc var attemptsAutomaticTouchID = false
    @objc var automaticTouchIDPrompt: String?
    @objc var automaticTouchIDCacheID: String?
    @objc var automaticTouchIDKeychainLabel: String?
    @objc var userData: String?
    @objc var ownerPID = 0
    @objc var userID = ""
    @objc var name = ""
    @objc var email = ""
    @objc var comment = ""
    @objc var keyID = ""
    @objc var pinentryPointer: UnsafeMutableRawPointer?

    var payload: PinentryRequestPayload {
        PinentryRequestPayload(
            requiresPassphrase: requiresPassphrase,
            title: title,
            message: message?.replacingOccurrences(of: "\\n", with: "\n"),
            errorText: errorText,
            promptText: promptText,
            okText: okText,
            cancelText: cancelText,
            notOkText: notOkText,
            repeatPassphrase: repeatPassphrase,
            qualityBarRequested: qualityBarRequested,
            timeoutSeconds: timeoutSeconds > 0 ? timeoutSeconds : nil,
            keyInfo: keyInfo,
            prefersSaveInKeychain: prefersSaveInKeychain,
            prefersShowTyping: prefersShowTyping,
            attemptsAutomaticTouchID: attemptsAutomaticTouchID,
            automaticTouchIDPrompt: automaticTouchIDPrompt,
            automaticTouchIDCacheID: automaticTouchIDCacheID,
            automaticTouchIDKeychainLabel: automaticTouchIDKeychainLabel,
            userData: userData,
            ownerPID: ownerPID > 0 ? ownerPID : nil,
            identity: PinentryIdentityContext(
                userID: userID,
                name: name,
                email: email,
                comment: comment,
                keyID: keyID
            )
        )
    }
}

@objc(CPinentryResponse)
final class CPinentryResponse: NSObject {
    @objc var confirmed = false
    @objc var canceled = false
    @objc var declined = false
    @objc var passphrase = ""
    @objc var repeatOkay = false
    @objc var saveInKeychain = false
    @objc var pinFromCache = false
    @objc var keychainUnusable = false

    convenience init(bridgeResult: PinentryBridgeResult) {
        self.init()
        confirmed = bridgeResult.confirmed
        canceled = bridgeResult.canceled
        declined = bridgeResult.declined
        passphrase = bridgeResult.passphrase
        repeatOkay = bridgeResult.repeatOkay
        saveInKeychain = bridgeResult.saveInKeychain
        pinFromCache = bridgeResult.pinFromCache
        keychainUnusable = bridgeResult.keychainUnusable
    }
}

@objc(PinentryMacSwiftRuntime)
final class PinentryMacSwiftRuntime: NSObject {
    @objc static func runRequest(_ request: CPinentryRequest) -> CPinentryResponse {
        let semaphore = DispatchSemaphore(value: 0)
        final class ResponseBox: @unchecked Sendable {
            var response = CPinentryResponse()
        }
        let responseBox = ResponseBox()

        DispatchQueue.main.async {
            Task { @MainActor in
                responseBox.response = await present(request)
                semaphore.signal()
            }
        }

        semaphore.wait()
        return responseBox.response
    }

    @MainActor
    private static func present(_ request: CPinentryRequest) async -> CPinentryResponse {
        NSLog(
            """
            [pinentry-mac-swift][request]
            payload: title=%@ | message=%@ | prompt=%@ | ok=%@ | cancel=%@ | notOk=%@ | timeout=%d | userData=%@
            l10n:
            %@
            """,
            request.title ?? "<nil>",
            request.message ?? "<nil>",
            request.promptText ?? "<nil>",
            request.okText ?? "<nil>",
            request.cancelText ?? "<nil>",
            request.notOkText ?? "<nil>",
            request.timeoutSeconds,
            request.userData ?? "<nil>",
            L10n.debugLocalizationContext()
        )

        let mapper = PinentryRequestMapper()
        let model = mapper.map(request.payload)
        let qualityEstimator = PinentryInquiryQualityEstimator(
            pinentryPointer: request.pinentryPointer
        )
        let coordinator = WindowPresentationCoordinator(
            qualityEstimator: qualityEstimator
        )
        coordinator.show(dialog: model)

        let hostingController = PinentryHostingController(coordinator: coordinator)
        let window = makeWindow(hostingController: hostingController)
        hostingController.preferredSizeDidChange = { [weak window] preferredSize in
            guard let window else {
                return
            }

            applyPreferredWindowSize(preferredSize, to: window, animated: true)
        }
        applyPreferredWindowSize(preferredWindowSize(for: hostingController), to: window, animated: false)
        window.center()
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            coordinator.beginAutomaticTouchIDIfNeeded()
        }

        let response = await coordinator.waitForResponse()
        window.close()

        let bridgeResult = PinentryResultWriter().makeResult(
            from: response,
            repeatExpected: request.repeatPassphrase
        )
        return CPinentryResponse(bridgeResult: bridgeResult)
    }

    @MainActor
    private static func makeWindow(hostingController: PinentryHostingController) -> NSWindow {
        let window = PinentryPanelWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowMinimumContentSize.width, height: 320),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.level = .modalPanel
        window.collectionBehavior = [.moveToActiveSpace, .transient]
        window.isMovableByWindowBackground = true
        window.animationBehavior = .alertPanel

        let hostingView = hostingController.view
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        window.contentView = makeGlassContainer(
            hostingView: hostingView,
            frame: NSRect(origin: .zero, size: window.frame.size)
        )
        return window
    }

    @MainActor
    private static func makeGlassContainer(hostingView: NSView, frame: NSRect) -> NSView {
        PinentryMacSwiftCreateGlassContainer(hostingView, frame)
    }

    @MainActor
    private static func preferredWindowSize(for hostingController: PinentryHostingController) -> NSSize {
        let unconstrained = hostingController.sizeThatFits(
            in: CGSize(
                width: windowMaximumContentSize.width,
                height: windowMaximumContentSize.height
            )
        )

        return clampedWindowSize(for: NSSize(width: unconstrained.width, height: unconstrained.height))
    }

    @MainActor
    private static func applyPreferredWindowSize(_ preferredSize: NSSize, to window: NSWindow, animated: Bool) {
        let clampedSize = clampedWindowSize(for: preferredSize)
        let currentFrame = window.frame
        let windowSize = windowFrameSize(forContentSize: clampedSize)
        let newFrame = NSRect(
            x: currentFrame.minX,
            y: currentFrame.maxY - windowSize.height,
            width: windowSize.width,
            height: windowSize.height
        )
        window.setFrame(newFrame, display: true, animate: animated)
    }

    private static func windowFrameSize(forContentSize contentSize: NSSize) -> NSSize {
        NSSize(
            width: contentSize.width + windowShadowOutset * 2,
            height: contentSize.height + windowShadowOutset * 2
        )
    }

    private static func clampedWindowSize(for size: NSSize) -> NSSize {
        NSSize(
            width: min(max(size.width, windowMinimumContentSize.width), windowMaximumContentSize.width),
            height: min(max(size.height, 0), windowMaximumContentSize.height)
        )
    }
}

private struct PinentryInquiryQualityEstimator: PassphraseQualityEstimating {
    let pinentryPointer: UnsafeMutableRawPointer?
    private let fallback = HeuristicQualityEstimator()

    func evaluate(passphrase: String) -> PassphraseQualityAssessment? {
        guard !passphrase.isEmpty else {
            return nil
        }

        guard let pinentryPointer else {
            return fallback.evaluate(passphrase: passphrase)
        }

        let quality = passphrase.withCString { cString in
            PinentryMacSwiftEvaluateQuality(
                pinentryPointer,
                cString,
                strlen(cString)
            )
        }

        guard quality > 0 else {
            return fallback.evaluate(passphrase: passphrase)
        }

        let score = min(max(Double(quality) / 100.0, 0.0), 1.0)
        let grade: PassphraseQualityAssessment.Grade
        switch score {
        case 0.85...:
            grade = .strong
        case 0.55...:
            grade = .good
        case 0.3...:
            grade = .fair
        default:
            grade = .weak
        }

        return PassphraseQualityAssessment(score: score, grade: grade)
    }
}
