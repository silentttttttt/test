import WebKit

final class VideoDetector: NSObject, WKScriptMessageHandler {
    static let messageName = "webBrowseVideoDetector"
    private static let scriptKey = "__webBrowseVideoDetectorV5"

    weak var owner: BrowserViewController?

    func install(on configuration: WKWebViewConfiguration) {
        let controller = configuration.userContentController
        controller.removeScriptMessageHandler(forName: Self.messageName, contentWorld: .page)
        controller.add(self, contentWorld: .page, name: Self.messageName)

        guard BrowserSettings.shared.autoDetectVideos else { return }

        let limit = max(1, min(BrowserSettings.shared.videoDetectionLimit, 50))
        let script = """
        (() => {
          const key = '\(Self.scriptKey)';
          if (window[key]) return;
          window[key] = true;

          const MAX = \(limit);
          let timer = null;
          let lastSignature = '';
          let nextID = 1;
          const seenIframes = new Set();

          const clean = (value) => String(value || '')
            .replace(/\\s+/g, ' ')
            .trim()
            .slice(0, 180);

          const absoluteURL = (value) => {
            if (!value) return '';
            try { return new URL(value, location.href).href; } catch (_) { return ''; }
          };

          const mediaURL = (video) => {
            const source = video.querySelector('source[src], source[data-src]');
            return absoluteURL(
              video.currentSrc ||
              video.src ||
              video.getAttribute('src') ||
              video.getAttribute('data-src') ||
              (source && (source.src || source.getAttribute('src') || source.getAttribute('data-src'))) ||
              ''
            );
          };

          const add = (out, seen, item) => {
            if (out.length >= MAX || !item) return;
            const url = item.url ? absoluteURL(item.url) : '';
            const key = [item.kind || '', url, item.elementID || '', item.title || ''].join('|');
            if (seen.has(key)) return;
            seen.add(key);
            out.push({
              title: clean(item.title) || ('Video ' + (out.length + 1)),
              url: url || null,
              poster: item.poster ? absoluteURL(item.poster) : null,
              kind: item.kind || 'Video',
              elementID: item.elementID || null
            });
          };

          const scanDOM = () => {
            const out = [];
            const seen = new Set();

            const visit = (root) => {
              if (!root || out.length >= MAX) return;

              root.querySelectorAll?.('video').forEach(video => {
                if (out.length >= MAX) return;
                if (!video.dataset.webbrowseVideoId) {
                  video.dataset.webbrowseVideoId = 'wbv-' + (nextID++);
                }

                const title = clean(
                  video.getAttribute('aria-label') ||
                  video.getAttribute('title') ||
                  video.getAttribute('data-title') ||
                  video.closest('figure')?.querySelector('figcaption')?.textContent ||
                  video.closest('[role="figure"]')?.textContent
                );

                add(out, seen, {
                  title,
                  url: mediaURL(video),
                  poster: video.poster || video.getAttribute('data-poster') || '',
                  kind: 'HTML5 video',
                  elementID: video.dataset.webbrowseVideoId
                });
              });

              // Shadow-DOM video elements.
              root.querySelectorAll?.('*').forEach(element => {
                if (out.length >= MAX) return;
                if (element.shadowRoot) visit(element.shadowRoot);
              });
            };

            visit(document);
            return out;
          };

          const scanPageMedia = (out) => {
            if (out.length >= MAX) return;
            const seen = new Set(out.map(x => [x.kind, x.url, x.elementID, x.title].join('|'));

            // Useful when a site exposes a direct media URL without putting it
            // directly on the <video> element.
            document.querySelectorAll('source[src], source[data-src], a[href], link[href]').forEach(el => {
              if (out.length >= MAX) return;
              const raw = el.getAttribute('src') || el.getAttribute('data-src') || el.getAttribute('href') || '';
              const url = absoluteURL(raw);
              if (!url || !/^https?:/i.test(url)) return;
              if (!/\.(mp4|m4v|mov|webm|m3u8|mp3|m4a|aac|wav)(?:$|[?#])/i.test(url)) return;

              add(out, seen, {
                title: el.getAttribute('title') || el.textContent || 'Media',
                url,
                poster: '',
                kind: /\.m3u8(?:$|[?#])/i.test(url) ? 'HLS stream' : 'Direct media',
                elementID: null
              });
            });
          };

          const scanMetadata = (out) => {
            if (out.length >= MAX) return;
            const seen = new Set(out.map(x => [x.kind, x.url, x.elementID, x.title].join('|')));

            document.querySelectorAll('meta[property="og:video"], meta[property="og:video:url"], meta[name="twitter:player:stream"]').forEach(meta => {
              if (out.length >= MAX) return;
              const url = absoluteURL(meta.getAttribute('content') || '');
              if (!url || !/^https?:/i.test(url)) return;
              add(out, seen, {
                title: document.title || 'Video',
                url,
                poster: '',
                kind: 'Page video metadata',
                elementID: null
              });
            });
          };

          const scanEmbeds = (out) => {
            if (out.length >= MAX) return;
            const seen = new Set(out.map(x => [x.kind, x.url, x.elementID, x.title].join('|')));
            document.querySelectorAll('iframe[src]').forEach(frame => {
              if (out.length >= MAX) return;
              const src = absoluteURL(frame.getAttribute('src') || frame.src || '');
              if (!src || !/^https?:/i.test(src)) return;
              if (!/(youtube(?:-nocookie)?|youtu\\.be|vimeo|dailymotion|twitch|wistia|brightcove|jwplayer|player\\.|video)/i.test(src)) return;
              if (seenIframes.has(src)) return;
              seenIframes.add(src);

              add(out, seen, {
                title: frame.getAttribute('title') || 'Embedded player',
                url: src,
                poster: '',
                kind: 'Embedded player',
                elementID: null
              });
            });
          };

          const scan = () => {
            const out = scanDOM();
            scanPageMedia(out);
            scanMetadata(out);
            scanEmbeds(out);

            const sourcePageURL = location.href;
            out.forEach(item => { item.sourcePageURL = sourcePageURL; });

            const signature = JSON.stringify([
              sourcePageURL,
              ...out.map(x => [x.kind, x.elementID, x.url, x.title, x.poster])
            ]);

            if (signature === lastSignature) return;
            lastSignature = signature;

            window.webkit.messageHandlers.webBrowseVideoDetector.postMessage(out);
          };

          const schedule = (delay = 500) => {
            clearTimeout(timer);
            timer = setTimeout(scan, delay);
          };

          const root = document.documentElement || document;
          if (root) {
            new MutationObserver(mutations => {
              const relevant = mutations.some(m => {
                if (m.type === 'attributes') {
                  return !!m.target?.matches?.('video,source,iframe') ||
                         ['src', 'poster', 'data-src'].includes(m.attributeName);
                }
                return Array.from(m.addedNodes || []).some(node => {
                  if (node.nodeType !== 1) return false;
                  return node.matches?.('video,source,iframe') ||
                         !!node.querySelector?.('video,source,iframe');
                });
              });
              if (relevant) schedule(200);
            }).observe(root, {
              childList: true,
              subtree: true,
              attributes: true,
              attributeFilter: ['src', 'poster', 'data-src', 'data-poster']
            });
          }

          document.addEventListener('loadedmetadata', () => schedule(100), true);
          document.addEventListener('durationchange', () => schedule(200), true);
          document.addEventListener('play', () => schedule(200), true);

          if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', () => schedule(50), { once: true });
          } else {
            schedule(50);
          }
        })();
        """

        controller.addUserScript(
            WKUserScript(
                source: script,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true,
                in: .page
            )
        )
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Self.messageName else { return }
        guard let payload = message.body as? [[String: Any]] else { return }

        let limit = max(1, min(BrowserSettings.shared.videoDetectionLimit, 50))
        var candidates: [VideoCandidate] = []
        var seen = Set<VideoCandidate>()

        for (index, item) in payload.prefix(limit).enumerated() {
            let title = (item["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let url = (item["url"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let poster = (item["poster"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let kind = ((item["kind"] as? String) ?? "Video").trimmingCharacters(in: .whitespacesAndNewlines)
            let sourcePageURL = (item["sourcePageURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let elementID = (item["elementID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

            let candidate = VideoCandidate(
                elementID: elementID?.isEmpty == true ? nil : elementID,
                title: title?.isEmpty == false ? title! : "Video \(index + 1)",
                url: url?.isEmpty == true ? nil : url,
                poster: poster?.isEmpty == true ? nil : poster,
                kind: kind.isEmpty ? "Video" : kind,
                sourcePageURL: sourcePageURL?.isEmpty == true ? nil : sourcePageURL
            )

            if seen.insert(candidate).inserted {
                candidates.append(candidate)
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.owner?.updateVideoCandidates(candidates)
        }
    }
}
