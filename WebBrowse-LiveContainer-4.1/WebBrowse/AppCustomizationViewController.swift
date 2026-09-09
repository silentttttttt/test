import UIKit

final class AppCustomizationViewController: UITableViewController {
    private let icons = [
        (nil, "WebBrowse Default", "Default app icon"),
        ("AppIconMidnight", "Midnight", "Dark blue WebBrowse icon"),
        ("AppIconOcean", "Ocean", "Blue WebBrowse icon"),
        ("AppIconSunset", "Sunset", "Warm WebBrowse icon"),
        ("AppIconForest", "Forest", "Green WebBrowse icon"),
        ("AppIconCustom", "Custom", "Replace the bundled Custom icon with your own 1024×1024 PNG")
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Customize WebBrowse"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "IconCell")
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { icons.count }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { "App Icon" }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "IconCell", for: indexPath)
        let item = icons[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = item.1
        content.secondaryText = item.2
        if let name = item.0, let image = UIImage(named: name) {
            content.image = image
        } else {
            content.image = UIImage(named: "AppIcon") ?? UIImage(systemName: "app.fill")
        }
        content.imageProperties.maximumSize = CGSize(width: 44, height: 44)
        cell.contentConfiguration = content
        cell.accessoryType = UIApplication.shared.alternateIconName == item.0 ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let iconName = icons[indexPath.row].0
        guard UIApplication.shared.supportsAlternateIcons else {
            showError("This iOS build does not allow alternate app icons.")
            return
        }
        UIApplication.shared.setAlternateIconName(iconName) { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.showError(error.localizedDescription)
                } else {
                    self?.tableView.reloadData()
                }
            }
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Icon change failed", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func done() { dismiss(animated: true) }
}
