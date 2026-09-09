import Foundation

struct NavigationSecurity {
    enum Decision {
        case allow
        case block(String)
        case warn(String)
    }

    // This is intentionally a local heuristic layer, not a replacement for a
    // continuously updated reputation service. It prevents common dangerous URL
    // tricks without pretending to know whether every Internet host is safe.
    static func inspect(_ url: URL) -> Decision {
        guard url.absoluteString.count <= 8192 else { return .block("WebBrowse blocked an unusually long website address.") }
        guard let scheme = url.scheme?.lowercased() else { return .block("The URL has no valid scheme.") }
        guard scheme == "http" || scheme == "https" || scheme == "about" else {
            return .block("WebBrowse blocked an unsupported URL scheme.")
        }
        guard let host = url.host?.lowercased(), !host.isEmpty || scheme == "about" else {
            return .block("The URL does not contain a valid website host.")
        }
        if scheme == "about" {
            guard url.absoluteString.lowercased() == "about:blank" else {
                return .block("WebBrowse only allows the standard about:blank page.")
            }
            return .allow
        }

        // Never silently visit a URL that embeds credentials. These are frequently
        // used by phishing links and are almost never needed for normal browsing.
        if url.user != nil || url.password != nil {
            return .block("WebBrowse blocked a URL containing embedded login credentials.")
        }

        // Reject control characters and malformed whitespace before WebKit ever sees
        // the navigation. These are not useful in normal website URLs and can make
        // security checks disagree with the actual URL interpreted by another parser.
        if url.absoluteString.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7f }) ||
           url.absoluteString.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
            return .block("WebBrowse blocked a malformed website address.")
        }

        // Punycode is legitimate, but it can also be used for look-alike domains.
        // Warn rather than block so internationalized websites still work.
        if host.split(separator: ".").contains(where: { $0.hasPrefix("xn--") }) {
            return .warn("This website uses an internationalized domain name. Check the domain carefully before entering sensitive information.")
        }

        // Raw IP addresses are valid, but are more commonly used for temporary hosts,
        // phishing pages, and insecure admin panels than ordinary public websites.
        // Warn instead of blocking to avoid breaking legitimate self-hosted services.
        if isIPv4Literal(host) || host.contains(":") {
            return .warn("This website is using a raw IP address instead of a normal domain name. Check it before entering sensitive information.")
        }

        if isLocalOrPrivateHost(host) {
            return .warn("This address points to a local or private network host. Only continue if you recognize the device or network service.")
        }

        return .allow
    }

    private static func isLocalOrPrivateHost(_ host: String) -> Bool {
        if host == "localhost" || host.hasSuffix(".localhost") || host == "local" || host.hasSuffix(".local") { return true }
        let parts = host.split(separator: ".")
        guard parts.count == 4, let a = Int(parts[0]), let b = Int(parts[1]) else { return false }
        if a == 10 || a == 127 || (a == 169 && b == 254) || (a == 192 && b == 168) { return true }
        return a == 172 && (16...31).contains(b)
    }

    private static func isIPv4Literal(_ host: String) -> Bool {
        let parts = host.split(separator: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let value = Int(part), part == Substring(String(value)) else { return false }
            return (0...255).contains(value)
        }
    }
}
