import Foundation

struct PinentryRequestMapper {
    private let parser: UserDataParser
    private let cachePolicy: CacheIdentifierPolicy

    init(
        parser: UserDataParser = UserDataParser(),
        cachePolicy: CacheIdentifierPolicy = CacheIdentifierPolicy()
    ) {
        self.parser = parser
        self.cachePolicy = cachePolicy
    }

    func map(_ payload: PinentryRequestPayload) -> DialogModel {
        let parsedUserData = parser.parse(
            rawUserData: payload.userData,
            fallbackDescription: payload.message,
            identity: payload.identity
        )

        let localizedTitle = payload.title?.nonEmpty.map {
            L10n.localizeKnownPinentryText($0, role: .title)
        }
        let localizedMessage = parsedUserData.resolvedDescription?.nonEmpty.map {
            L10n.localizeKnownPinentryText($0, role: .message)
        }
        let localizedErrorText = payload.errorText?.nonEmpty.map {
            L10n.localizeKnownPinentryText($0, role: .message)
        }
        let localizedPrompt = payload.promptText?.nonEmpty.map {
            L10n.localizeKnownPinentryText($0, role: .prompt)
        }
        let localizedOkText = payload.okText?.nonEmpty.map {
            L10n.localizeKnownPinentryText($0, role: .ok)
        }
        let localizedCancelText = payload.cancelText?.nonEmpty.map {
            L10n.localizeKnownPinentryText($0, role: .cancel)
        }
        let localizedNotOkText = payload.notOkText?.nonEmpty.map {
            L10n.localizeKnownPinentryText($0, role: .notOk)
        }

        let iconSource: DialogModel.IconSource
        if let iconPath = parsedUserData.iconPath, !iconPath.isEmpty {
            iconSource = .filePath(iconPath)
        } else {
            iconSource = .appIcon
        }

        let dialog = DialogModel(
            mode: payload.requiresPassphrase ? .passphrase : .confirm,
            title: localizedTitle ?? L10n.defaultDialogTitle,
            message: localizedMessage ?? "",
            errorText: localizedErrorText,
            promptText: localizedPrompt,
            okText: localizedOkText ?? (payload.requiresPassphrase ? L10n.unlockAction : L10n.allowAction),
            cancelText: localizedCancelText ?? L10n.cancelAction,
            notOkText: payload.requiresPassphrase ? nil : localizedNotOkText,
            showsRepeatField: payload.requiresPassphrase && payload.repeatPassphrase,
            showsQualityBar: payload.requiresPassphrase && payload.qualityBarRequested,
            canUseKeychain: payload.requiresPassphrase && cachePolicy.canPersistPassphrase(for: payload.keyInfo),
            showTypingToggleAvailable: payload.requiresPassphrase,
            saveInKeychainDefault: payload.prefersSaveInKeychain,
            showTypingDefault: payload.prefersShowTyping,
            timeoutSeconds: payload.timeoutSeconds,
            iconSource: iconSource
        )

        NSLog(
            """
            [pinentry-mac-swift][mapper]
            raw: title=%@ | message=%@ | prompt=%@ | ok=%@ | cancel=%@ | notOk=%@
            localized: title=%@ | message=%@ | prompt=%@ | ok=%@ | cancel=%@ | notOk=%@
            final: title=%@ | message=%@ | prompt=%@ | ok=%@ | cancel=%@ | notOk=%@
            """,
            payload.title ?? "<nil>",
            payload.message ?? "<nil>",
            payload.promptText ?? "<nil>",
            payload.okText ?? "<nil>",
            payload.cancelText ?? "<nil>",
            payload.notOkText ?? "<nil>",
            localizedTitle ?? "<nil>",
            localizedMessage ?? "<nil>",
            localizedPrompt ?? "<nil>",
            localizedOkText ?? "<nil>",
            localizedCancelText ?? "<nil>",
            localizedNotOkText ?? "<nil>",
            dialog.title,
            dialog.message,
            dialog.promptText ?? "<nil>",
            dialog.okText,
            dialog.cancelText,
            dialog.notOkText ?? "<nil>"
        )

        return dialog
    }
}

private extension String {
    var nonEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
