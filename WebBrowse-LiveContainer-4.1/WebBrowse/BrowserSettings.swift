import Foundation

final class BrowserSettings {
    static let shared = BrowserSettings()
    private let d = UserDefaults.standard
    private init() {}

    enum Key: String {
        case blockAds, blockPopups, blockRedirects, preventTracking, privateMode, secureDNS
        case httpsOnly, searchEngine, homePage, dnsURL, lowMemoryMode, autoDetectVideos, allowDownloads, suspiciousURLProtection
    }

    func registerDefaults() {
        d.register(defaults: [
            Key.blockAds.rawValue: true,
            Key.blockPopups.rawValue: true,
            Key.blockRedirects.rawValue: true,
            Key.preventTracking.rawValue: true,
            Key.privateMode.rawValue: false,
            Key.secureDNS.rawValue: false,
            Key.httpsOnly.rawValue: false,
            Key.searchEngine.rawValue: "Google",
            Key.homePage.rawValue: "https://www.google.com",
            Key.dnsURL.rawValue: "https://cloudflare-dns.com/dns-query",
            Key.lowMemoryMode.rawValue: false,
            Key.autoDetectVideos.rawValue: true,
            Key.allowDownloads.rawValue: true,
            Key.suspiciousURLProtection.rawValue: true
        ])
    }

    var blockAds: Bool { get { d.bool(forKey: Key.blockAds.rawValue) } set { d.set(newValue, forKey: Key.blockAds.rawValue) } }
    var blockPopups: Bool { get { d.bool(forKey: Key.blockPopups.rawValue) } set { d.set(newValue, forKey: Key.blockPopups.rawValue) } }
    var blockRedirects: Bool { get { d.bool(forKey: Key.blockRedirects.rawValue) } set { d.set(newValue, forKey: Key.blockRedirects.rawValue) } }
    var preventTracking: Bool { get { d.bool(forKey: Key.preventTracking.rawValue) } set { d.set(newValue, forKey: Key.preventTracking.rawValue) } }
    var privateMode: Bool { get { d.bool(forKey: Key.privateMode.rawValue) } set { d.set(newValue, forKey: Key.privateMode.rawValue) } }
    var secureDNS: Bool { get { d.bool(forKey: Key.secureDNS.rawValue) } set { d.set(newValue, forKey: Key.secureDNS.rawValue) } }
    var httpsOnly: Bool { get { d.bool(forKey: Key.httpsOnly.rawValue) } set { d.set(newValue, forKey: Key.httpsOnly.rawValue) } }
    var searchEngine: String { get { d.string(forKey: Key.searchEngine.rawValue) ?? "Google" } set { d.set(newValue, forKey: Key.searchEngine.rawValue) } }
    var homePage: String { get { d.string(forKey: Key.homePage.rawValue) ?? "https://www.google.com" } set { d.set(newValue, forKey: Key.homePage.rawValue) } }
    var dnsURL: String { get { d.string(forKey: Key.dnsURL.rawValue) ?? "https://cloudflare-dns.com/dns-query" } set { d.set(newValue, forKey: Key.dnsURL.rawValue) } }
    var lowMemoryMode: Bool { get { d.bool(forKey: Key.lowMemoryMode.rawValue) } set { d.set(newValue, forKey: Key.lowMemoryMode.rawValue) } }
    var autoDetectVideos: Bool { get { d.bool(forKey: Key.autoDetectVideos.rawValue) } set { d.set(newValue, forKey: Key.autoDetectVideos.rawValue) } }
    var allowDownloads: Bool { get { d.bool(forKey: Key.allowDownloads.rawValue) } set { d.set(newValue, forKey: Key.allowDownloads.rawValue) } }
    var suspiciousURLProtection: Bool { get { d.bool(forKey: Key.suspiciousURLProtection.rawValue) } set { d.set(newValue, forKey: Key.suspiciousURLProtection.rawValue) } }

    /// Automatically enables the memory-saving profile on devices with roughly 4 GB or less RAM.
    /// The manual setting can also force it on for testing or for unusually heavy pages.
    var effectiveLowMemoryMode: Bool {
        lowMemoryMode || ProcessInfo.processInfo.physicalMemory <= 4_000_000_000
    }

    /// Keep the detector cheaper on lower-memory devices while preserving automatic detection.
    var videoDetectionLimit: Int {
        effectiveLowMemoryMode ? 30 : 50
    }
}
