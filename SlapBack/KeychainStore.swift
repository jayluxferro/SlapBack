import Foundation
import Security

/// Stores app configuration in the macOS Keychain for secure persistence
final class KeychainStore {
    private static let service = "com.slapback.app"

    static func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        delete(key: key) // Remove existing first
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }

    // MARK: - Config Backup/Restore

    /// Export all UserDefaults settings to Keychain as a JSON blob
    static func backupSettings() -> Bool {
        let keys = [
            "sensitivity", "volume", "cooldown", "soundPack", "bundledPack",
            "bundledFile", "dynamicVolume", "screenFlash", "confetti", "screenShake",
            "showCountInMenuBar", "comboAnnouncer", "usbSounds", "hapticFeedback",
            "hapticPatterns", "idleTaunts", "idleMinutes", "gestureDetection",
            "audioDucking", "focusAwareness", "notifications", "autoCalibrate",
            "slapActions", "slapActionScript"
        ]
        var dict: [String: Any] = [:]
        let ud = UserDefaults.standard
        for key in keys {
            if let val = ud.object(forKey: key) { dict[key] = val }
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let json = String(data: data, encoding: .utf8) else { return false }
        return save(key: "settings_backup", value: json)
    }

    /// Restore settings from Keychain backup
    static func restoreSettings() -> Bool {
        guard let json = load(key: "settings_backup"),
              let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        let ud = UserDefaults.standard
        for (key, value) in dict { ud.set(value, forKey: key) }
        return true
    }
}
