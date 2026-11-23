//
//  WebAddress.swift
//  CoreApps
//

/// A URL taken apart as far as the browser needs: its scheme, its host
/// and port, and the rest. No Foundation, as the browser is a guest.
///
/// It reads what an engine reports, which is already a URL; what someone
/// types goes through `AddressInput` first.
public struct WebAddress: Equatable, Sendable {

    /// The scheme, lowercased: `https`, `about`.
    public var scheme: String

    /// The host, lowercased, without brackets for IPv6. Empty for a URL
    /// with no authority, such as `about:blank` or `mailto:`.
    public var host: String

    public var port: Int?

    /// Everything after the authority: the path, query and fragment. For a
    /// URL with no authority, everything after the scheme's colon.
    public var rest: String

    public init?(_ url: String) {
        guard let scheme = Self.scheme(of: url) else { return nil }
        self.scheme = scheme
        let afterColon = Text.dropping(scheme.utf8.count + 1, from: url)
        guard afterColon.hasPrefix("//") else {
            host = ""
            port = nil
            rest = afterColon
            return
        }
        let authorityAndRest = Array(afterColon.utf8.dropFirst(2))
        let end = authorityAndRest.firstIndex { $0 == UInt8(ascii: "/") || $0 == UInt8(ascii: "?") || $0 == UInt8(ascii: "#") }
            ?? authorityAndRest.count
        var authority = Array(authorityAndRest[..<end])
        rest = String(decoding: authorityAndRest[end...], as: UTF8.self)
        // Whoever's signing in isn't part of where the page is.
        if let at = authority.lastIndex(of: UInt8(ascii: "@")) {
            authority = Array(authority[(at + 1)...])
        }
        var hostBytes = authority
        var port: Int?
        if authority.first == UInt8(ascii: "["), let close = authority.firstIndex(of: UInt8(ascii: "]")) {
            hostBytes = Array(authority[1..<close])
            let after = authority[(close + 1)...]
            if after.first == UInt8(ascii: ":") {
                port = Int(String(decoding: after.dropFirst(), as: UTF8.self))
            }
        } else if let colon = authority.lastIndex(of: UInt8(ascii: ":")) {
            hostBytes = Array(authority[..<colon])
            port = Int(String(decoding: authority[(colon + 1)...], as: UTF8.self))
        }
        host = Text.asciiLowercased(String(decoding: hostBytes, as: UTF8.self))
        self.port = port
    }

    /// Whether the page came over TLS.
    public var isSecure: Bool {
        scheme == "https" || scheme == "wss"
    }

    /// Whether it's a page on the web, rather than a file, a blank page or
    /// a page made from data.
    public var isWeb: Bool {
        scheme == "http" || scheme == "https"
    }

    /// The host as people know it: without `www.`.
    public var displayHost: String {
        host.hasPrefix("www.") ? Text.dropping(4, from: host) : host
    }

    /// What the address bar shows while it isn't being edited: the host
    /// of a web page, and the whole URL of anything else.
    public static func summary(of url: String) -> String {
        guard let address = WebAddress(url), address.isWeb, !address.host.isEmpty else {
            return url
        }
        return address.displayHost
    }

    /// A URL's scheme, lowercased: a letter, then letters, digits, `+`,
    /// `-` and `.`, before the first colon.
    public static func scheme(of text: String) -> String? {
        let bytes = Array(text.utf8)
        guard let colon = bytes.firstIndex(of: UInt8(ascii: ":")), colon > 0, Text.isASCIILetter(bytes[0]) else {
            return nil
        }
        for byte in bytes[..<colon] {
            guard Text.isASCIILetter(byte) || Text.isASCIIDigit(byte)
                || byte == UInt8(ascii: "+") || byte == UInt8(ascii: "-") || byte == UInt8(ascii: ".") else {
                return nil
            }
        }
        return Text.asciiLowercased(String(decoding: bytes[..<colon], as: UTF8.self))
    }
}
