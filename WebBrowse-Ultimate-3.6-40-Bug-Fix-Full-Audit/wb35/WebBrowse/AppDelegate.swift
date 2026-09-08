import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        BrowserSettings.shared.registerDefaults()
        return true
    }
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        if identifier == "com.example.WebBrowse.downloads" {
            DownloadManager.shared.handleBackgroundEvents(completion: completionHandler)
        } else {
            completionHandler()
        }
    }

}
