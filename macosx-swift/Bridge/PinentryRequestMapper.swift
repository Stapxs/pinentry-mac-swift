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

        let iconSource: DialogModel.IconSource
        if let iconPath = parsedUserData.iconPath, !iconPath.isEmpty {
            iconSource = .filePath(iconPath)
        } else {
            iconSource = .appIcon
        }

        return DialogModel(
            mode: payload.requiresPassphrase ? .passphrase : .confirm,
            title: payload.title?.nonEmpty ?? "Pinentry Mac",
            message: parsedUserData.resolvedDescription?.nonEmpty ?? "",
            errorText: payload.errorText?.nonEmpty,
            promptText: payload.promptText?.nonEmpty,
            okText: payload.okText?.nonEmpty ?? (payload.requiresPassphrase ? "Unlock" : "Allow"),
            cancelText: payload.cancelText?.nonEmpty ?? "Cancel",
            notOkText: payload.requiresPassphrase ? nil : payload.notOkText?.nonEmpty,
            showsRepeatField: payload.requiresPassphrase && payload.repeatPassphrase,
            showsQualityBar: payload.requiresPassphrase && payload.qualityBarRequested,
            canUseKeychain: payload.requiresPassphrase && cachePolicy.canPersistPassphrase(for: payload.keyInfo),
            showTypingToggleAvailable: payload.requiresPassphrase,
            saveInKeychainDefault: payload.prefersSaveInKeychain,
            showTypingDefault: payload.prefersShowTyping,
            timeoutSeconds: payload.timeoutSeconds,
            iconSource: iconSource
        )
    }
}

private extension String {
    var nonEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
