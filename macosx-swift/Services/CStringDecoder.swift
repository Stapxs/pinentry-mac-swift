import Foundation

struct CStringDecoder {
    func decode(_ cString: UnsafePointer<CChar>?) -> String {
        guard let cString else {
            return ""
        }

        return decode(bytes: Array(Data(bytes: cString, count: strlen(cString))))
    }

    func decode(bytes: [UInt8]) -> String {
        guard !bytes.isEmpty else {
            return ""
        }

        if let decoded = String(bytes: bytes, encoding: .utf8) {
            return decoded
        }

        let sanitized = sanitizeUTF8(bytes)
        if let decoded = String(bytes: sanitized, encoding: .utf8), !decoded.isEmpty {
            return decoded
        }

        for encoding in [String.Encoding.isoLatin1, .isoLatin2, .ascii] {
            if let decoded = String(bytes: bytes, encoding: encoding), !decoded.isEmpty {
                return decoded
            }
        }

        return ""
    }

    private func sanitizeUTF8(_ bytes: [UInt8]) -> [UInt8] {
        var output: [UInt8] = []
        var pendingMultiByteCount = 0
        var startIndex: Int?

        for (index, byte) in bytes.enumerated() {
            if pendingMultiByteCount > 0, (byte & 0xC0) == 0x80 {
                pendingMultiByteCount -= 1
                if pendingMultiByteCount == 0, let startIndex {
                    output.append(contentsOf: bytes[startIndex...index])
                }
            } else if (byte & 0x80) == 0 {
                output.append(byte)
                pendingMultiByteCount = 0
                startIndex = nil
            } else if (byte & 0xC0) == 0xC0 {
                if pendingMultiByteCount > 0 {
                    output.append(UInt8(ascii: "?"))
                }

                switch byte {
                case 0xC2...0xDF:
                    pendingMultiByteCount = 1
                    startIndex = index
                case 0xE0...0xEF:
                    pendingMultiByteCount = 2
                    startIndex = index
                case 0xF0...0xF4:
                    pendingMultiByteCount = 3
                    startIndex = index
                default:
                    output.append(UInt8(ascii: "?"))
                    pendingMultiByteCount = 0
                    startIndex = nil
                }
            } else {
                output.append(UInt8(ascii: "?"))
                pendingMultiByteCount = 0
                startIndex = nil
            }
        }

        return output
    }
}
