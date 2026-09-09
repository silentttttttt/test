import UIKit
import LocalAuthentication

final class AppLockViewController: UIViewController, UITextFieldDelegate {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let passwordField = UITextField()
    private let unlockButton = UIButton(type: .system)
    private let faceIDButton = UIButton(type: .system)
    private let errorLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var didAutoAttempt = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        isModalInPresentation = true
        buildUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !didAutoAttempt {
            didAutoAttempt = true
            attemptFaceIDIfAvailable()
        }
    }

    private func buildUI() {
        titleLabel.text = "WebBrowse is Locked"
        titleLabel.font = .preferredFont(forTextStyle: .largeTitle)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        subtitleLabel.text = "Unlock with Face ID or your WebBrowse password."
        subtitleLabel.font = .preferredFont(forTextStyle: .body)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        passwordField.placeholder = "Password"
        passwordField.isSecureTextEntry = true
        passwordField.borderStyle = .roundedRect
        passwordField.returnKeyType = .done
        passwordField.delegate = self
        passwordField.textContentType = .password
        passwordField.accessibilityLabel = "WebBrowse password"

        unlockButton.setTitle("Unlock", for: .normal)
        unlockButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        unlockButton.addTarget(self, action: #selector(unlockPassword), for: .touchUpInside)

        faceIDButton.setTitle("Use Face ID", for: .normal)
        faceIDButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        faceIDButton.addTarget(self, action: #selector(unlockFaceID), for: .touchUpInside)

        errorLabel.textColor = .systemRed
        errorLabel.font = .preferredFont(forTextStyle: .footnote)
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0

        let icon = UIImageView(image: UIImage(systemName: "lock.shield.fill"))
        icon.tintColor = .label
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [icon, titleLabel, subtitleLabel, passwordField, unlockButton, faceIDButton, errorLabel, spinner])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -28),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            icon.heightAnchor.constraint(equalToConstant: 72),
            passwordField.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    private func attemptFaceIDIfAvailable() {
        guard AppLockManager.shared.useFaceID else { return }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else { return }
        unlockFaceID()
    }

    @objc private func unlockFaceID() {
        setBusy(true)
        AppLockManager.shared.unlockWithFaceID(reason: "Unlock WebBrowse to access your browsing data.") { [weak self] success in
            guard let self else { return }
            self.setBusy(false)
            if success {
                self.finishUnlock()
            } else {
                self.errorLabel.text = "Face ID was not completed. You can use your password instead."
            }
        }
    }

    @objc private func unlockPassword() {
        let value = passwordField.text ?? ""
        guard !value.isEmpty else {
            errorLabel.text = "Enter your WebBrowse password."
            return
        }
        if AppLockManager.shared.unlockWithAppPassword(value) {
            finishUnlock()
        } else {
            errorLabel.text = "Incorrect password."
            passwordField.text = ""
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        unlockPassword()
        return true
    }

    private func setBusy(_ busy: Bool) {
        spinner.isHidden = !busy
        busy ? spinner.startAnimating() : spinner.stopAnimating()
        faceIDButton.isEnabled = !busy
        unlockButton.isEnabled = !busy
    }

    private func finishUnlock() {
        dismiss(animated: true)
    }
}
