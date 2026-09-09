import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var privacyShield: UIView?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: ws)
        window.rootViewController = BrowserViewController()
        self.window = window
        window.makeKeyAndVisible()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        addPrivacyShield()
        AppLockManager.shared.lockIfNeeded()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        privacyShield?.removeFromSuperview()
        privacyShield = nil
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        guard AppLockManager.shared.enabled else {
            removePrivacyShield()
            return
        }
        if AppLockManager.shared.isLocked {
            presentLockIfNeeded()
        } else {
            removePrivacyShield()
        }
    }

    private func presentLockIfNeeded() {
        guard let root = window?.rootViewController else { return }
        if root.presentedViewController is AppLockViewController { return }
        let lock = AppLockViewController()
        lock.modalPresentationStyle = .fullScreen
        root.present(lock, animated: false) { [weak self] in
            self?.removePrivacyShield()
        }
    }

    private func addPrivacyShield() {
        guard let window, privacyShield == nil else { return }
        let shield = UIView(frame: window.bounds)
        shield.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        shield.backgroundColor = .systemBackground
        let icon = UIImageView(image: UIImage(systemName: "lock.shield.fill"))
        icon.tintColor = .secondaryLabel
        icon.translatesAutoresizingMaskIntoConstraints = false
        shield.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: shield.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: shield.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 54),
            icon.heightAnchor.constraint(equalToConstant: 54)
        ])
        window.addSubview(shield)
        privacyShield = shield
    }

    private func removePrivacyShield() {
        privacyShield?.removeFromSuperview()
        privacyShield = nil
    }
}
