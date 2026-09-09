import Foundation
import LocalAuthentication
import Security
import CryptoKit
import UIKit

final class AppLockManager {
    static let shared = AppLockManager()

    private let defaults = UserDefaults.standard
    private let service = "com.example.WebBrowse.app-lock"
    private let account = "app-passcode"
    private let saltAccount = "app-passcode-salt"

    enum Key: String {
        case enabled = "appLockEnabled"
        case useFaceID = "appLockUseFaceID"
        case lockOnBackground = "appLockOnBackground"
    }

    private init() {
        defaults.register(defaults: [
            Key.enabled.rawValue: false,
            Key.useFaceID.rawValue: true,
            Key.lockOnBackground.rawValue: true
        ])
        isLocked = defaults.bool(forKey: Key.enabled.rawValue)
    }

    var enabled: Bool {
        get { defaults.bool(forKey: Key.enabled.rawValue) }
        set { defaults.set(newValue, forKey: Key.enabled.rawValue) }
    }

    var useFaceID: Bool {
        get { defaults.bool(forKey: Key.useFaceID.rawValue) }
        set { defaults.set(newValue, forKey: Key.useFaceID.rawValue) }
    }

    var lockOnBackground: Bool {
        get { defaults.bool(forKey: Key.lockOnBackground.rawValue) }
        set { defaults.set(newValue, forKey: Key.lockOnBackground.rawValue) }
    }

    private(set) var isLocked = false
    private var failedPasswordAttempts = 0
    private var passwordRetryAfter: Date?

    func lockIfNeeded() {
        guard enabled, lockOnBackground else { return }
        isLocked = true
    }

    func unlockWithFaceID(reason: String, completion: @escaping (Bool) -> Void) {
        guard enabled else { completion(true); return }
        guard useFaceID else { completion(false); return }
        let context = LAContext()
        context.localizedCancelTitle = "Use Password"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            completion(false)
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { [weak self] success, _ in
            DispatchQueue.main.async {
                if success {
                    self?.isLocked = false
                }
                completion(success)
            }
        }
    }

    func unlockWithDevicePasscode(reason: String, completion: @escaping (Bool) -> Void) {
        guard enabled else { completion(true); return }
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { [weak self] success, _ in
            DispatchQueue.main.async {
                if success {
                    self?.isLocked = false
                }
                completion(success)
            }
        }
    }

    func unlockWithAppPassword(_ password: String) -> Bool {
        guard enabled else { return true }
        if let retryAfter = passwordRetryAfter, retryAfter > Date() { return false }
        guard let stored = keychainData(account: account),
              let salt = keychainData(account: saltAccount) else { return false }
        guard password.count <= 256 else { return false }
        let candidate = SHA256Hasher.derive(password: password, salt: salt)
        let ok = constantTimeEqual(candidate, stored)
        if ok {
            isLocked = false
            failedPasswordAttempts = 0
            passwordRetryAfter = nil
        } else {
            failedPasswordAttempts += 1
            if failedPasswordAttempts >= 5 {
                let delay = min(60.0, pow(2.0, Double(failedPasswordAttempts - 5)))
                passwordRetryAfter = Date().addingTimeInterval(delay)
            }
        }
        return ok
    }

    private func constantTimeEqual(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var difference: UInt8 = 0
        for (a, b) in zip(lhs, rhs) { difference |= a ^ b }
        return difference == 0
    }

    func hasAppPassword() -> Bool {
        keychainData(account: account) != nil && keychainData(account: saltAccount) != nil
    }

    @discardableResult
    func setAppPassword(_ password: String) -> Bool {
        guard password.count >= 8, password.count <= 256 else { return false }
        var salt = Data(count: 16)
        let result = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, salt.count, $0.baseAddress!) }
        guard result == errSecSuccess else { return false }
        let hash = SHA256Hasher.derive(password: password, salt: salt)
        // Write the hash first. If the second write fails, remove both values so
        // the lock can never be left with a mismatched salt/hash pair.
        guard setKeychainData(hash, account: account) else { return false }
        guard setKeychainData(salt, account: saltAccount) else {
            deleteKeychain(account: account)
            return false
        }
        return true
    }

    func removeAppPassword() {
        deleteKeychain(account: account)
        deleteKeychain(account: saltAccount)
    }

    func disable() {
        enabled = false
        isLocked = false
        failedPasswordAttempts = 0
        passwordRetryAfter = nil
        removeAppPassword()
    }

    private func setKeychainData(_ data: Data, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    private func keychainData(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private func deleteKeychain(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

private enum SHA256Hasher {
    static func derive(password: String, salt: Data) -> Data {
        var input = Data(salt)
        input.append(contentsOf: Data(password.utf8))
        var digest = Data(SHA256.hash(data: input))
        for _ in 0..<100_000 {
            digest = Data(SHA256.hash(data: digest + salt))
        }
        return digest
    }
}
