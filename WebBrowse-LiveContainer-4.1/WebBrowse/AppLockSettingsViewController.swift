import UIKit
import LocalAuthentication

final class AppLockSettingsViewController: UITableViewController {
    private let s = AppLockManager.shared
    private let enabledSwitch = UISwitch()
    private let faceIDSwitch = UISwitch()
    private let backgroundSwitch = UISwitch()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "App Lock"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LockCell")
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 0 ? 2 : 1 }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "Security" : "Lock behavior"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LockCell", for: indexPath)
        cell.accessoryView = nil
        cell.accessoryType = .none
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                cell.textLabel?.text = "App Lock"
                enabledSwitch.isOn = s.enabled
                enabledSwitch.removeTarget(nil, action: nil, for: .valueChanged)
                enabledSwitch.addTarget(self, action: #selector(toggleEnabled(_:)), for: .valueChanged)
                cell.accessoryView = enabledSwitch
            } else {
                cell.textLabel?.text = "Use Face ID"
                faceIDSwitch.isOn = s.useFaceID
                faceIDSwitch.removeTarget(nil, action: nil, for: .valueChanged)
                faceIDSwitch.addTarget(self, action: #selector(toggleFaceID(_:)), for: .valueChanged)
                faceIDSwitch.isEnabled = s.enabled && canUseBiometrics()
                cell.accessoryView = faceIDSwitch
            }
        } else {
            cell.textLabel?.text = "Lock when leaving WebBrowse"
            backgroundSwitch.isOn = s.lockOnBackground
            backgroundSwitch.isEnabled = s.enabled
            backgroundSwitch.removeTarget(nil, action: nil, for: .valueChanged)
            backgroundSwitch.addTarget(self, action: #selector(toggleBackground(_:)), for: .valueChanged)
            cell.accessoryView = backgroundSwitch
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0, indexPath.row == 0 {
            toggleEnabled(enabledSwitch)
        }
        if indexPath.section == 0, indexPath.row == 1 {
            faceIDSwitch.setOn(!faceIDSwitch.isOn, animated: true)
            toggleFaceID(faceIDSwitch)
        }
    }

    @objc private func toggleEnabled(_ control: UISwitch) {
        if control.isOn {
            if s.hasAppPassword() {
                s.enabled = true
                tableView.reloadData()
                return
            }
            control.setOn(false, animated: true)
            askForPassword()
        } else {
            let alert = UIAlertController(title: "Disable App Lock?", message: "Your WebBrowse app password will be removed from the device.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Disable", style: .destructive) { _ in
                self.s.disable()
                self.tableView.reloadData()
            })
            present(alert, animated: true)
        }
    }

    @objc private func toggleFaceID(_ control: UISwitch) {
        guard s.enabled else { control.setOn(false, animated: true); return }
        guard canUseBiometrics() else {
            control.setOn(false, animated: true)
            showError("Face ID is not available on this device right now.")
            return
        }
        s.useFaceID = control.isOn
    }

    @objc private func toggleBackground(_ control: UISwitch) {
        s.lockOnBackground = control.isOn
    }

    private func askForPassword() {
        let alert = UIAlertController(title: "Create WebBrowse Password", message: "Use at least 8 characters. This password is stored as a one-way hash in the device Keychain.", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Password"
            field.isSecureTextEntry = true
            field.textContentType = .newPassword
        }
        alert.addTextField { field in
            field.placeholder = "Confirm password"
            field.isSecureTextEntry = true
            field.textContentType = .newPassword
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Enable", style: .default) { [weak self, weak alert] _ in
            guard let self, let alert else { return }
            let first = alert.textFields?[0].text ?? ""
            let second = alert.textFields?[1].text ?? ""
            guard first.count >= 8, first.count <= 256, first == second else {
                self.showError("Passwords must match and contain 8–256 characters.")
                return
            }
            guard self.s.setAppPassword(first) else {
                self.showError("The password could not be stored securely.")
                return
            }
            self.s.enabled = true
            self.tableView.reloadData()
        })
        present(alert, animated: true)
    }

    private func canUseBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "App Lock", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func done() { dismiss(animated: true) }
}
