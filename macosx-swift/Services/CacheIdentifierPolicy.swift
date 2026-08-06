import Foundation

struct KeyDescriptor: Equatable {
    enum CacheMode: Equatable {
        case user
        case ssh
        case normal
        case unknown(Character)
    }

    let cacheMode: CacheMode
    let cacheIdentifier: String?
}

struct CacheIdentifierPolicy {
    func descriptor(for keyInfo: String?) -> KeyDescriptor {
        guard let keyInfo, keyInfo.count > 2, keyInfo[keyInfo.index(after: keyInfo.startIndex)] == "/" else {
            return KeyDescriptor(cacheMode: .unknown("?"), cacheIdentifier: nil)
        }

        let first = keyInfo[keyInfo.startIndex]
        let mode: KeyDescriptor.CacheMode
        switch first {
        case "u":
            mode = .user
        case "s":
            mode = .ssh
        case "n":
            mode = .normal
        default:
            mode = .unknown(first)
        }

        return KeyDescriptor(
            cacheMode: mode,
            cacheIdentifier: String(keyInfo.dropFirst(2))
        )
    }

    func canPersistPassphrase(for keyInfo: String?) -> Bool {
        let descriptor = descriptor(for: keyInfo)
        guard let cacheIdentifier = descriptor.cacheIdentifier, !cacheIdentifier.isEmpty else {
            return false
        }

        return descriptor.cacheMode != .user
    }
}
