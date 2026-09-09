import UIKit

final class PrivacyDashboardViewController: UITableViewController {
    private let settings = BrowserSettings.shared
    private let items = ["Content blocking", "Tracker protection", "Private browsing", "HTTPS upgrade", "Public IP protection"]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Privacy Dashboard"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
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
        default: c.detailTextLabel?.text = "Not connected — WebBrowse does not hide your public IP"
        }
        c.selectionStyle = .none
        return c
    }

    @objc private func done() { dismiss(animated: true) }
}
