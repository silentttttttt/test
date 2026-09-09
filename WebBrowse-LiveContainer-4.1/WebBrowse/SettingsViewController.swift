import UIKit
import WebKit

final class SettingsViewController: UITableViewController {
    var onChanged: (() -> Void)?
    private let s = BrowserSettings.shared

    private enum Row: Int, CaseIterable {
        case ads, popups, redirects, trackers, suspiciousURLs, privateMode, https, videos, downloads, lowMemory
        case privacyDashboard, clearData
        case appLock, customize
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
        tableView.cellLayoutMarginsFollowReadableWidth = true
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 4 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        [10, 2, 1, 1][section]
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        ["Protection & Performance", "Privacy & Data", "Security", "Appearance"][section]
    }

    private func row(for indexPath: IndexPath) -> Row {
        let offsets = [0, 10, 12, 13]
        return Row(rawValue: offsets[indexPath.section] + indexPath.row)!
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        if let reused = tableView.dequeueReusableCell(withIdentifier: "Setting") {
            cell = reused
        } else {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: "Setting")
        }
        cell.accessoryView = nil
        cell.accessoryType = .none
        cell.detailTextLabel?.text = nil
        cell.textLabel?.textColor = .label
        let item = row(for: indexPath)

        switch item {
        case .ads: configureSwitch(cell, title: "Block ads", on: s.blockAds, tag: item.rawValue)
        case .popups: configureSwitch(cell, title: "Block pop-ups", on: s.blockPopups, tag: item.rawValue)
        case .redirects: configureSwitch(cell, title: "Block suspicious redirects", on: s.blockRedirects, tag: item.rawValue)
        case .trackers: configureSwitch(cell, title: "Prevent common trackers", on: s.preventTracking, tag: item.rawValue)
        case .suspiciousURLs: configureSwitch(cell, title: "Suspicious URL protection", on: s.suspiciousURLProtection, tag: item.rawValue)
        case .privateMode: configureSwitch(cell, title: "Private browsing", on: s.privateMode, tag: item.rawValue)
        case .https: configureSwitch(cell, title: "HTTPS upgrade", on: s.httpsOnly, tag: item.rawValue)
        case .videos: configureSwitch(cell, title: "Auto-detect videos", on: s.autoDetectVideos, tag: item.rawValue)
        case .downloads: configureSwitch(cell, title: "Allow video downloads", on: s.allowDownloads, tag: item.rawValue)
        case .lowMemory:
            configureSwitch(cell, title: "Low-memory mode", on: s.lowMemoryMode, tag: item.rawValue)
            cell.detailTextLabel?.text = ProcessInfo.processInfo.physicalMemory <= 4_000_000_000 ? "Automatically active on this device" : nil
        case .privacyDashboard:
            cell.textLabel?.text = "Privacy dashboard"
            cell.accessoryType = .disclosureIndicator
        case .clearData:
            cell.textLabel?.text = "Clear website data"
            cell.textLabel?.textColor = .systemRed
        case .appLock:
            cell.textLabel?.text = "App Lock"
            cell.detailTextLabel?.text = AppLockManager.shared.enabled ? "Face ID / password enabled" : "Off"
            cell.accessoryType = .disclosureIndicator
        case .customize:
            cell.textLabel?.text = "Customize WebBrowse"
            cell.detailTextLabel?.text = UIApplication.shared.alternateIconName == nil ? "Default icon" : "Custom icon"
            cell.accessoryType = .disclosureIndicator
        }
        return cell
    }

    private func configureSwitch(_ cell: UITableViewCell, title: String, on: Bool, tag: Int) {
        cell.textLabel?.text = title
        let sw = UISwitch()
        sw.tag = tag
        sw.isOn = on
        sw.addTarget(self, action: #selector(toggle(_:)), for: .valueChanged)
        cell.accessoryView = sw
    }

    @objc private func toggle(_ sw: UISwitch) {
        guard let item = Row(rawValue: sw.tag) else { return }
        switch item {
        case .ads: s.blockAds = sw.isOn
        case .popups: s.blockPopups = sw.isOn
        case .redirects: s.blockRedirects = sw.isOn
        case .trackers: s.preventTracking = sw.isOn
        case .suspiciousURLs: s.suspiciousURLProtection = sw.isOn
        case .privateMode: s.privateMode = sw.isOn
        case .https: s.httpsOnly = sw.isOn
        case .videos: s.autoDetectVideos = sw.isOn
        case .downloads: s.allowDownloads = sw.isOn
        case .lowMemory: s.lowMemoryMode = sw.isOn
        case .privacyDashboard, .clearData, .appLock, .customize:
            return
        }
        onChanged?()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch row(for: indexPath) {
        case .privacyDashboard:
            present(UINavigationController(rootViewController: PrivacyDashboardViewController()), animated: true)
        case .clearData:
            clearData()
        case .appLock:
            present(UINavigationController(rootViewController: AppLockSettingsViewController()), animated: true)
        case .customize:
            present(UINavigationController(rootViewController: AppCustomizationViewController()), animated: true)
        default:
            break
        }
    }

    private func clearData() {
        let alert = UIAlertController(title: "Clear website data?", message: "Cookies, caches, local storage and other WebKit website data will be removed.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { _ in
            let types: Set<String> = [
                WKWebsiteDataTypeCookies,
                WKWebsiteDataTypeDiskCache,
                WKWebsiteDataTypeMemoryCache,
                WKWebsiteDataTypeLocalStorage,
                WKWebsiteDataTypeSessionStorage,
                WKWebsiteDataTypeWebSQLDatabases,
                WKWebsiteDataTypeIndexedDBDatabases,
                WKWebsiteDataTypeServiceWorkerRegistrations
            ]
            WKWebsiteDataStore.default().removeData(ofTypes: types, modifiedSince: .distantPast) { }
        })
        present(alert, animated: true)
    }

    private func showError(_ error: Error) {
        let a = UIAlertController(title: "Network setting", message: error.localizedDescription, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    @objc private func done() { dismiss(animated: true) }
}
