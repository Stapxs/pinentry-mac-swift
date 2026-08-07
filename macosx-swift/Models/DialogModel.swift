import Foundation

struct DialogModel: Equatable {
    enum Mode: Equatable {
        case passphrase
        case confirm
    }

    enum IconSource: Equatable {
        case appIcon
        case ownerProcessID(Int)
        case systemSymbol(String)
        case bundledImage(String)
        case filePath(String)
    }

    let mode: Mode
    let title: String
    let message: String
    let errorText: String?
    let promptText: String?
    let okText: String
    let cancelText: String
    let notOkText: String?
    let showsRepeatField: Bool
    let showsQualityBar: Bool
    let canUseKeychain: Bool
    let showTypingToggleAvailable: Bool
    let saveInKeychainDefault: Bool
    let showTypingDefault: Bool
    let attemptsAutomaticTouchID: Bool
    let automaticTouchIDPrompt: String?
    let automaticTouchIDCacheID: String?
    let automaticTouchIDKeychainLabel: String?
    let timeoutSeconds: Int?
    let iconSource: IconSource
}

struct DialogViewState: Equatable {
    let isExpanded: Bool
    let showsErrorSection: Bool
    let showsOptionsSection: Bool
    let showsRepeatField: Bool
    let showsQualityBar: Bool
}

struct DialogResponse: Equatable {
    let confirmed: Bool
    let canceled: Bool
    let declined: Bool
    let passphrase: String
    let saveInKeychain: Bool
    let pinFromCache: Bool
    let keychainUnusable: Bool
}
