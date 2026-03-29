import Foundation

struct ComboState {
    let count: Int
    let tier: ComboTier

    static let none = ComboState(count: 0, tier: .none)
}

enum ComboTier: String {
    case none = ""
    case double = "Double!"
    case triple = "Triple!"
    case mega = "Mega!"
    case ultra = "Ultra!"
    case godlike = "GODLIKE!"

    static func from(count: Int) -> ComboTier {
        switch count {
        case 0...1: return .none
        case 2: return .double
        case 3: return .triple
        case 4...6: return .mega
        case 7...9: return .ultra
        default: return .godlike
        }
    }
}

final class ComboTracker {
    /// Time window for consecutive hits to count as a combo
    var comboWindow: TimeInterval = 2.0

    var onComboUpdated: ((ComboState) -> Void)?

    private var hitCount: Int = 0
    private var lastHitTime: TimeInterval = 0
    private var comboResetTimer: Timer?

    var currentCombo: ComboState {
        ComboState(count: hitCount, tier: ComboTier.from(count: hitCount))
    }

    func registerHit(at timestamp: TimeInterval) {
        comboResetTimer?.invalidate()

        if timestamp - lastHitTime > comboWindow {
            hitCount = 0
        }

        hitCount += 1
        lastHitTime = timestamp

        let state = currentCombo
        onComboUpdated?(state)

        // Schedule reset
        comboResetTimer = Timer.scheduledTimer(withTimeInterval: comboWindow, repeats: false) { [weak self] _ in
            self?.hitCount = 0
            self?.onComboUpdated?(ComboState.none)
        }
    }

    func reset() {
        comboResetTimer?.invalidate()
        hitCount = 0
        lastHitTime = 0
        onComboUpdated?(ComboState.none)
    }
}
