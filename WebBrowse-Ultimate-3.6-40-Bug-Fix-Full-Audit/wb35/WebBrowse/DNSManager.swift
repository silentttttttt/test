import Foundation
import NetworkExtension

final class DNSManager {
    static let shared = DNSManager()
    private init() {}

    func load(completion: @escaping (Error?) -> Void) {
        NEDNSSettingsManager.shared().loadFromPreferences(completionHandler: completion)
    }

    func enableDoH(urlString: String, completion: @escaping (Error?) -> Void) {
        guard urlString.count <= 512, let url = URL(string: urlString), url.scheme?.lowercased() == "https", url.host != nil else {
            completion(NSError(domain: "WebBrowseDNS", code: 1, userInfo: [NSLocalizedDescriptionKey: "DNS-over-HTTPS URL must use HTTPS."]))
            return
        }
        let manager = NEDNSSettingsManager.shared()
        manager.loadFromPreferences { error in
            if let error { DispatchQueue.main.async { completion(error) }; return }
            let settings = NEDNSOverHTTPSSettings(servers: [])
            settings.serverURL = url
            settings.matchDomains = [""]
            settings.matchDomainsNoSearch = true
            manager.localizedDescription = "WebBrowse Secure DNS"
            manager.dnsSettings = settings
            manager.saveToPreferences { error in DispatchQueue.main.async { completion(error) } }
        }
    }

    func disable(completion: @escaping (Error?) -> Void) {
        NEDNSSettingsManager.shared().removeFromPreferences { error in DispatchQueue.main.async { completion(error) } }
    }

    func isEnabled(completion: @escaping (Bool) -> Void) {
        let manager = NEDNSSettingsManager.shared()
        manager.loadFromPreferences { _ in DispatchQueue.main.async { completion(manager.isEnabled) } }
    }
}
