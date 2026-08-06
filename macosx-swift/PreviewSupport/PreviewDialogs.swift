import Foundation

enum PreviewDialogs {
    static let minimalPassphrase = DialogModel(
        mode: .passphrase,
        title: "Unlock Secret Key",
        message: "pinentry needs the passphrase for your GPG key before it can continue.",
        errorText: nil,
        promptText: "Passphrase",
        okText: "Unlock",
        cancelText: "Cancel",
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
        title: "Allow Access to Encrypted Backup",
        message: "The requested operation needs the passphrase that protects your local encryption key. Enter it below to continue with decryption for this one-time operation.",
        errorText: nil,
        promptText: "Passphrase",
        okText: "Continue",
        cancelText: "Cancel",
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
        title: "Passphrase Incorrect",
        message: "The provided passphrase could not unlock your secret key. Try again.",
        errorText: "The passphrase you entered was incorrect.",
        promptText: "Passphrase",
        okText: "Try Again",
        cancelText: "Cancel",
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
        title: "Set New Passphrase",
        message: "Create a new passphrase for the selected key. You will need to enter it twice.",
        errorText: nil,
        promptText: "New Passphrase",
        okText: "Save Passphrase",
        cancelText: "Cancel",
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
        title: "Protect Secret Key",
        message: "Choose a passphrase strong enough to secure your key material.",
        errorText: nil,
        promptText: "Passphrase",
        okText: "Use Passphrase",
        cancelText: "Cancel",
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
        title: "Unlock Signing Key",
        message: "Enter the passphrase for your signing key. You can reveal the text temporarily or remember it in Keychain for later requests.",
        errorText: nil,
        promptText: "Passphrase",
        okText: "Unlock",
        cancelText: "Cancel",
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
        title: "Allow Key Operation",
        message: "Another app is requesting permission to use your private key for this operation.",
        errorText: nil,
        promptText: nil,
        okText: "Allow",
        cancelText: "Cancel",
        notOkText: "Deny",
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
