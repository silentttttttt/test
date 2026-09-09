import WebKit

final class ContentBlocker {
    static let shared = ContentBlocker()
    private init() {}

    private let adRules = """
    [
      {"trigger":{"url-filter":".*(doubleclick\\.net|googlesyndication\\.com|googleadservices\\.com|adnxs\\.(com|net)|taboola\\.com|outbrain\\.com|scorecardresearch\\.com|popads\\.net|propellerads\\.com|zedo\\.com|rubiconproject\\.com|pubmatic\\.com|openx\\.net|criteo\\.com|adsrvr\\.org|adform\\.net|casalemedia\\.com|smartadserver\\.com|quantserve\\.com|moatads\\.com|amazon-adsystem\\.com|33across\\.com|bidvertiser\\.com|revcontent\\.com|mgid\\.com|adroll\\.com|bluekai\\.com|mathtag\\.com|demdex\\.net|krxd\\.net|everesttech\\.net|adsafeprotected\\.com|doubleverify\\.com|adsymptotic\\.com|lijit\\.com|sovrn\\.com|yieldmo\\.com|sharethrough\\.com|teads\\.tv|e-planning\\.net|media\\.net|adskeeper\\.co|trafficjunky\\.net|exoclick\\.com).*"},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*(popunder|popunderads|popup|interstitial|clickunder|push\\.pushcrew|onclickads).*","resource-type":["script"]},"action":{"type":"block"}}
    ]
    """

    private let trackingRules = """
    [
      {"trigger":{"url-filter":".*(facebook\\.net|facebook\\.com/tr|connect\\.facebook\\.net|analytics\\.twitter\\.com|bat\\.bing\\.com).*","resource-type":["image","script","style-sheet","font","fetch"]},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*(google-analytics\\.com|googletagmanager\\.com|hotjar\\.com|clarity\\.ms|mixpanel\\.com|segment\\.(io|com)|amplitude\\.com|fullstory\\.com|mouseflow\\.com|heap\\.io|matomo\\.cloud|plausible\\.io|snowplow|newrelic\\.com|nr-data\\.net|sentry\\.io).*"},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*(pixel|beacon|telemetry|tracking)\\.(gif|png|jpg|jpeg|svg)([?#].*)?$","resource-type":["image"]},"action":{"type":"block"}}
    ]
    """

    func install(on webView: WKWebView, blockAds: Bool, preventTracking: Bool, completion: ((Bool) -> Void)? = nil) {
        let store = WKContentRuleListStore.default()
        var rules: [[String: Any]] = []
        if blockAds { rules.append(contentsOf: decode(adRules)) }
        if preventTracking { rules.append(contentsOf: decode(trackingRules)) }

        guard let encoded = encode(rules) else {
            completion?(false)
            return
        }

        // Do not clear an already-installed blocker until the replacement has
        // successfully compiled. A malformed rule must never silently turn
        // protection off for the page being rebuilt.
        let identifier = "WebBrowse.PrivacyRules.v5-\(blockAds ? "A" : "")\(preventTracking ? "T" : "")"
        if rules.isEmpty {
            removeOwnedLists(from: webView, store: store, completion: completion)
            return
        }

        // Reuse a previously compiled list when possible. Compilation is relatively
        // expensive, and settings rebuilds should not repeatedly compile identical JSON.
        store.lookUpContentRuleList(forIdentifier: identifier) { existing, _ in
            if let existing {
                self.apply(existing, identifier: identifier, to: webView, store: store, completion: completion)
                return
            }
            store.compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: encoded) { list, _ in
                DispatchQueue.main.async {
                    guard let list else {
                        // Keep whatever rule list is currently installed rather than
                        // failing open. The caller can rebuild again after settings change.
                        completion?(false)
                        return
                    }
                    self.apply(list, identifier: identifier, to: webView, store: store, completion: completion)
                }
            }
        }
    }

    private func apply(_ list: WKContentRuleList, identifier: String, to webView: WKWebView, store: WKContentRuleListStore, completion: ((Bool) -> Void)?) {
        removeInstalledOwnedLists(from: webView, excluding: identifier) {
            DispatchQueue.main.async {
                webView.configuration.userContentController.add(list)
                completion?(true)
            }
        }
        // Old WebBrowse rule lists live in WKContentRuleListStore's persistent cache.
        // Remove stale versions so repeated setting changes don't accumulate compiled
        // lists. Never touch rule lists owned by other apps/extensions.
        store.getAvailableContentRuleListIdentifiers { identifiers in
            for old in identifiers ?? [] where old.hasPrefix("WebBrowse.PrivacyRules.") && old != identifier {
                store.removeContentRuleList(forIdentifier: old) { _ in }
            }
        }
    }

    private func removeInstalledOwnedLists(from webView: WKWebView, excluding identifier: String? = nil, completion: (() -> Void)? = nil) {
        let store = WKContentRuleListStore.default()
        let knownIDs = [
            "WebBrowse.PrivacyRules.v5-A",
            "WebBrowse.PrivacyRules.v5-T",
            "WebBrowse.PrivacyRules.v5-AT"
        ]
        let group = DispatchGroup()
        for id in knownIDs where id != identifier {
            group.enter()
            store.lookUpContentRuleList(forIdentifier: id) { list, _ in
                if let list {
                    DispatchQueue.main.async { webView.configuration.userContentController.removeContentRuleList(list); group.leave() }
                } else {
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) { completion?() }
    }

    private func removeOwnedLists(from webView: WKWebView, store: WKContentRuleListStore, completion: ((Bool) -> Void)?) {
        removeInstalledOwnedLists(from: webView) {
            store.getAvailableContentRuleListIdentifiers { identifiers in
                for id in identifiers ?? [] where id.hasPrefix("WebBrowse.PrivacyRules.") {
                    store.removeContentRuleList(forIdentifier: id) { _ in }
                }
                DispatchQueue.main.async { completion?(true) }
            }
        }
    }

    private func decode(_ string: String) -> [[String: Any]] {
        guard let data = string.data(using: .utf8),
              let value = try? JSONSerialization.jsonObject(with: data),
              let rules = value as? [[String: Any]] else { return [] }
        return rules
    }

    private func encode(_ rules: [[String: Any]]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: rules, options: []),
              let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }
}
