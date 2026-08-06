import Foundation

struct PinentryRequestPayload: Equatable {
    let requiresPassphrase: Bool
    let title: String?
    let message: String?
    let errorText: String?
    let promptText: String?
    let okText: String?
    let cancelText: String?
    let notOkText: String?
    let repeatPassphrase: Bool
    let qualityBarRequested: Bool
    let timeoutSeconds: Int?
    let keyInfo: String?
    let prefersSaveInKeychain: Bool
    let prefersShowTyping: Bool
    let userData: String?
    let identity: PinentryIdentityContext
}

struct PinentryBridgeResult: Equatable {
    let confirmed: Bool
    let canceled: Bool
    let declined: Bool
    let passphrase: String
    let repeatOkay: Bool
    let saveInKeychain: Bool
}
