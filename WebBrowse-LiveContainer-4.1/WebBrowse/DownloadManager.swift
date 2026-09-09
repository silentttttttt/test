import Foundation

extension Notification.Name {
    static let webBrowseDownloadFinished = Notification.Name("WebBrowseDownloadFinished")
    static let webBrowseDownloadFailed = Notification.Name("WebBrowseDownloadFailed")
    static let webBrowseDownloadProgress = Notification.Name("WebBrowseDownloadProgress")
}

enum WebBrowseDownloadFolder: String {
    case downloads = "Downloads"
    case savedVideos = "Saved Videos"
}

final class DownloadManager: NSObject, URLSessionDownloadDelegate, URLSessionTaskDelegate {
    static let shared = DownloadManager()

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.example.WebBrowse.downloads")
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        config.httpMaximumConnectionsPerHost = 3
        config.waitsForConnectivity = true
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 24 * 60 * 60
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private var backgroundCompletion: (() -> Void)?
    private var completions: [Int: (Result<URL, Error>) -> Void] = [:]
    private let lock = NSLock()

    private override init() { super.init() }

    @discardableResult
    func start(url: URL, suggestedName: String?, folder: WebBrowseDownloadFolder = .downloads,
               completion: ((Result<URL, Error>) -> Void)? = nil) -> Bool {
        guard url.absoluteString.count <= 8192, ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.user == nil, url.password == nil else { return false }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let task = session.downloadTask(with: request)
        let name = sanitizedFilename(suggestedName ?? url.lastPathComponent)
        task.taskDescription = "\(folder.rawValue)|\(name)"
        if let completion {
            lock.lock(); completions[task.taskIdentifier] = completion; lock.unlock()
        }
        task.resume()
        return true
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let url = request.url else { completionHandler(nil); return }
        let scheme = url.scheme?.lowercased() ?? ""
        guard (scheme == "http" || scheme == "https"), url.user == nil, url.password == nil, url.absoluteString.count <= 8192 else {
            completionHandler(nil); return
        }
        completionHandler(request)
    }

    func cancel(taskID: Int) {
        session.getAllTasks { tasks in
            tasks.first(where: { $0.taskIdentifier == taskID })?.cancel()
        }
    }

