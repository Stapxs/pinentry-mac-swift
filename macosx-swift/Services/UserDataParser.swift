import Foundation

struct PinentryIdentityContext: Equatable {
    let userID: String
    let name: String
    let email: String
    let comment: String
    let keyID: String
}

struct ParsedPinentryUserData: Equatable {
    let resolvedDescription: String?
    let iconPath: String?
}

struct UserDataParser {
    func parse(
        rawUserData: String?,
        fallbackDescription: String?,
        identity: PinentryIdentityContext
    ) -> ParsedPinentryUserData {
        guard let rawUserData, !rawUserData.isEmpty else {
            return ParsedPinentryUserData(
                resolvedDescription: fallbackDescription,
                iconPath: nil
            )
        }

        let description = resolvedDescription(
            from: rawUserData,
            fallbackDescription: fallbackDescription,
            identity: identity
        )
        let iconPath = value(for: "ICON", in: rawUserData)

        return ParsedPinentryUserData(
            resolvedDescription: description,
            iconPath: iconPath
        )
    }

    private func resolvedDescription(
        from rawUserData: String,
        fallbackDescription: String?,
        identity: PinentryIdentityContext
    ) -> String? {
        guard var template = value(for: "DESCRIPTION", in: rawUserData) else {
            return fallbackDescription
        }

        let replacements: [(String, String)] = [
            ("%USERID", identity.userID),
            ("%EMAIL", identity.email),
            ("%COMMENT", identity.comment),
            ("%NAME", identity.name),
            ("%KEYID", identity.keyID)
        ]

        for (token, value) in replacements {
            template = template.replacingOccurrences(of: token, with: value)
        }

        return template.removingPercentEncoding ?? fallbackDescription
    }

    private func value(for key: String, in rawUserData: String) -> String? {
        guard let range = rawUserData.range(of: "\(key)=") else {
            return nil
        }

        let trailing = rawUserData[range.upperBound...]
        if let delimiter = trailing.firstIndex(of: ",") {
            return String(trailing[..<delimiter])
        }

        return String(trailing)
    }
}
