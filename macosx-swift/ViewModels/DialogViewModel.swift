import AppKit
import Foundation
import SwiftUI

@MainActor
final class DialogViewModel: ObservableObject {
    @Published var passphrase = ""
    @Published var repeatedPassphrase = ""
    @Published var saveInKeychain: Bool
    @Published var showTypedPassphrase: Bool
    @Published private(set) var response: DialogResponse?
    @Published private(set) var remainingSeconds: Int?

    let dialog: DialogModel

    private let iconResolver: any IconResolving
    private let qualityEstimator: any PassphraseQualityEstimating
    private let timeoutController: any TimeoutControlling
    private let onResolve: ((DialogResponse) -> Void)?
    private var timeoutTask: Task<Void, Never>?

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
                saveInKeychain: saveInKeychain
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
                saveInKeychain: false
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
                saveInKeychain: false
            )
        )
    }

    private func finish(_ response: DialogResponse) {
        self.response = response
        timeoutTask?.cancel()
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
}
