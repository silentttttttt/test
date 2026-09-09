import Foundation
import WebKit

final class VideoURLResolver: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var completion: ((URL?) -> Void)?
    private var timeoutWork: DispatchWorkItem?
    private var redirectCount = 0
    private let targetURL: URL
    private let dataStore: WKWebsiteDataStore

    init(url: URL, dataStore: WKWebsiteDataStore) {
        self.targetURL = url
        self.dataStore = dataStore
        super.init()
    }

    func resolve(completion: @escaping (URL?) -> Void) {
        switch NavigationSecurity.inspect(targetURL) {
        case .allow:
            break
        case .block, .warn:
            completion(nil)
            return
        }
        timeoutWork?.cancel()
        self.completion = completion
        redirectCount = 0
        let config = WKWebViewConfiguration()
        config.processPool = BrowserProcessPool.shared.pool
        config.websiteDataStore = dataStore
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        webView = wv
        wv.load(URLRequest(url: targetURL, timeoutInterval: 20))

        let timeout = DispatchWorkItem { [weak self] in self?.finish(nil) }
        timeoutWork = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeout)
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        redirectCount += 1
        if redirectCount > 8 { finish(nil) }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        switch NavigationSecurity.inspect(url) {
        case .allow, .warn: decisionHandler(.allow)
        case .block: decisionHandler(.cancel); finish(nil)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let script = """
        (() => {
          const list = Array.from(document.querySelectorAll('video, audio, source')).map(el => ({
            src: el.currentSrc || el.src || '',
            type: (el.getAttribute('type') || '').toLowerCase()
          })).filter(x => x.src);
          const meta = Array.from(document.querySelectorAll('meta[property="og:video"], meta[property="og:video:url"], meta[name="twitter:player:stream"]'))
            .map(m => ({src: m.content || '', type: ''})).filter(x => x.src);
          return list.concat(meta);
        })();
        """
        webView.evaluateJavaScript(script, in: nil, in: .page) { [weak self] result, _ in
            guard let self else { return }
            if let list = result as? [[String: Any]] {
                for entry in list {
                    guard let raw = entry["src"] as? String, let url = URL(string: raw) else { continue }
                    let type = entry["type"] as? String
                    if Self.isUsableMediaURL(url, declaredType: type) {
                        self.finish(url)
                        return
                    }
                }
            }
            self.finish(nil)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(nil) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(nil) }

    private func finish(_ url: URL?) {
        timeoutWork?.cancel()
        timeoutWork = nil
        let completion = self.completion
        self.completion = nil
        webView?.navigationDelegate = nil
        webView?.stopLoading()
        webView = nil
        completion?(url)
    }

    private static func isUsableMediaURL(_ url: URL, declaredType: String?) -> Bool {
        guard url.absoluteString.count <= 8192, ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return false }
        let ext = url.pathExtension.lowercased()
        if ["m3u8", "mp4", "mov", "m4v", "mp3", "m4a", "aac", "wav", "webm"].contains(ext) { return true }
        guard let type = declaredType else { return false }
        return type.hasPrefix("video/") || type.hasPrefix("audio/") || type == "application/x-mpegurl" || type == "application/vnd.apple.mpegurl"
    }
}

final class BrowserProcessPool {
    static let shared = BrowserProcessPool()
    let pool = WKProcessPool()
    private init() {}
}
