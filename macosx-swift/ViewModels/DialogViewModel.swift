import AppKit
import Foundation
import LocalAuthentication
import SwiftUI

@MainActor
final class DialogViewModel: ObservableObject {
    @Published var passphrase = ""
    @Published var repeatedPassphrase = ""
    @Published var saveInKeychain: Bool
    @Published var showTypedPassphrase: Bool
    @Published private(set) var response: DialogResponse?
    @Published private(set) var remainingSeconds: Int?
    @Published private(set) var showsInlineTouchID = false
    @Published private(set) var inlineTouchIDContext: LAContext?

    let dialog: DialogModel

    private let iconResolver: any IconResolving
    private let qualityEstimator: any PassphraseQualityEstimating
    private let timeoutController: any TimeoutControlling
    private let onResolve: ((DialogResponse) -> Void)?
    private var timeoutTask: Task<Void, Never>?
    private var automaticTouchIDTask: Task<Void, Never>?
    private var didAttemptAutomaticTouchID = false
    private var keychainMarkedUnusable = false
    private var touchIDSession = 0

    init(
        dialog: DialogModel,
        iconResolver: any IconResolving = IconResolver(),
        qualityEstimator: any PassphraseQualityEstimating = HeuristicQualityEstimator(),
        timeoutController: any TimeoutControlling = TimeoutController(),
        onResolve: ((DialogResponse) -> Void)? = nil
    ) {
        self.dialog = dialog
        self.iconResolver = iconResolver
        self.qualityEstimator = qualityEstimator
        self.timeoutController = timeoutController
        self.onResolve = onResolve
        self.saveInKeychain = dialog.saveInKeychainDefault
        self.showTypedPassphrase = dialog.showTypingDefault
        self.remainingSeconds = dialog.timeoutSeconds

        NSLog(
            """
            [pinentry-mac-swift][view-model]
            dialog: title=%@ | prompt=%@ | ok=%@ | cancel=%@
            local: showTyping=%@ | saveInKeychain=%@ | timeout=%@
            """,
            dialog.title,
            dialog.promptText ?? "<nil>",
            dialog.okText,
            dialog.cancelText,
            L10n.showTyping,
            L10n.saveInKeychain,
            dialog.timeoutSeconds.map { L10n.timeoutHint(secondsRemaining: $0) } ?? "<nil>"
        )

        beginTimeoutIfNeeded()
    }

    deinit {
        timeoutTask?.cancel()
        automaticTouchIDTask?.cancel()
    }

    var state: DialogViewState {
        let showsOptions = dialog.mode == .passphrase && (dialog.canUseKeychain || dialog.showTypingToggleAvailable)
        let showsError = !(dialog.errorText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let showsQuality = dialog.mode == .passphrase && dialog.showsQualityBar && qualityAssessment != nil

        return DialogViewState(
            isExpanded: showsError || dialog.showsRepeatField || showsQuality || showsOptions,
            showsErrorSection: showsError,
            showsOptionsSection: showsOptions,
            showsRepeatField: dialog.mode == .passphrase && dialog.showsRepeatField,
            showsQualityBar: showsQuality
        )
    }

    var titleText: String {
        showsInlineTouchID ? L10n.touchIDDialogTitle : dialog.title
    }

    var primaryActionTitle: String {
        dialog.okText
    }

    var secondaryActionTitle: String {
        dialog.cancelText
    }

    var tertiaryActionTitle: String? {
        dialog.notOkText
    }

    var promptText: String {
        let trimmed = dialog.promptText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? L10n.defaultPassphrasePrompt : trimmed
    }

    var confirmPromptText: String {
        let normalizedPrompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasePrompt = normalizedPrompt.lowercased()

        if lowercasePrompt.contains("confirm") || normalizedPrompt.hasPrefix(L10n.confirmPromptPrefix) {
            return normalizedPrompt
        }

        return L10n.confirmPrompt(normalizedPrompt)
    }

    var mismatchHint: String? {
        guard state.showsRepeatField, !repeatedPassphrase.isEmpty, repeatedPassphrase != passphrase else {
            return nil
        }

        return L10n.mismatchHint
    }

    var qualityAssessment: PassphraseQualityAssessment? {
        guard dialog.mode == .passphrase, dialog.showsQualityBar else {
            return nil
        }

        return qualityEstimator.evaluate(passphrase: passphrase)
    }

    var isPrimaryActionEnabled: Bool {
        switch dialog.mode {
        case .confirm:
            return true
        case .passphrase:
            return mismatchHint == nil
        }
    }

    var keyboardPrompt: String? {
        guard let remainingSeconds, remainingSeconds > 0 else {
            return nil
        }

        return L10n.timeoutHint(secondsRemaining: remainingSeconds)
    }

    var usePasswordActionTitle: String {
        L10n.usePasswordAction
    }

    func resolveIcon() -> Image {
        switch dialog.iconSource {
        case .systemSymbol(let name):
            return Image(systemName: name)
        default:
            if let image = iconResolver.resolve(dialog.iconSource) {
                return Image(nsImage: image)
            }

            return Image(systemName: "lock.circle.fill")
        }
    }

    func confirm() {
        guard isPrimaryActionEnabled else {
            return
        }

        finish(
            DialogResponse(
                confirmed: true,
                canceled: false,
                declined: false,
                passphrase: passphrase,
                saveInKeychain: saveInKeychain,
                pinFromCache: false,
                keychainUnusable: keychainMarkedUnusable
            )
        )
    }

    func cancel() {
        finish(
            DialogResponse(
                confirmed: false,
                canceled: true,
                declined: false,
                passphrase: "",
                saveInKeychain: false,
                pinFromCache: false,
                keychainUnusable: keychainMarkedUnusable
            )
        )
    }

    func decline() {
        finish(
            DialogResponse(
                confirmed: false,
                canceled: false,
                declined: true,
                passphrase: "",
                saveInKeychain: false,
                pinFromCache: false,
                keychainUnusable: keychainMarkedUnusable
            )
        )
    }

    func beginAutomaticTouchIDIfNeeded() {
        guard response == nil, !didAttemptAutomaticTouchID else {
            return
        }

        didAttemptAutomaticTouchID = true

        guard
            dialog.mode == .passphrase,
            dialog.attemptsAutomaticTouchID,
            let localizedReason = dialog.automaticTouchIDPrompt?.trimmingCharacters(in: .whitespacesAndNewlines),
            !localizedReason.isEmpty
        else {
            return
        }

        let cacheID = dialog.automaticTouchIDCacheID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let keychainLabel = dialog.automaticTouchIDKeychainLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let keychainQuery = AutomaticTouchIDQuery(cacheID: cacheID, keychainLabel: keychainLabel)
        else {
            return
        }

        let context = LAContext()
        context.localizedFallbackTitle = ""
        var evaluationError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &evaluationError) else {
            return
        }

        touchIDSession += 1
        let session = touchIDSession
        inlineTouchIDContext = context
        showsInlineTouchID = true

        automaticTouchIDTask = Task { [weak self] in
            let result = await Self.performAutomaticTouchID(
                query: keychainQuery,
                localizedReason: localizedReason,
                context: context
            )

            await MainActor.run {
                guard let self, self.response == nil, session == self.touchIDSession else {
                    return
                }

                switch result {
                case .resolved(let passphrase):
                    self.finish(
                        DialogResponse(
                            confirmed: true,
                            canceled: false,
                            declined: false,
                            passphrase: passphrase,
                            saveInKeychain: false,
                            pinFromCache: true,
                            keychainUnusable: false
                        )
                    )
                case .unusableKeychain:
                    self.keychainMarkedUnusable = true
                    self.showPasswordEntryAfterTouchID(invalidateContext: false)
                case .continueManually:
                    self.showPasswordEntryAfterTouchID(invalidateContext: false)
                }
            }
        }
    }

