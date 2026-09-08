import UIKit

final class VideoListViewController: UITableViewController {
    private let candidates: [VideoCandidate]
    private weak var browser: BrowserViewController?

    init(candidates: [VideoCandidate], browser: BrowserViewController) {
        self.candidates = candidates
        self.browser = browser
        super.init(style: .insetGrouped)
        title = candidates.isEmpty ? "Videos" : "Videos (\(candidates.count))"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Recently Watched", style: .plain, target: self, action: #selector(openHistory))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(close))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "VideoCell")
        tableView.rowHeight = 72
    }

    @objc private func close() { dismiss(animated: true) }

    @objc private func openHistory() {
        let vc = VideoHistoryViewController()
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { candidates.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "VideoCell", for: indexPath)
        let item = candidates[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = item.title
        content.secondaryText = item.kind == "Embedded player" ? "Native player will be attempted first" : item.kind
        content.image = UIImage(systemName: "play.rectangle.fill")
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = candidates[indexPath.row]
        let sheet = UIAlertController(title: item.title, message: item.kind, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Watch in WebBrowse Player", style: .default) { [weak self] _ in self?.watch(item) })

        if BrowserSettings.shared.allowDownloads,
           let urlString = item.url,
           let url = URL(string: urlString),
           (Self.isDirectMedia(url) || (item.kind == "HTML5 video" && Self.isHTTPMediaCandidate(url))) {
            sheet.addAction(UIAlertAction(title: "Download", style: .default) { [weak self] _ in
                let started = DownloadManager.shared.start(url: url, suggestedName: item.title, folder: .downloads) { [weak self] result in
                    guard let self else { return }
                    let alert: UIAlertController
                    switch result {
                    case .success(let localURL):
                        alert = UIAlertController(title: "Download complete", message: localURL.lastPathComponent, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "Share / Save to Files", style: .default) { _ in self.share(localURL) })
                    case .failure(let error):
                        alert = UIAlertController(title: "Download failed", message: error.localizedDescription, preferredStyle: .alert)
                    }
                    alert.addAction(UIAlertAction(title: "Done", style: .cancel))
                    self.present(alert, animated: true)
                }
                if !started { self?.showDownloadError() }
            })
            sheet.addAction(UIAlertAction(title: "Save in WebBrowse", style: .default) { [weak self] _ in
                let started = DownloadManager.shared.start(url: url, suggestedName: item.title, folder: .savedVideos) { [weak self] result in
                    guard let self else { return }
                    let message: String
                    switch result {
                    case .success(let localURL): message = localURL.lastPathComponent
                    case .failure(let error): message = error.localizedDescription
                    }
                    let alert = UIAlertController(title: { if case .success = result { return "Saved in WebBrowse" }; return "Save failed" }(), message: message, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
                if !started { self?.showDownloadError() }
            })
            if ["mp4", "mov", "m4v"].contains(url.pathExtension.lowercased()) {
                sheet.addAction(UIAlertAction(title: "Save to Photos", style: .default) { [weak self] _ in
                    self?.downloadForPhotos(url: url, title: item.title)
                })
            }
        }
        if let urlString = item.url, let url = URL(string: urlString), ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            sheet.addAction(UIAlertAction(title: "Share Video Link", style: .default) { [weak self] _ in self?.shareURL(url) })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = sheet.popoverPresentationController, let cell = tableView.cellForRow(at: indexPath) {
            pop.sourceView = cell
            pop.sourceRect = cell.bounds
        }
        present(sheet, animated: true)
    }

    private func watch(_ item: VideoCandidate) {
        dismiss(animated: true) { [weak self] in
            guard let self, let browser = self.browser else { return }
            if let urlString = item.url, let url = URL(string: urlString), url.scheme?.lowercased() != "blob" {
                let ext = url.pathExtension.lowercased()
                if ["m3u8", "mp4", "mov", "m4v"].contains(ext) {
                    browser.presentNativeVideo(url: url, title: item.title, sourcePageURL: item.sourcePageURL, mediaURL: item.url)
                    return
                }
                if item.kind == "Embedded player" {
                    // First try to resolve the iframe's actual <video>/<source> URL and hand
                    // that media to AVPlayer. This keeps playback inside WebBrowse whenever
                    // the embedded player exposes a native-playable stream.
                    browser.resolveEmbeddedVideo(url: url, title: item.title, sourcePageURL: item.sourcePageURL, mediaURL: item.url)
                    return
                }
            }
            browser.playDetectedVideo(elementID: item.elementID)
        }
    }

    private func downloadForPhotos(url: URL, title: String) {
        let started = DownloadManager.shared.start(url: url, suggestedName: title, folder: .savedVideos) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let localURL):
                PhotoSaver.shared.saveVideo(at: localURL) { error in
                    let alert = UIAlertController(title: error == nil ? "Saved to Photos" : "Could not save to Photos", message: error?.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            case .failure(let error):
                let alert = UIAlertController(title: "Download failed", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
        if !started { showDownloadError() }
    }

    private func showDownloadError() {
        let alert = UIAlertController(title: "Unable to start download", message: "This video does not expose a downloadable HTTP(S) media URL.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func share(_ url: URL) {
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let pop = vc.popoverPresentationController { pop.barButtonItem = navigationItem.rightBarButtonItem }
        present(vc, animated: true)
    }

    private func shareURL(_ url: URL) {
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let pop = vc.popoverPresentationController { pop.sourceView = view; pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1) }
        present(vc, animated: true)
    }

    private static func isDirectMedia(_ url: URL) -> Bool {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return false }
        return ["mp4", "mov", "m4v", "mp3", "m4a", "aac", "wav", "webm"].contains(url.pathExtension.lowercased())
    }

    private static func isHTTPMediaCandidate(_ url: URL) -> Bool {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return false }
        guard url.host != nil else { return false }
        let ext = url.pathExtension.lowercased()
        return ext.isEmpty || isDirectMedia(url)
    }
}
