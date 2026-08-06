import AppKit
import Darwin
import Foundation
import SwiftUI

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
    @objc var userData: String?
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
            userData: userData,
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

    convenience init(bridgeResult: PinentryBridgeResult) {
        self.init()
        confirmed = bridgeResult.confirmed
        canceled = bridgeResult.canceled
        declined = bridgeResult.declined
        passphrase = bridgeResult.passphrase
        repeatOkay = bridgeResult.repeatOkay
        saveInKeychain = bridgeResult.saveInKeychain
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
        let mapper = PinentryRequestMapper()
        let model = mapper.map(request.payload)
        let qualityEstimator = PinentryInquiryQualityEstimator(
            pinentryPointer: request.pinentryPointer
        )
        let coordinator = WindowPresentationCoordinator(
            qualityEstimator: qualityEstimator
        )
        let window = makeWindow(coordinator: coordinator)
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        let response = await coordinator.present(dialog: model)
        window.close()

        let bridgeResult = PinentryResultWriter().makeResult(
            from: response,
            repeatExpected: request.repeatPassphrase
        )
        return CPinentryResponse(bridgeResult: bridgeResult)
    }

    @MainActor
    private static func makeWindow(coordinator: WindowPresentationCoordinator) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 540),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "pinentry-mac-swift"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .transient]
        window.contentView = NSHostingView(
            rootView: PrototypeWindowView(coordinator: coordinator)
        )
        return window
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
