import AppKit

/// Monitors macOS Focus/DND state with async caching. Provides audio ducking.
final class FocusMonitor {
    var respectFocus: Bool = true
    private var cachedFocusActive: Bool = false
    private var cacheTimer: Timer?

    var isFocusActive: Bool {
        guard respectFocus else { return false }
        return cachedFocusActive
    }

    func startMonitoring() {
        cacheTimer?.invalidate()
        updateCache()
        cacheTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateCache()
        }
    }

    func stopMonitoring() {
        cacheTimer?.invalidate()
        cacheTimer = nil
    }

    private func updateCache() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let active = Self.checkFocusState()
            DispatchQueue.main.async { self?.cachedFocusActive = active }
        }
    }

    private static func checkFocusState() -> Bool {
        // Read the Focus state from ControlCenter defaults (cached read, no subprocess)
        let defaults = UserDefaults(suiteName: "com.apple.controlcenter")
        return defaults?.bool(forKey: "NSStatusItem Visible FocusModes") == true
    }

    /// Briefly duck system audio volume, then restore
    func duckSystemAudio(duration: TimeInterval = 0.4) {
        DispatchQueue.global(qos: .utility).async {
            let script = """
            set curVol to output volume of (get volume settings)
            set volume output volume (curVol * 0.3)
            delay \(duration)
            set volume output volume curVol
            """
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
        }
    }

    deinit { stopMonitoring() }
}