    func handleBackgroundEvents(completion: @escaping () -> Void) {
        lock.lock()
        backgroundCompletion = completion
        lock.unlock()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = min(1.0, max(0.0, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .webBrowseDownloadProgress, object: progress,
                                            userInfo: ["taskID": downloadTask.taskIdentifier])
        }
    }


    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let http = downloadTask.response as? HTTPURLResponse else {
            let error = NSError(domain: "WebBrowseDownload", code: 1, userInfo: [NSLocalizedDescriptionKey: "The server did not return a valid HTTP response."])
            finish(taskID: downloadTask.taskIdentifier, result: .failure(error))
            return
        }
        if !(200...299).contains(http.statusCode) {
            let error = NSError(domain: "WebBrowseDownload", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "The server returned HTTP status \(http.statusCode) instead of a media file."])
            finish(taskID: downloadTask.taskIdentifier, result: .failure(error))
            return
        }
        let mime = downloadTask.response?.mimeType?.lowercased()
        let maximumDownloadBytes: Int64 = 20 * 1024 * 1024 * 1024
        if let expected = downloadTask.response?.expectedContentLength, expected > maximumDownloadBytes {
            let error = NSError(domain: "WebBrowseDownload", code: 4, userInfo: [NSLocalizedDescriptionKey: "WebBrowse refused this download because it is larger than the 20 GB safety limit."])
            finish(taskID: downloadTask.taskIdentifier, result: .failure(error))
            return
        }
        if let attributes = try? FileManager.default.attributesOfItem(atPath: location.path),
           let actual = attributes[.size] as? NSNumber, actual.int64Value > maximumDownloadBytes {
            let error = NSError(domain: "WebBrowseDownload", code: 5, userInfo: [NSLocalizedDescriptionKey: "WebBrowse refused this download because the received file is larger than the 20 GB safety limit."])
            finish(taskID: downloadTask.taskIdentifier, result: .failure(error))
            return
        }
        if let mime, ["text/html", "application/xhtml+xml", "text/plain", "application/json", "text/xml"].contains(mime) {
            let error = NSError(domain: "WebBrowseDownload", code: 2, userInfo: [NSLocalizedDescriptionKey: "The server returned a webpage or text response instead of a media file."])
            finish(taskID: downloadTask.taskIdentifier, result: .failure(error))
            return
        }
        // A small content sniff catches servers that incorrectly label an HTML
        // phishing/redirect page as application/octet-stream.
        if let handle = try? FileHandle(forReadingFrom: location) {
            defer { try? handle.close() }
            let prefix = try? handle.read(upToCount: 512) ?? Data()
            let sample = String(data: prefix ?? Data(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            if sample.hasPrefix("<!doctype html") || sample.hasPrefix("<html") || sample.hasPrefix("<head") || sample.hasPrefix("<script") {
                let error = NSError(domain: "WebBrowseDownload", code: 3, userInfo: [NSLocalizedDescriptionKey: "WebBrowse rejected the download because it looks like a webpage rather than a video or audio file."])
                finish(taskID: downloadTask.taskIdentifier, result: .failure(error))
                return
            }
        }
        let extensionLooksMedia = ["mp4", "mov", "m4v", "webm", "mp3", "m4a", "aac", "wav"].contains((downloadTask.originalRequest?.url?.pathExtension ?? "").lowercased())
        let mimeLooksMedia = mime.map { $0.hasPrefix("video/") || $0.hasPrefix("audio/") } ?? false
        if !extensionLooksMedia && !mimeLooksMedia {
            let error = NSError(domain: "WebBrowseDownload", code: 6, userInfo: [NSLocalizedDescriptionKey: "WebBrowse could not verify that this response is a media file."])
            finish(taskID: downloadTask.taskIdentifier, result: .failure(error))
            return
        }
        do {
            let fm = FileManager.default
            let documents = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let description = downloadTask.taskDescription ?? "Downloads|WebBrowse-Download"
            let parts = description.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
            let folderName = parts.first.map(String.init) ?? WebBrowseDownloadFolder.downloads.rawValue
            var fileName = sanitizedFilename(parts.count > 1 ? String(parts[1]) : "WebBrowse-Download")
            if !fileName.contains("."), let mime {
                if let ext = Self.fileExtension(for: mime) { fileName += ".\(ext)" }
            }
            let dir = documents.appendingPathComponent(folderName, isDirectory: true)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let protection: FileProtectionType = folderName == WebBrowseDownloadFolder.savedVideos.rawValue ? .complete : .completeUntilFirstUserAuthentication
            try? fm.setAttributes([.protectionKey: protection], ofItemAtPath: dir.path)
            let destination = uniqueURL(dir.appendingPathComponent(fileName))
            try fm.moveItem(at: location, to: destination)
            // Keep saved media protected by iOS Data Protection. Downloads remain available
            // after the first device unlock; the more private Saved Videos folder is locked
            // whenever the device is locked.
            try fm.setAttributes([.protectionKey: protection], ofItemAtPath: destination.path)
            finish(taskID: downloadTask.taskIdentifier, result: .success(destination))
        } catch {
            finish(taskID: downloadTask.taskIdentifier, result: .failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        finish(taskID: task.taskIdentifier, result: .failure(error))
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        lock.lock()
        let completion = backgroundCompletion
        backgroundCompletion = nil
        lock.unlock()
        DispatchQueue.main.async { completion?() }
    }

    private func finish(taskID: Int, result: Result<URL, Error>) {
        let completion: ((Result<URL, Error>) -> Void)?
        lock.lock()
        completion = completions.removeValue(forKey: taskID)
        lock.unlock()

        DispatchQueue.main.async {
            switch result {
            case .success(let url):
                NotificationCenter.default.post(name: .webBrowseDownloadFinished, object: url, userInfo: ["taskID": taskID])
            case .failure(let error):
                NotificationCenter.default.post(name: .webBrowseDownloadFailed, object: error, userInfo: ["taskID": taskID])
            }
            completion?(result)
        }
    }

    private static func fileExtension(for mime: String) -> String? {
        switch mime {
        case "video/mp4": return "mp4"
        case "video/quicktime": return "mov"
        case "video/x-m4v": return "m4v"
        case "video/webm": return "webm"
        case "audio/mpeg": return "mp3"
        case "audio/mp4": return "m4a"
        case "audio/aac": return "aac"
        case "audio/wav", "audio/x-wav": return "wav"
        default: return nil
        }
    }

    private func sanitizedFilename(_ input: String) -> String {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { value = "WebBrowse-Download" }
        value = value.replacingOccurrences(of: "[<>:\"/\\|?*]", with: "_", options: .regularExpression)
        value = String(value.prefix(120))
        return value.isEmpty ? "WebBrowse-Download" : value
    }

    private func uniqueURL(_ url: URL) -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return url }
        let ext = url.pathExtension
        let stem = url.deletingPathExtension().lastPathComponent
        for n in 2...9999 {
            let candidate = url.deletingLastPathComponent().appendingPathComponent("\(stem) (\(n))\(ext.isEmpty ? "" : ".\(ext)")")
            if !fm.fileExists(atPath: candidate.path) { return candidate }
        }
        return url.deletingPathExtension().appendingPathExtension("copy")
    }
}