    func usePasswordInstead() {
        showPasswordEntryAfterTouchID(invalidateContext: true)
    }

    private func finish(_ response: DialogResponse) {
        self.response = response
        timeoutTask?.cancel()
        automaticTouchIDTask?.cancel()
        inlineTouchIDContext?.invalidate()
        inlineTouchIDContext = nil
        onResolve?(response)
    }

    private func beginTimeoutIfNeeded() {
        guard let timeout = dialog.timeoutSeconds, timeout > 0 else {
            return
        }

        timeoutTask = timeoutController.start(
            timeoutSeconds: timeout
        ) { [weak self] second in
            self?.remainingSeconds = second
        } onExpire: { [weak self] in
            guard let self, self.response == nil else {
                return
            }

            self.cancel()
        }
    }

    private enum AutomaticTouchIDResult {
        case resolved(String)
        case unusableKeychain
        case continueManually
    }

    private struct AutomaticTouchIDQuery {
        let cacheID: String?
        let keychainLabel: String?

        init?(cacheID: String?, keychainLabel: String?) {
            let normalizedCacheID = cacheID?.isEmpty == false ? cacheID : nil
            let normalizedKeychainLabel = keychainLabel?.isEmpty == false ? keychainLabel : nil

            guard normalizedCacheID != nil || normalizedKeychainLabel != nil else {
                return nil
            }

            self.cacheID = normalizedCacheID
            self.keychainLabel = normalizedKeychainLabel
        }
    }

    private static func performAutomaticTouchID(
        query: AutomaticTouchIDQuery,
        localizedReason: String,
        context: LAContext
    ) async -> AutomaticTouchIDResult {
        let didAuthenticate = await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: localizedReason) { success, _ in
                continuation.resume(returning: success)
            }
        }

        guard didAuthenticate else {
            return .continueManually
        }

        var keychainUnusable = ObjCBool(false)
        let passphrase: String?
        if let cacheID = query.cacheID {
            passphrase = getPassphraseFromKeychain(cacheID, &keychainUnusable)
        } else if let keychainLabel = query.keychainLabel {
            passphrase = getPassphraseFromKeychainWithLabel(keychainLabel, &keychainUnusable)
        } else {
            passphrase = nil
        }

        if keychainUnusable.boolValue {
            return .unusableKeychain
        }

        guard let passphrase, !passphrase.isEmpty else {
            return .continueManually
        }

        return .resolved(passphrase)
    }

    private func showPasswordEntryAfterTouchID(invalidateContext: Bool) {
        touchIDSession += 1
        automaticTouchIDTask?.cancel()
        automaticTouchIDTask = nil
        if invalidateContext {
            inlineTouchIDContext?.invalidate()
        }
        inlineTouchIDContext = nil
        showsInlineTouchID = false
    }
}
