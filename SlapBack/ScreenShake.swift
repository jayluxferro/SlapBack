import AppKit

/// Shakes the screen content briefly on extreme hits
final class ScreenShake {
    var enabled: Bool = true
    private var isShaking = false

    func shake(intensity: SlapIntensity) {
        guard enabled, intensity >= .hard, !isShaking else { return }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { return }

        DispatchQueue.main.async { [weak self] in
            self?.performShake(intensity: intensity)
        }
    }

    private func performShake(intensity: SlapIntensity) {
        guard !isShaking else { return }
        isShaking = true
        guard NSScreen.main != nil else { isShaking = false; return }
        let amplitude: CGFloat = intensity == .extreme ? 12 : 6
        let shakeCount = intensity == .extreme ? 4 : 2
        let duration: TimeInterval = 0.05

        // Only shake normal-level, non-panel windows that belong to other apps or are untitled
        let windows = NSApplication.shared.windows.filter {
            $0.isVisible && $0.level == .normal && !($0 is NSPanel)
        }

        guard !windows.isEmpty else { isShaking = false; return }

        // Store original positions
        let originals = windows.map { $0.frame.origin }

        // Shake sequence
        for i in 0..<shakeCount {
            let delay = duration * Double(i * 2)
            let dx = (i % 2 == 0) ? amplitude : -amplitude
            let dy = (i % 2 == 0) ? amplitude * 0.5 : -amplitude * 0.5

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                for (idx, window) in windows.enumerated() {
                    var frame = window.frame
                    frame.origin.x = originals[idx].x + dx
                    frame.origin.y = originals[idx].y + dy
                    window.setFrame(frame, display: false)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + duration) { [weak self] in
                for (idx, window) in windows.enumerated() {
                    var frame = window.frame
                    frame.origin = originals[idx]
                    window.setFrame(frame, display: false)
                }
                if i == shakeCount - 1 { self?.isShaking = false }
            }
        }
    }
}
