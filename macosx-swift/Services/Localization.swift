import Foundation

enum AppRuntimeBundle {
    static let bundle: Bundle = resolveBundle()

    private static func resolveBundle() -> Bundle {
        for executableURL in executableCandidates {
            if let bundle = containingAppBundle(for: executableURL) {
                return bundle
            }
        }

        return .main
    }

    private static var executableCandidates: [URL] {
        var urls: [URL] = []

        if let executableURL = Bundle.main.executableURL {
            urls.append(executableURL)
        }

        if let argument = CommandLine.arguments.first, !argument.isEmpty {
            let currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            urls.append(URL(fileURLWithPath: argument, relativeTo: currentDirectoryURL).standardizedFileURL)
        }

        return urls
    }

    private static func containingAppBundle(for executableURL: URL) -> Bundle? {
        let candidateURLs = [
            executableURL.standardizedFileURL,
            executableURL.resolvingSymlinksInPath().standardizedFileURL
        ]

        for candidateURL in candidateURLs {
            var currentURL = candidateURL.deletingLastPathComponent()

            while currentURL.path != "/" {
                if currentURL.pathExtension == "app", let bundle = Bundle(url: currentURL) {
                    return bundle
                }

                currentURL.deleteLastPathComponent()
            }
        }

        return nil
    }
}

enum L10n {
    enum TextRole {
        case title
        case message
        case prompt
        case ok
        case cancel
        case notOk
    }

    static func tr(_ key: String, fallback: String) -> String {
        let localized = localizedResourceBundle.localizedString(forKey: key, value: nil, table: nil)
        if localized != key {
            return localized
        }

        return AppRuntimeBundle.bundle.localizedString(forKey: key, value: fallback, table: nil)
    }

    static func format(_ key: String, fallback: String, _ arguments: CVarArg...) -> String {
        String(
            format: tr(key, fallback: fallback),
            locale: Locale.current,
            arguments: arguments
        )
    }

    static var defaultDialogTitle: String {
        tr("dialog.title.default", fallback: "Pinentry Mac")
    }

    static var unlockAction: String {
        tr("dialog.action.unlock", fallback: "OK")
    }

    static var allowAction: String {
        tr("dialog.action.allow", fallback: "Allow")
    }

    static var cancelAction: String {
        tr("dialog.action.cancel", fallback: "Cancel")
    }

    static var usePasswordAction: String {
        tr("dialog.action.use_password", fallback: "Use Password...")
    }

    static var defaultPassphrasePrompt: String {
        tr("dialog.prompt.passphrase", fallback: "Passphrase")
    }

    static var confirmPromptPrefix: String {
        tr("dialog.prompt.confirm_prefix", fallback: "Confirm")
    }

    static func confirmPrompt(_ prompt: String) -> String {
        format("dialog.prompt.confirm_format", fallback: "Confirm %@", prompt)
    }

    static var mismatchHint: String {
        tr("dialog.repeat.mismatch", fallback: "The two passphrases must match.")
    }

    static func timeoutHint(secondsRemaining: Int) -> String {
        format(
            "dialog.timeout.remaining",
            fallback: "This request times out in %ds.",
            secondsRemaining
        )
    }

    static var qualityTitle: String {
        tr("dialog.quality.title", fallback: "Passphrase Strength")
    }

    static func qualityLabel(for grade: PassphraseQualityAssessment.Grade) -> String {
        switch grade {
        case .weak:
            return tr("dialog.quality.weak", fallback: "Weak")
        case .fair:
            return tr("dialog.quality.fair", fallback: "Fair")
        case .good:
            return tr("dialog.quality.good", fallback: "Good")
        case .strong:
            return tr("dialog.quality.strong", fallback: "Strong")
        }
    }

    static var showTyping: String {
        tr("dialog.option.show_typing", fallback: "Show typing")
    }

    static var saveInKeychain: String {
        tr("dialog.option.save_in_keychain", fallback: "Save in Keychain")
    }

    static var emptyStateTitle: String {
        tr("dialog.empty.title", fallback: "No active pinentry request")
    }

    static var emptyStateMessage: String {
        tr(
            "dialog.empty.message",
            fallback: "The presentation coordinator will attach the next dialog here."
        )
    }

