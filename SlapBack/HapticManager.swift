import AppKit

/// Triggers Force Touch trackpad haptic feedback on slap detection.
/// Supports morse-like patterns for accessibility.
final class HapticManager {
    var enabled: Bool = true
    var patternsEnabled: Bool = false

    func trigger(intensity: SlapIntensity) {
        guard enabled else { return }

        if patternsEnabled {
            triggerPattern(intensity: intensity)
        } else {
            triggerSingle(intensity: intensity)
        }
    }

    func triggerComboPattern(count: Int) {
        guard enabled, patternsEnabled else { return }
        // Rapid-fire haptics for combo count
        for i in 0..<min(count, 5) {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
        }
    }

    private func triggerSingle(intensity: SlapIntensity) {
        let pattern: NSHapticFeedbackManager.FeedbackPattern
        switch intensity {
        case .light:   pattern = .generic
        case .medium:  pattern = .levelChange
        case .hard:    pattern = .alignment
        case .extreme: pattern = .alignment
        }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }

    /// Morse-style pattern: short-long for intensity levels
    /// Light = dot, Medium = dash, Hard = dot-dot-dash, Extreme = dash-dash-dash
    private func triggerPattern(intensity: SlapIntensity) {
        let pattern: [(NSHapticFeedbackManager.FeedbackPattern, TimeInterval)]
        switch intensity {
        case .light:
            pattern = [(.generic, 0)]
        case .medium:
            pattern = [(.alignment, 0)]
        case .hard:
            pattern = [(.generic, 0), (.generic, 0.08), (.alignment, 0.16)]
        case .extreme:
            pattern = [(.alignment, 0), (.alignment, 0.1), (.alignment, 0.2)]
        }
        for (feedback, delay) in pattern {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                NSHapticFeedbackManager.defaultPerformer.perform(feedback, performanceTime: .now)
            }
        }
    }
}
