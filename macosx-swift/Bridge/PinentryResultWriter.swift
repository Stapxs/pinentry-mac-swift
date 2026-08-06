import Foundation

struct PinentryResultWriter {
    func makeResult(from response: DialogResponse, repeatExpected: Bool) -> PinentryBridgeResult {
        PinentryBridgeResult(
            confirmed: response.confirmed,
            canceled: response.canceled,
            declined: response.declined,
            passphrase: response.passphrase,
            repeatOkay: !repeatExpected || response.confirmed,
            saveInKeychain: response.saveInKeychain
        )
    }
}
