import WebKit

final class VideoDetector: NSObject, WKScriptMessageHandler {
    static let messageName = "webBrowseVideoDetector"
    weak var owner: BrowserViewController?

    func install(on configuration: WKWebViewConfiguration) {
        let controller = configuration.userContentController
        controller.removeScriptMessageHandler(forName: Self.messageName, contentWorld: .page)
        controller.add(self, contentWorld: .page, name: Self.messageName)
        guard BrowserSettings.shared.autoDetectVideos else { return }
        let script = """
        (() => {
          const key = '__webBrowseVideoDetectorV4';
          if (window[key]) return;
          window[key] = true;
          let timer = null;
          let lastSignature = '';
          let lastScan = 0;
          let nextID = 1;
          const MAX = \(BrowserSettings.shared.videoDetectionLimit);
          const schedule = (delay = 700) => {
            clearTimeout(timer);
            timer = setTimeout(send, delay);
          };
          const clean = (value) => (value || '').replace(/\\s+/g, ' ').trim().slice(0, 180);
          const mediaURL = (v) => {
            const source = v.querySelector('source[src]');
            return v.currentSrc || v.src || (source ? source.src : '');
          };
          const scanVideos = () => {
            const out = [];
            const seen = new Set();
            const visit = (root) => {
              if (!root || out.length >= MAX) return;
              root.querySelectorAll?.('video').forEach(v => {
                if (out.length >= MAX) return;
                if (!v.dataset.webbrowseVideoId) v.dataset.webbrowseVideoId = 'wbv-' + (nextID++);
                const id = v.dataset.webbrowseVideoId;
                if (seen.has(id)) return;
                seen.add(id);
                const title = clean(v.getAttribute('aria-label') || v.getAttribute('title') || v.getAttribute('data-title') || v.closest('figure')?.querySelector('figcaption')?.textContent);
                out.push({ title: title || ('Video ' + (out.length + 1)), url: mediaURL(v) || null, poster: v.poster || null, kind: 'HTML5 video', elementID: id });
              });
              root.querySelectorAll?.('*').forEach(el => {
                if (out.length >= MAX) return;
                if (el.shadowRoot) visit(el.shadowRoot);
              });
            };
            visit(document);
            return out;
          };
          const send = () => {
            const now = Date.now();
            if (now - lastScan < 350) return;
            lastScan = now;
            const result = scanVideos();
            if (result.length < MAX) {
              document.querySelectorAll('iframe[src]').forEach(f => {
                if (result.length >= MAX) return;
                const src = f.src || '';
                if (/youtube|youtu[.]be|vimeo|dailymotion|twitch|player[.]|video/i.test(src) && !iframeSeen.has(src)) {
                  iframeSeen.add(src);
                  result.push({ title: clean(f.getAttribute('title')) || 'Embedded player', url: src, poster: null, kind: 'Embedded player', elementID: null });
                }
              });
            }
            const sourcePageURL = location.href;
            const iframeSeen = new Set(result.filter(x => x.kind === 'Embedded player').map(x => x.url));
            result.forEach(x => { x.sourcePageURL = sourcePageURL; });
            const signature = JSON.stringify([sourcePageURL, ...result.map(x => [x.kind, x.elementID, x.url, x.title])]);
            if (signature === lastSignature) return;
            lastSignature = signature;
            window.webkit.messageHandlers.webBrowseVideoDetector.postMessage(result);
          };
          const root = document.documentElement || document;
          if (root) {
            new MutationObserver((mutations) => {
              const relevant = mutations.some(m => {
                if (m.type === 'attributes') {
                  return m.target?.matches?.('video,source,iframe') === true;
                }
                return Array.from(m.addedNodes).some(node => {
                  if (node.nodeType !== 1) return false;
                  const el = node;
                  return el.matches?.('video,source,iframe') || !!el.querySelector?.('video,source,iframe');
                });
              });
              if (relevant) schedule(250);
            }).observe(root, {childList:true, subtree:true, attributes:true, attributeFilter:['src','poster','type']});
          }
          document.addEventListener('loadedmetadata', () => schedule(150), true);
          document.addEventListener('durationchange', () => schedule(250), true);
          document.addEventListener('play', () => schedule(250), true);
          if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', () => schedule(100), {once:true}); else schedule(100);
        })();
        """
        controller.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: .page))
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Self.messageName, let payload = message.body as? [[String: Any]] else { return }
        var candidates: [VideoCandidate] = []
        for (index, item) in payload.prefix(BrowserSettings.shared.videoDetectionLimit).enumerated() {
            let title = (item["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let url = item["url"] as? String
            let poster = item["poster"] as? String
            let kind = (item["kind"] as? String) ?? "Video"
            let sourcePageURL = item["sourcePageURL"] as? String
            let elementID = item["elementID"] as? String
            candidates.append(VideoCandidate(elementID: elementID, title: (title?.isEmpty == false ? title! : "Video \(index + 1)"), url: url, poster: poster, kind: kind, sourcePageURL: sourcePageURL))
        }
        DispatchQueue.main.async { [weak self] in self?.owner?.updateVideoCandidates(candidates) }
    }
}
