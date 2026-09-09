import Foundation

struct WatchedVideo: Codable, Hashable {
    let id: UUID
    let title: String
    let mediaURL: String?
    let sourcePageURL: String
    let sourceHost: String
    let watchedAt: Date
}

final class VideoHistory {
    static let shared = VideoHistory()
    private let maxEntries = 100
    private let schemaVersion = 2
    private let queue = DispatchQueue(label: "com.example.WebBrowse.video-history", qos: .utility)
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var cached: [WatchedVideo] = []
    private var lastSaveFailed = false
    private var saveRetryCount = 0
    private var loaded = false

    private init() {
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func record(title: String, mediaURL: String?, sourcePageURL: String?) {
        guard let sourcePageURL, let sourceURL = URL(string: sourcePageURL),
              ["http", "https"].contains(sourceURL.scheme?.lowercased() ?? ""),
              sourceURL.host != nil else { return }
        let cleanTitle = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        let normalizedMedia = mediaURL.flatMap { raw -> String? in
            guard let u = URL(string: raw), ["http", "https"].contains(u.scheme?.lowercased() ?? "") else { return nil }
            return u.absoluteString
        }
        let normalizedSource = sourceURL.absoluteString
        let item = WatchedVideo(id: UUID(), title: cleanTitle.isEmpty ? "Video" : cleanTitle,
                                mediaURL: normalizedMedia, sourcePageURL: normalizedSource,
                                sourceHost: sourceURL.host ?? "Website", watchedAt: Date())
        queue.async { [weak self] in
            guard let self else { return }
            self.ensureLoaded()
            let mediaKey = normalizedMedia ?? ""
            self.cached.removeAll { $0.sourcePageURL == item.sourcePageURL && ($0.mediaURL ?? "") == mediaKey }
            self.cached.insert(item, at: 0)
            if self.cached.count > self.maxEntries { self.cached.removeLast(self.cached.count - self.maxEntries) }
            self.saveLocked()
            DispatchQueue.main.async { NotificationCenter.default.post(name: .webBrowseVideoHistoryChanged, object: nil) }
        }
    }

    func all() -> [WatchedVideo] {
        queue.sync {
            ensureLoaded()
            return cached
        }
    }

    func clear(completion: (() -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self else { return }
            self.cached.removeAll()
            self.loaded = true
            self.lastSaveFailed = false
            self.saveRetryCount = 0
            try? FileManager.default.removeItem(at: self.fileURL)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .webBrowseVideoHistoryChanged, object: nil)
                completion?()
            }
        }
    }

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("WebBrowse", isDirectory: true).appendingPathComponent("RecentlyWatchedVideos.json")
    }

    private func ensureLoaded() {
        guard !loaded else { return }
        loaded = true
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? NSNumber, size.int64Value <= 2 * 1024 * 1024,
              let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? decoder.decode([WatchedVideo].self, from: data) {
            cached = Array(decoded.sorted { $0.watchedAt > $1.watchedAt }.prefix(maxEntries))
        } else {
            // A corrupt/old history file should never prevent the browser from starting.
            // Keep it private and replace it on the next successful save.
            cached.removeAll()
        }
    }

    private func saveLocked() {
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: dir.path)
        guard let data = try? encoder.encode(cached) else { return }
        do {
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            lastSaveFailed = false
            saveRetryCount = 0
        } catch {
            // Keep the in-memory history. The next history change retries the write.
            lastSaveFailed = true
            guard saveRetryCount < 3 else { return }
            saveRetryCount += 1
            self.queue.asyncAfter(deadline: .now() + 2) { [weak self] in self?.retrySaveIfNeeded() }
        }
    }

    private func retrySaveIfNeeded() {
        guard lastSaveFailed else { return }
        saveLocked()
    }
}

extension Notification.Name {
    static let webBrowseVideoHistoryChanged = Notification.Name("WebBrowseVideoHistoryChanged")
}
