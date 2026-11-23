//
//  AddressInput.swift
//  CoreApps
//

/// What the address bar does with what's typed into it: go to it, if it's
/// an address, or search for it.
public enum AddressInput {

    /// Schemes typed in full that are gone to as they are.
    static let schemes: Set<String> = ["http", "https", "file", "about", "data", "view-source"]

    /// The URL to load for `text`, or `nil` for nothing but whitespace.
    ///
    /// - A URL with a scheme the browser opens is gone to as it is.
    /// - Something with no spaces that looks like a host, perhaps with a
    ///   port and a path, is gone to over HTTPS: `swift.org/blog`. A local
    ///   host or an IP address is gone to over HTTP, as such servers rarely
    ///   have certificates: `localhost:8080`, `192.168.1.1`.
    /// - Anything else is searched for.
    public static func destination(for text: String, engine: SearchEngine = .standard) -> String? {
        let text = Text.trimmed(text)
        guard !text.isEmpty else { return nil }
        if let scheme = WebAddress.scheme(of: text), schemes.contains(scheme) {
            return text
        }
        if !text.utf8.contains(where: Text.isWhitespace), let host = host(of: text) {
            return (host.isLocal ? "http://" : "https://") + text
        }
        return engine.searchURL(for: text)
    }

    /// What kind of host `text` starts with, if it starts with one.
    static func host(of text: String) -> HostKind? {
        let bytes = Array(text.utf8)
        let end = bytes.firstIndex { $0 == UInt8(ascii: "/") || $0 == UInt8(ascii: "?") || $0 == UInt8(ascii: "#") } ?? bytes.count
        var authority = Array(bytes[..<end])
        // `someone@example.com` is more likely an email address to search
        // for than a sign-in.
        guard !authority.isEmpty, !authority.contains(UInt8(ascii: "@")) else { return nil }
        if authority.first == UInt8(ascii: "[") {
            guard let close = authority.firstIndex(of: UInt8(ascii: "]")), close > 1,
                  isPort(authority[(close + 1)...]) else { return nil }
            return .local
        }
        if let colon = authority.lastIndex(of: UInt8(ascii: ":")) {
            guard isPort(authority[colon...]) else { return nil }
            authority = Array(authority[..<colon])
        }
        let host = Text.asciiLowercased(authority)
        if host.elementsEqual("localhost".utf8) || Text.hasSuffix(host, Array(".localhost".utf8)) {
            return .local
        }
        let labels = host.split(separator: UInt8(ascii: "."), omittingEmptySubsequences: false).map { Array($0) }
        if labels.count == 4, labels.allSatisfy(isOctet) {
            return .local
        }
        guard labels.count >= 2, labels.allSatisfy(isLabel), let top = labels.last else { return nil }
        // A top-level domain is letters (or an internationalized one).
        guard top.count >= 2, top.allSatisfy({ Text.isASCIILetter($0) || $0 >= 0x80 }) else { return nil }
        return Text.hasSuffix(host, Array(".local".utf8)) ? .local : .internet
    }

    enum HostKind: Equatable {
        /// On this machine or its network.
        case local
        case internet

        var isLocal: Bool { self == .local }
    }

    /// `:` and one to five digits, or nothing.
    private static func isPort(_ bytes: ArraySlice<UInt8>) -> Bool {
        guard let first = bytes.first else { return true }
        let digits = bytes.dropFirst()
        return first == UInt8(ascii: ":") && (1...5).contains(digits.count) && digits.allSatisfy(Text.isASCIIDigit)
    }

    private static func isOctet(_ label: [UInt8]) -> Bool {
        guard (1...3).contains(label.count), label.allSatisfy(Text.isASCIIDigit),
              let value = Int(String(decoding: label, as: UTF8.self)) else { return false }
        return value <= 255
    }

    /// A DNS label: letters, digits and hyphens, not at either end, or
    /// non-ASCII for an internationalized name.
    private static func isLabel(_ label: [UInt8]) -> Bool {
        guard let first = label.first, let last = label.last, label.count <= 63,
              first != UInt8(ascii: "-"), last != UInt8(ascii: "-") else { return false }
        return label.allSatisfy { Text.isASCIILetter($0) || Text.isASCIIDigit($0) || $0 == UInt8(ascii: "-") || $0 >= 0x80 }
    }
}
