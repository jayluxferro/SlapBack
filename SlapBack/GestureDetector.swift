import Foundation

enum GestureType: String, CaseIterable {
    case single = "Single"
    case doubleTap = "Double Tap"
    case tripleTap = "Triple Tap"
}

/// Detects gesture patterns: single tap, double tap, triple tap
final class GestureDetector {
    var enabled: Bool = false
    var onGesture: ((GestureType) -> Void)?

    private let tapWindow: TimeInterval = 0.4
    private var recentTaps: [TimeInterval] = []
    private var evaluationTimer: Timer?

    func recordTap(at timestamp: TimeInterval) {
        guard enabled else { return }

        recentTaps.append(timestamp)
        evaluationTimer?.invalidate()

        evaluationTimer = Timer.scheduledTimer(withTimeInterval: tapWindow, repeats: false) { [weak self] _ in
            self?.evaluate()
        }
    }

    private func evaluate() {
        let now = ProcessInfo.processInfo.systemUptime
        recentTaps = recentTaps.filter { now - $0 < tapWindow * 2 }

        let type: GestureType
        switch recentTaps.count {
        case 3...: type = .tripleTap
        case 2:    type = .doubleTap
        default:   type = .single
        }

        recentTaps.removeAll()
        onGesture?(type)
    }

    func reset() {
        evaluationTimer?.invalidate()
        recentTaps.removeAll()
    }
}
