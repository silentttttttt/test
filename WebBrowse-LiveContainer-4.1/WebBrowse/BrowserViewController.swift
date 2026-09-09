import UIKit
import WebKit

final class BrowserViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, UISearchBarDelegate {
    private let videoDetector = VideoDetector()
    private var videoCandidates: [VideoCandidate] = []
    private var videoButton: UIButton!
    private var webView: WKWebView!
    private let searchBar = UISearchBar()
    private let toolbar = UIToolbar()
    private var shareButton: UIBarButtonItem!
    private let progressView = UIProgressView(progressViewStyle: .bar)
    private var lastHost: String?
    private var rebuildPending = false
    private var redirectCount = 0
    private var redirectWindowStart: Date?
    private var isLoading = false
    private var observations: [NSKeyValueObservation] = []
    private var videoResolver: VideoURLResolver?
    private var lastContentProcessRestart = Date.distantPast
    private var dialogCount = 0
    private var dialogWindowStart = Date.distantPast
    

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(handleHistoryURL(_:)), name: .webBrowseOpenURLFromHistory, object: nil)
        view.backgroundColor = .systemBackground
        buildBrowser(initialURL: BrowserSettings.shared.homePage)
    }

    private func makeConfiguration() -> WKWebViewConfiguration {
        let c = WKWebViewConfiguration()
        c.processPool = BrowserProcessPool.shared.pool
        c.allowsInlineMediaPlayback = true
        c.allowsPictureInPictureMediaPlayback = true
        c.allowsAirPlayForMediaPlayback = true
        // Keep autoplay disabled by default. Sites can still start playback from a user gesture.
        c.mediaTypesRequiringUserActionForPlayback = [.audio, .video]
        c.websiteDataStore = BrowserSettings.shared.privateMode ? .nonPersistent() : .default()
        c.upgradeKnownHostsToHTTPS = BrowserSettings.shared.httpsOnly
        videoDetector.owner = self
        videoDetector.install(on: c)
        return c
    }

    private func buildBrowser(initialURL: String?) {
        let c = makeConfiguration()
        webView = WKWebView(frame: .zero, configuration: c)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        if BrowserSettings.shared.effectiveLowMemoryMode {
            webView.scrollView.isPrefetchingEnabled = false
            webView.scrollView.delaysContentTouches = false
        }
        if BrowserSettings.shared.blockAds || BrowserSettings.shared.preventTracking {
            ContentBlocker.shared.install(on: webView, blockAds: BrowserSettings.shared.blockAds, preventTracking: BrowserSettings.shared.preventTracking)
        }

        searchBar.placeholder = "Search or enter website"
        searchBar.searchBarStyle = .minimal
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false

        videoButton = UIButton(type: .system)
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.image = UIImage(systemName: "play.rectangle.fill")
            config.imagePadding = 5
            config.cornerStyle = .medium
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
            videoButton.configuration = config
        } else {
            videoButton.setImage(UIImage(systemName: "play.rectangle.fill"), for: .normal)
        }
        videoButton.accessibilityLabel = "Videos found on this page"
        videoButton.addTarget(self, action: #selector(openVideos), for: .touchUpInside)
        videoButton.translatesAutoresizingMaskIntoConstraints = false
        videoButton.isHidden = true

        let settings = UIBarButtonItem(image: UIImage(systemName: "slider.horizontal.3"), style: .plain, target: self, action: #selector(openSettings))
        let back = UIBarButtonItem(image: UIImage(systemName: "chevron.backward"), style: .plain, target: self, action: #selector(goBack))
        let forward = UIBarButtonItem(image: UIImage(systemName: "chevron.forward"), style: .plain, target: self, action: #selector(goForward))
        let home = UIBarButtonItem(image: UIImage(systemName: "house"), style: .plain, target: self, action: #selector(goHome))
        shareButton = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(sharePage))
        let reload = UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"), style: .plain, target: self, action: #selector(reloadOrStop))
        toolbar.items = [settings, back, forward, .flexibleSpace(), shareButton, home, reload]
        toolbar.translatesAutoresizingMaskIntoConstraints = false

        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.isHidden = true
        progressView.progress = 0

        view.addSubview(searchBar)
        view.addSubview(videoButton)
        view.addSubview(webView)
        view.addSubview(toolbar)
        view.addSubview(progressView)

        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: g.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: g.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: videoButton.leadingAnchor, constant: -4),
            searchBar.heightAnchor.constraint(equalToConstant: 50),
            videoButton.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -8),
            videoButton.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor),
            videoButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 72),
            videoButton.heightAnchor.constraint(equalToConstant: 40),
            webView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: toolbar.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            progressView.leadingAnchor.constraint(equalTo: webView.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: webView.trailingAnchor),
            progressView.topAnchor.constraint(equalTo: webView.topAnchor)
        ])

        observations.removeAll()
        observations.append(webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] webView, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.progressView.progress = Float(webView.estimatedProgress)
                self.progressView.isHidden = webView.estimatedProgress >= 1.0
            }
        })
        observations.append(webView.observe(\.title, options: [.new]) { [weak self] webView, _ in
            guard let self else { return }
            DispatchQueue.main.async { self.navigationItem.title = webView.title }
        })

        if let raw = initialURL, let url = URL(string: raw) {
            load(url)
        }
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let raw = searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return }
        searchBar.resignFirstResponder()
        if let u = URL(string: raw), let scheme = u.scheme?.lowercased(), ["http", "https"].contains(scheme) { load(u); return }
        if !raw.contains(" ") && raw.contains("."), let u = URL(string: "https://" + raw) { load(u); return }
        let q = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? raw
        let base = BrowserSettings.shared.searchEngine == "DuckDuckGo" ? "https://duckduckgo.com/?q=" : "https://www.google.com/search?q="
        guard let url = URL(string: base + q) else { return }
        load(url)
    }

    private func secureURL(_ url: URL) -> URL {
        guard BrowserSettings.shared.httpsOnly, url.scheme?.lowercased() == "http", var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        components.scheme = "https"
        return components.url ?? url
    }

    private func load(_ url: URL) {
        let finalURL = secureURL(url)
        if BrowserSettings.shared.suspiciousURLProtection {
            switch NavigationSecurity.inspect(finalURL) {
            case .block(let reason): showSecurityNotice(reason); return
            case .warn(let warning):
                let alert = UIAlertController(title: "Check this website", message: warning, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                alert.addAction(UIAlertAction(title: "Continue", style: .default) { [weak self] _ in self?.performLoad(finalURL) })
                present(alert, animated: true)
                return
            case .allow: break
            }
        }
        performLoad(finalURL)
    }

    private func performLoad(_ url: URL) {
        guard ["http", "https", "about"].contains(url.scheme?.lowercased() ?? "") else { return }
        searchBar.text = url.absoluteString
        webView.load(URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30))
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        videoCandidates.removeAll()
        videoButton?.isHidden = true
        isLoading = true
        progressView.isHidden = false
        if redirectWindowStart == nil || Date().timeIntervalSince(redirectWindowStart!) > 5 {
            redirectWindowStart = Date()
            redirectCount = 0
        }
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        searchBar.text = webView.url?.absoluteString
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        searchBar.text = webView.url?.absoluteString
        lastHost = webView.url?.host
        redirectCount = 0
        redirectWindowStart = nil
        dialogCount = 0
        refreshDetectedVideos()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        if (error as NSError).code == NSURLErrorCancelled { return }
        showError(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        if (error as NSError).code == NSURLErrorCancelled { return }
        showError(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        // WebKit can terminate a content process under memory pressure. Restore the page instead of leaving a blank browser.
        guard webView.url != nil else { return }
        let now = Date()
        guard now.timeIntervalSince(lastContentProcessRestart) > 2 else { return }
        lastContentProcessRestart = now
        webView.reload()
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let target = action.request.url else { decisionHandler(.cancel); return }
        let scheme = target.scheme?.lowercased() ?? ""
        if BrowserSettings.shared.suspiciousURLProtection {
            switch NavigationSecurity.inspect(target) {
            case .block(let reason):
                decisionHandler(.cancel)
                showSecurityNotice(reason)
                return
            case .warn(let warning):
                if action.targetFrame?.isMainFrame == true {
                    let alert = UIAlertController(title: "Check this website", message: warning, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Go Back", style: .cancel))
                    alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in decisionHandler(.allow) })
                    present(alert, animated: true)
                    return
                }
            case .allow:
                break
            }
        }
        guard scheme == "http" || scheme == "https" || scheme == "about" else {
            decisionHandler(.cancel)
            return
        }

        if BrowserSettings.shared.httpsOnly, scheme == "http" {
            decisionHandler(.cancel)
            load(target)
            return
        }

        if BrowserSettings.shared.blockRedirects, action.targetFrame?.isMainFrame == true, action.navigationType == .other {
            let now = Date()
            if redirectWindowStart == nil || now.timeIntervalSince(redirectWindowStart!) > 5 {
                redirectWindowStart = now
                redirectCount = 0
            }
            redirectCount += 1
            // Allow normal multi-host OAuth/SSO/payment flows, but stop an automatic
            // redirect loop before it can churn the WebView or trap the user.
            if redirectCount > 10 {
                decisionHandler(.cancel)
                showSecurityNotice("WebBrowse stopped an unusually long automatic redirect chain.")
                return
            }
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if BrowserSettings.shared.blockPopups { return nil }
        guard let url = action.request.url else { return nil }
        if BrowserSettings.shared.suspiciousURLProtection, case .block(let reason) = NavigationSecurity.inspect(url) { showSecurityNotice(reason); return nil }
        load(url)
        return nil
    }

    private func allowJavaScriptDialog() -> Bool {
        let now = Date()
        if now.timeIntervalSince(dialogWindowStart) > 10 { dialogWindowStart = now; dialogCount = 0 }
        dialogCount += 1
        return dialogCount <= 8
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        guard allowJavaScriptDialog() else { completionHandler(); return }
        let a = UIAlertController(title: webView.url?.host ?? "Website", message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(a, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        guard allowJavaScriptDialog() else { completionHandler(false); return }
        let a = UIAlertController(title: webView.url?.host ?? "Website", message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(a, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        guard allowJavaScriptDialog() else { completionHandler(nil); return }
        let a = UIAlertController(title: webView.url?.host ?? "Website", message: prompt, preferredStyle: .alert)
        a.addTextField { $0.text = defaultText }
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(nil) })
        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(a.textFields?.first?.text) })
        present(a, animated: true)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard let url = navigationResponse.response.url, BrowserSettings.shared.suspiciousURLProtection else {
            decisionHandler(.allow)
            return
        }
        switch NavigationSecurity.inspect(url) {
        case .allow:
            decisionHandler(.allow)
        case .block(let reason):
            decisionHandler(.cancel)
            showSecurityNotice(reason)
        case .warn:
            // URL warnings are presented at navigation-action time; don't interrupt
            // an already-approved response a second time.
            decisionHandler(.allow)
        }
    }

    @objc private func goBack() { if webView.canGoBack { webView.goBack() } }
    @objc private func goForward() { if webView.canGoForward { webView.goForward() } }
    @objc private func reloadOrStop() { isLoading ? webView.stopLoading() : webView.reload() }
    @objc private func goHome() {
        guard let url = URL(string: BrowserSettings.shared.homePage) else { return }
        load(url)
    }
    @objc private func sharePage() {
        guard let url = webView.url else { return }
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = activity.popoverPresentationController { popover.barButtonItem = shareButton }
        present(activity, animated: true)
    }
    @objc private func openSettings() {
        let vc = SettingsViewController()
        vc.onChanged = { [weak self] in self?.rebuildPreservingURL() }
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    private func rebuildPreservingURL() {
        guard !rebuildPending else { return }
        rebuildPending = true
        let current = webView.url?.absoluteString ?? BrowserSettings.shared.homePage
        videoResolver = nil
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        observations.removeAll()
        webView.removeFromSuperview()
        webView = nil
        searchBar.removeFromSuperview()
        videoButton.removeFromSuperview()
        toolbar.removeFromSuperview()
        progressView.removeFromSuperview()
        videoCandidates.removeAll()
        buildBrowser(initialURL: current)
        rebuildPending = false
    }

    func updateVideoCandidates(_ candidates: [VideoCandidate]) {
        var seen = Set<String>()
        let currentSource = webView.url?.absoluteString
        let sourcePageURL = candidates.compactMap { item -> String? in
            guard let raw = item.sourcePageURL, let url = URL(string: raw),
                  ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return nil }
            let normalized = url.absoluteString
            return currentSource == nil || normalized == currentSource ? normalized : nil
        }.first ?? currentSource
        guard sourcePageURL == nil || sourcePageURL == currentSource else { return }
        videoCandidates = candidates.filter { item in
            let key = "\(item.kind)|\(item.elementID ?? "")|\(item.url ?? item.title)"
            return seen.insert(key).inserted
        }.prefix(100).map { item in
            VideoCandidate(elementID: item.elementID, title: item.title, url: item.url, poster: item.poster, kind: item.kind, sourcePageURL: item.sourcePageURL.flatMap { raw in URL(string: raw)?.absoluteString } ?? sourcePageURL)
        }
        videoButton.isHidden = videoCandidates.isEmpty
        videoButton.alpha = videoCandidates.isEmpty ? 0 : 1
        videoButton.accessibilityLabel = videoCandidates.isEmpty ? "No videos detected" : "Videos found: \(videoCandidates.count)"
        let title = videoCandidates.isEmpty ? nil : "Videos \(videoCandidates.count)"
        if #available(iOS 15.0, *) {
            videoButton.configuration?.title = title
        } else {
            videoButton.setTitle(title, for: .normal)
        }
    }

    private func refreshDetectedVideos() {
        let script = "document.dispatchEvent(new Event('loadedmetadata'));"
        webView.evaluateJavaScript(script, in: nil, in: .page) { _, _ in }
    }

    @objc private func openVideos() {
        let vc = VideoListViewController(candidates: videoCandidates, browser: self)
        let nav = UINavigationController(rootViewController: vc)
        if let popover = nav.popoverPresentationController {
            popover.sourceView = videoButton
            popover.sourceRect = videoButton.bounds
            popover.permittedArrowDirections = .up
        }
        present(nav, animated: true)
    }

    func playDetectedVideo(elementID: String?) {
        guard let elementID, !elementID.isEmpty else {
            showError(NSError(domain: "WebBrowseVideo", code: 1, userInfo: [NSLocalizedDescriptionKey: "This video is controlled by an embedded player and does not expose a direct HTML5 video element."]))
            return
        }
        let escapedID = elementID.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
        let script = """
        (() => {
          const find = (root) => {
            if (!root) return null;
            const direct = root.querySelector?.('video[data-webbrowse-video-id="\(escapedID)"]');
            if (direct) return direct;
            for (const el of root.querySelectorAll?.('*') || []) {
              if (el.shadowRoot) {
                const nested = find(el.shadowRoot);
                if (nested) return nested;
              }
            }
            return null;
          };
          const v = find(document);
          if (!v) return false;
          v.scrollIntoView({behavior:'smooth', block:'center'});
          v.muted = false;
          const p = v.play();
          if (p && p.catch) p.catch(() => {});
          return true;
        })();
        """
        webView.evaluateJavaScript(script, in: nil, in: .page) { [weak self] result, _ in
            guard let self else { return }
            guard (result as? Bool) == true else {
                self.showError(NSError(domain: "WebBrowseVideo", code: 1, userInfo: [NSLocalizedDescriptionKey: "The site's video could not be started. It may be protected or controlled by the site's own player."]))
                return
            }
            // Only record history after the element actually reports itself as playing.
            // A successful play() call can still be rejected by autoplay/policy or the
            // site's media pipeline.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                guard let self, let item = self.videoCandidates.first(where: { $0.elementID == elementID }) else { return }
                let check = "(() => { const find=(root)=>{ if(!root) return null; const d=root.querySelector?.('video[data-webbrowse-video-id=\"\(escapedID)\"]'); if(d) return d; for(const e of root.querySelectorAll?.('*')||[]){ if(e.shadowRoot){ const n=find(e.shadowRoot); if(n) return n; }} return null; }; const v=find(document); return !!v && !v.paused && v.readyState >= 2; })();"
                self.webView.evaluateJavaScript(check, in: nil, in: .page) { [weak self] state, _ in
                    guard let self, (state as? Bool) == true else { return }
                    if !BrowserSettings.shared.privateMode {
                        VideoHistory.shared.record(title: item.title, mediaURL: item.url, sourcePageURL: item.sourcePageURL ?? self.webView.url?.absoluteString)
                    }
                }
            }
        }
    }

    func resolveEmbeddedVideo(url: URL, title: String, sourcePageURL: String?, mediaURL: String?) {
        let resolver = VideoURLResolver(url: url, dataStore: webView.configuration.websiteDataStore)
        videoResolver = resolver
        resolver.resolve { [weak self] resolvedURL in
            DispatchQueue.main.async {
                guard let self else { return }
                self.videoResolver = nil
                if let resolvedURL {
                    self.presentNativeVideo(url: resolvedURL, title: title, sourcePageURL: sourcePageURL, mediaURL: mediaURL)
                } else {
                    self.showNativePlayerUnavailable(message: "This embedded player does not expose a direct media stream that iOS can play natively. WebBrowse will keep playback on the site's player instead of pretending it can extract protected media.")
                    self.openDetectedVideoPage(url)
                }
            }
        }
    }

    func presentNativeVideo(url: URL, title: String, sourcePageURL: String? = nil, mediaURL: String? = nil) {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            showNativePlayerUnavailable(message: "WebBrowse can only play media from an HTTP or HTTPS URL.")
            return
        }
        if BrowserSettings.shared.suspiciousURLProtection, case .block(let reason) = NavigationSecurity.inspect(url) {
            showSecurityNotice(reason)
            return
        }
        let player = NativeVideoPlayerViewController(url: url, title: title, headers: [:]) { [weak self] in
            guard let self else { return }
            if !BrowserSettings.shared.privateMode {
                VideoHistory.shared.record(title: title, mediaURL: mediaURL ?? url.absoluteString, sourcePageURL: sourcePageURL ?? self.webView.url?.absoluteString)
            }
        }
        present(player, animated: true)
    }

    func openDetectedVideoPage(_ url: URL) {
        load(url)
    }

    func showNativePlayerUnavailable(message: String) {
        let alert = UIAlertController(title: "Native player unavailable", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showSecurityNotice(_ message: String) {
        guard presentedViewController == nil, viewIfLoaded?.window != nil else { return }
        let a = UIAlertController(title: "WebBrowse Protection", message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    @objc private func handleHistoryURL(_ notification: Notification) {
        guard let url = notification.object as? URL else { return }
        load(url)
    }

    private func showError(_ error: Error) {
        if let presented = presentedViewController, presented.isBeingDismissed || presented.isBeingPresented {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in self?.showError(error) }
            return
        }
        guard presentedViewController == nil else { return }
        let a = UIAlertController(title: "WebBrowse", message: error.localizedDescription, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }


    deinit {
        NotificationCenter.default.removeObserver(self)
        observations.removeAll()
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: VideoDetector.messageName, contentWorld: .page)
    }
}
