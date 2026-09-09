import Foundation
import Photos

final class PhotoSaver {
    static let shared = PhotoSaver()
    private init() {}

    func saveVideo(at url: URL, completion: @escaping (Error?) -> Void) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            completion(NSError(domain: "WebBrowsePhotos", code: 2, userInfo: [NSLocalizedDescriptionKey: "The downloaded video no longer exists."]))
            return
        }
        guard ["mp4", "mov", "m4v"].contains(url.pathExtension.lowercased()) else {
            completion(NSError(domain: "WebBrowsePhotos", code: 3, userInfo: [NSLocalizedDescriptionKey: "Only MP4, MOV, and M4V videos can be saved to Photos."]))
            return
        }
        let perform: () -> Void = {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }, completionHandler: { _, error in
                DispatchQueue.main.async { completion(error) }
            })
        }

        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                DispatchQueue.main.async {
                    guard status == .authorized || status == .limited else {
                        completion(NSError(domain: "WebBrowsePhotos", code: 1, userInfo: [NSLocalizedDescriptionKey: "Photo access was not granted."]))
                        return
                    }
                    perform()
                }
            }
        } else {
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    guard status == .authorized else {
                        completion(NSError(domain: "WebBrowsePhotos", code: 1, userInfo: [NSLocalizedDescriptionKey: "Photo access was not granted."]))
                        return
                    }
                    perform()
                }
            }
        }
    }
}