    static func localizeKnownPinentryText(_ text: String, role: TextRole) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return text
        }

        if let localized = localizedMatch(for: trimmed, role: role) {
            return text.replacingOccurrences(of: trimmed, with: localized)
        }

        if trimmed.contains("\n") {
            let localizedLines = trimmed
                .components(separatedBy: .newlines)
                .map { line in
                    localizedMatch(for: line, role: role) ?? line
                }
                .joined(separator: "\n")

            if localizedLines != trimmed {
                return text.replacingOccurrences(of: trimmed, with: localizedLines)
            }
        }

        return text
    }

    static func debugLocalizationContext() -> String {
        let appBundle = AppRuntimeBundle.bundle
        let supportedLocalizations = Array(Set(appBundle.localizations)).sorted()
        let languagePreferences = UserDefaults.standard.stringArray(forKey: "AppleLanguages") ?? Locale.preferredLanguages
        let preferredLocalizations = Bundle.preferredLocalizations(
            from: supportedLocalizations.filter { $0 != "Base" },
            forPreferences: languagePreferences
        )
        let selectedLocalization = preferredLocalizations.first ?? appBundle.developmentLocalization ?? "unknown"
        let selectedBundlePath = appBundle.path(forResource: selectedLocalization, ofType: "lproj") ?? "<main>"

        return """
        languages=\(languagePreferences)
        mainBundle=\(Bundle.main.bundleURL.path)
        appBundle=\(appBundle.bundleURL.path)
        supported=\(supportedLocalizations)
        preferred=\(preferredLocalizations)
        development=\(appBundle.developmentLocalization ?? "nil")
        selected=\(selectedLocalization)
        bundle=\(selectedBundlePath)
        showTyping=\(tr("dialog.option.show_typing", fallback: "Show typing"))
        timeout=\(tr("dialog.timeout.remaining", fallback: "This request times out in %ds."))
        unlock=\(tr("dialog.action.unlock", fallback: "OK"))
        cancel=\(tr("dialog.action.cancel", fallback: "Cancel"))
        """
    }

    private static let knownTitleTranslations = makeLookupTable([
        "Unlock Secret Key": tr("known.title.unlock_secret_key", fallback: "解锁私钥"),
        "Allow Key Operation": tr("known.title.allow_key_operation", fallback: "允许密钥操作"),
        "Set New Passphrase": tr("known.title.set_new_passphrase", fallback: "设置新口令"),
        "Protect Secret Key": tr("known.title.protect_secret_key", fallback: "保护私钥"),
        "Passphrase Incorrect": tr("known.title.passphrase_incorrect", fallback: "口令不正确"),
        "Unlock Signing Key": tr("known.title.unlock_signing_key", fallback: "解锁签名密钥"),
        "Passphrase Required": tr("known.title.passphrase_required", fallback: "需要口令"),
        "Confirm Key Operation": tr("known.title.confirm_key_operation", fallback: "确认密钥操作")
    ])

    private static let knownMessageTranslations = makeLookupTable([
        "Enter the passphrase for your signing key.": tr(
            "known.message.enter_signing_key_passphrase",
            fallback: "请输入签名密钥的口令。"
        ),
        "Enter the passphrase for your GPG key.": tr(
            "known.message.enter_gpg_key_passphrase",
            fallback: "请输入你的 GPG 密钥口令。"
        ),
        "Another app is requesting permission to use your private key.": tr(
            "known.message.private_key_permission_short",
            fallback: "另一个应用正在请求使用你的私钥。"
        ),
        "Another app is requesting permission to use your private key for this operation.": tr(
            "known.message.private_key_permission",
            fallback: "另一个应用正请求使用你的私钥来执行此操作。"
        ),
        "Create a new passphrase for the selected key.": tr(
            "known.message.create_new_passphrase_short",
            fallback: "请为所选密钥创建一个新口令。"
        ),
        "Create a new passphrase for the selected key. You will need to enter it twice.": tr(
            "known.message.create_new_passphrase",
            fallback: "请为所选密钥创建一个新口令。你需要输入两次。"
        ),
        "Choose a passphrase strong enough to secure your key material.": tr(
            "known.message.choose_strong_passphrase",
            fallback: "请选择一个足够强的口令来保护你的密钥材料。"
        ),
        "The provided passphrase could not unlock your secret key.": tr(
            "known.message.passphrase_could_not_unlock_short",
            fallback: "提供的口令无法解锁你的私钥。"
        ),
        "The provided passphrase could not unlock your secret key. Try again.": tr(
            "known.message.passphrase_could_not_unlock",
            fallback: "提供的口令无法解锁你的私钥，请重试。"
        ),
        "pinentry needs the passphrase for your GPG key before it can continue.": tr(
            "known.message.pinentry_needs_gpg_passphrase",
            fallback: "Pinentry 需要你的 GPG 密钥口令才能继续。"
        ),
        "Please enter the passphrase to unlock the OpenPGP secret key:": tr(
            "known.message.unlock_openpgp_secret_key",
            fallback: "请输入口令以解锁 OpenPGP 私钥："
        )
    ])

    private static let knownPromptTranslations = makeLookupTable([
        "Passphrase": tr("known.prompt.passphrase", fallback: "口令"),
        "New Passphrase": tr("known.prompt.new_passphrase", fallback: "新口令"),
        "Confirm Passphrase": tr("known.prompt.confirm_passphrase", fallback: "再次输入口令"),
        "Repeat Passphrase": tr("known.prompt.repeat_passphrase", fallback: "再次输入口令"),
        "PIN": tr("known.prompt.pin", fallback: "PIN 码"),
        "Confirm PIN": tr("known.prompt.confirm_pin", fallback: "再次输入 PIN 码"),
        "Repeat PIN": tr("known.prompt.repeat_pin", fallback: "再次输入 PIN 码")
    ])

    private static let knownOkTranslations = makeLookupTable([
        "Unlock": tr("known.action.unlock", fallback: "解锁"),
        "Allow": tr("known.action.allow", fallback: "允许"),
        "Continue": tr("known.action.continue", fallback: "继续"),
        "Try Again": tr("known.action.try_again", fallback: "重试"),
        "Save Passphrase": tr("known.action.save_passphrase", fallback: "保存口令"),
        "Use Passphrase": tr("known.action.use_passphrase", fallback: "使用该口令"),
        "OK": tr("known.action.ok", fallback: "确定"),
        "Confirm": tr("known.action.confirm", fallback: "确认"),
        "Retry": tr("known.action.retry", fallback: "重试"),
        "Save": tr("known.action.save", fallback: "保存"),
        "Proceed": tr("known.action.proceed", fallback: "继续")
    ])

    private static let knownCancelTranslations = makeLookupTable([
        "Cancel": tr("known.action.cancel", fallback: "取消")
    ])

    private static let knownNotOkTranslations = makeLookupTable([
        "Deny": tr("known.action.deny", fallback: "拒绝")
    ])

    private static func localizedMatch(for text: String, role: TextRole) -> String? {
        let lookupTable: [String: String]
        switch role {
        case .title:
            lookupTable = knownTitleTranslations
        case .message:
            lookupTable = knownMessageTranslations
        case .prompt:
            lookupTable = knownPromptTranslations
        case .ok:
            lookupTable = knownOkTranslations
        case .cancel:
            lookupTable = knownCancelTranslations
        case .notOk:
            lookupTable = knownNotOkTranslations
        }

        let normalizedKey = canonicalLookupKey(text)
        if let localized = lookupTable[normalizedKey] {
            return localized
        }

        let punctuationStrippedKey = strippedTrailingPunctuationLookupKey(text)
        if punctuationStrippedKey != normalizedKey {
            return lookupTable[punctuationStrippedKey]
        }

        return nil
    }

    private static func makeLookupTable(_ entries: [String: String]) -> [String: String] {
        Dictionary(
            uniqueKeysWithValues: entries.map { entry in
                (canonicalLookupKey(entry.key), entry.value)
            }
        )
    }

    private static func canonicalLookupKey(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "&", with: "")
            .replacingOccurrences(of: "_", with: "")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
    }

    private static func strippedTrailingPunctuationLookupKey(_ text: String) -> String {
        let stripped = text.trimmingCharacters(
            in: CharacterSet(charactersIn: ".:!?\u{2026}\u{FF1A} ").union(.whitespacesAndNewlines)
        )
        return canonicalLookupKey(stripped)
    }

    private static var localizedResourceBundle: Bundle {
        let appBundle = AppRuntimeBundle.bundle
        let supportedLocalizations = Array(Set(appBundle.localizations)).filter { $0 != "Base" }
        let languagePreferences = UserDefaults.standard.stringArray(forKey: "AppleLanguages") ?? Locale.preferredLanguages
        let preferredLocalizations = Bundle.preferredLocalizations(
            from: supportedLocalizations,
            forPreferences: languagePreferences
        )

        for localization in preferredLocalizations {
            if let bundle = localizedBundle(named: localization) {
                return bundle
            }
        }

        if let developmentLocalization = appBundle.developmentLocalization,
           let bundle = localizedBundle(named: developmentLocalization) {
            return bundle
        }

        return appBundle
    }

    private static func localizedBundle(named localization: String) -> Bundle? {
        guard let bundlePath = AppRuntimeBundle.bundle.path(forResource: localization, ofType: "lproj") else {
            return nil
        }

        return Bundle(path: bundlePath)
    }

}
