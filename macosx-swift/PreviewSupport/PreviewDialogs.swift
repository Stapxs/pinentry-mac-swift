import Foundation

enum PreviewDialogs {
    static let minimalPassphrase = DialogModel(
        mode: .passphrase,
        title: L10n.tr("preview.minimal.title", fallback: "Unlock Secret Key"),
        message: L10n.tr(
            "preview.minimal.message",
            fallback: "pinentry needs the passphrase for your GPG key before it can continue."
        ),
        errorText: nil,
        promptText: L10n.defaultPassphrasePrompt,
        okText: L10n.unlockAction,
        cancelText: L10n.cancelAction,
        notOkText: nil,
        showsRepeatField: false,
        showsQualityBar: false,
        canUseKeychain: false,
        showTypingToggleAvailable: false,
        saveInKeychainDefault: false,
        showTypingDefault: false,
        timeoutSeconds: nil,
        iconSource: .appIcon
    )

    static let longMessage = DialogModel(
        mode: .passphrase,
        title: L10n.tr("preview.long.title", fallback: "Allow Access to Encrypted Backup"),
        message: L10n.tr(
            "preview.long.message",
            fallback: "The requested operation needs the passphrase that protects your local encryption key. Enter it below to continue with decryption for this one-time operation."
        ),
        errorText: nil,
        promptText: L10n.defaultPassphrasePrompt,
        okText: L10n.tr("preview.action.continue", fallback: "Continue"),
        cancelText: L10n.cancelAction,
        notOkText: nil,
        showsRepeatField: false,
        showsQualityBar: false,
        canUseKeychain: false,
        showTypingToggleAvailable: false,
        saveInKeychainDefault: false,
        showTypingDefault: false,
        timeoutSeconds: nil,
        iconSource: .systemSymbol("externaldrive.badge.lock")
    )

    static let errorState = DialogModel(
        mode: .passphrase,
        title: L10n.tr("preview.error.title", fallback: "Passphrase Incorrect"),
        message: L10n.tr(
            "preview.error.message",
            fallback: "The provided passphrase could not unlock your secret key. Try again."
        ),
        errorText: L10n.tr(
            "preview.error.detail",
            fallback: "The passphrase you entered was incorrect."
        ),
        promptText: L10n.defaultPassphrasePrompt,
        okText: L10n.tr("preview.action.try_again", fallback: "Try Again"),
        cancelText: L10n.cancelAction,
        notOkText: nil,
        showsRepeatField: false,
        showsQualityBar: false,
        canUseKeychain: false,
        showTypingToggleAvailable: true,
        saveInKeychainDefault: false,
        showTypingDefault: false,
        timeoutSeconds: nil,
        iconSource: .systemSymbol("exclamationmark.triangle.fill")
    )

    static let repeatEntry = DialogModel(
        mode: .passphrase,
        title: L10n.tr("preview.repeat.title", fallback: "Set New Passphrase"),
        message: L10n.tr(
            "preview.repeat.message",
            fallback: "Create a new passphrase for the selected key. You will need to enter it twice."
        ),
        errorText: nil,
        promptText: L10n.tr("preview.repeat.prompt", fallback: "New Passphrase"),
        okText: L10n.tr("preview.action.save_passphrase", fallback: "Save Passphrase"),
        cancelText: L10n.cancelAction,
        notOkText: nil,
        showsRepeatField: true,
        showsQualityBar: false,
        canUseKeychain: false,
        showTypingToggleAvailable: true,
        saveInKeychainDefault: false,
        showTypingDefault: false,
        timeoutSeconds: nil,
        iconSource: .systemSymbol("key.fill")
    )

    static let qualityEntry = DialogModel(
        mode: .passphrase,
        title: L10n.tr("preview.quality.title", fallback: "Protect Secret Key"),
        message: L10n.tr(
            "preview.quality.message",
            fallback: "Choose a passphrase strong enough to secure your key material."
        ),
        errorText: nil,
        promptText: L10n.defaultPassphrasePrompt,
        okText: L10n.tr("preview.action.use_passphrase", fallback: "Use Passphrase"),
        cancelText: L10n.cancelAction,
        notOkText: nil,
        showsRepeatField: false,
        showsQualityBar: true,
        canUseKeychain: false,
        showTypingToggleAvailable: true,
        saveInKeychainDefault: false,
        showTypingDefault: false,
        timeoutSeconds: nil,
        iconSource: .systemSymbol("lock.shield.fill")
    )

    static let optionsEntry = DialogModel(
        mode: .passphrase,
        title: L10n.tr("preview.options.title", fallback: "Unlock Signing Key"),
        message: L10n.tr(
            "preview.options.message",
            fallback: "Enter the passphrase for your signing key. You can reveal the text temporarily or remember it in Keychain for later requests."
        ),
        errorText: nil,
        promptText: L10n.defaultPassphrasePrompt,
        okText: L10n.unlockAction,
        cancelText: L10n.cancelAction,
        notOkText: nil,
        showsRepeatField: false,
        showsQualityBar: false,
        canUseKeychain: true,
        showTypingToggleAvailable: true,
        saveInKeychainDefault: true,
        showTypingDefault: false,
        timeoutSeconds: 90,
        iconSource: .appIcon
    )

    static let confirmOnly = DialogModel(
        mode: .confirm,
        title: L10n.tr("preview.confirm.title", fallback: "Allow Key Operation"),
        message: L10n.tr(
            "preview.confirm.message",
            fallback: "Another app is requesting permission to use your private key for this operation."
        ),
        errorText: nil,
        promptText: nil,
        okText: L10n.allowAction,
        cancelText: L10n.cancelAction,
        notOkText: L10n.tr("preview.action.deny", fallback: "Deny"),
        showsRepeatField: false,
        showsQualityBar: false,
        canUseKeychain: false,
        showTypingToggleAvailable: false,
        saveInKeychainDefault: false,
        showTypingDefault: false,
        timeoutSeconds: nil,
        iconSource: .systemSymbol("hand.raised.fill")
    )
}
