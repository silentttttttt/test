import UIKit
import NetworkExtension

final class PrivacyDashboardViewController: UITableViewController {
    private let settings = BrowserSettings.shared
    private var dnsEnabled = false
    private var vpnStatus = "Not connected"
    private let items = ["Content blocking", "Tracker protection", "Private browsing", "HTTPS upgrade", "Encrypted DNS", "Public IP protection"]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Privacy Dashboard"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
        DNSManager.shared.isEnabled { [weak self] enabled in
            DispatchQueue.main.async { self?.dnsEnabled = enabled; self?.refreshVPNStatus() }
        }
        refreshVPNStatus()
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { items.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        c.textLabel?.text = items[indexPath.row]
        switch indexPath.row {
        case 0: c.detailTextLabel?.text = settings.blockAds ? "Active" : "Off"
        case 1: c.detailTextLabel?.text = settings.preventTracking ? "Active" : "Off"
        case 2: c.detailTextLabel?.text = settings.privateMode ? "Non-persistent WebKit storage" : "Persistent storage"
        case 3: c.detailTextLabel?.text = settings.httpsOnly ? "Enabled" : "Disabled"
        case 4: c.detailTextLabel?.text = dnsEnabled ? "System DNS profile enabled" : "Not enabled"
        default: c.detailTextLabel?.text = vpnStatus == "Connected" ? "Connected — traffic is using the configured tunnel" : "Not connected — DNS alone cannot hide your public IP"
        }
        c.selectionStyle = .none
        return c
    }

    private func refreshVPNStatus() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, _ in
            let connected = managers?.contains { manager in
                let providerID = manager.protocolConfiguration?.providerBundleIdentifier
                return providerID == "com.example.WebBrowse.PacketTunnel" && manager.connection.status == .connected
            } ?? false
            DispatchQueue.main.async {
                self?.vpnStatus = connected ? "Connected" : "Not connected"
                self?.tableView.reloadData()
            }
        }
    }

    @objc private func done() { dismiss(animated: true) }
}
