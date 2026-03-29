import Foundation

/// Timed slap challenges with goals
struct Challenge: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let targetSlaps: Int
    let targetCombo: Int
    let timeLimit: TimeInterval // seconds

    static let presets: [Challenge] = [
        Challenge(name: "Warmup", description: "10 slaps in 30 seconds", targetSlaps: 10, targetCombo: 0, timeLimit: 30),
        Challenge(name: "Combo King", description: "Hit a 5x combo", targetSlaps: 0, targetCombo: 5, timeLimit: 60),
        Challenge(name: "Speed Demon", description: "20 slaps in 15 seconds", targetSlaps: 20, targetCombo: 0, timeLimit: 15),
        Challenge(name: "Berserker", description: "50 slaps in 60 seconds", targetSlaps: 50, targetCombo: 0, timeLimit: 60),
        Challenge(name: "Combo Master", description: "Hit a 10x combo", targetSlaps: 0, targetCombo: 10, timeLimit: 120),
        Challenge(name: "Lightning", description: "30 slaps in 10 seconds", targetSlaps: 30, targetCombo: 0, timeLimit: 10),
    ]
}

final class SlapChallengeManager: ObservableObject {
    @Published var activeChallenge: Challenge?
    @Published var isRunning = false
    @Published var timeRemaining: TimeInterval = 0
    @Published var currentSlaps: Int = 0
    @Published var currentMaxCombo: Int = 0
    @Published var result: ChallengeResult?

    enum ChallengeResult {
        case success
        case failure
    }

    private var timer: Timer?

    deinit { timer?.invalidate() }

    func start(challenge: Challenge) {
        activeChallenge = challenge
        isRunning = true
        currentSlaps = 0
        currentMaxCombo = 0
        timeRemaining = challenge.timeLimit
        result = nil

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, self.isRunning else { return }
            self.timeRemaining -= 0.1
            if self.timeRemaining <= 0 {
                self.finish(success: false)
            }
        }
    }

    func recordSlap() {
        guard isRunning else { return }
        currentSlaps += 1
        checkWin()
    }

    func recordCombo(_ count: Int) {
        guard isRunning else { return }
        if count > currentMaxCombo { currentMaxCombo = count }
        checkWin()
    }

    func cancel() {
        timer?.invalidate()
        isRunning = false
        activeChallenge = nil
        result = nil
    }

    private func checkWin() {
        guard let challenge = activeChallenge else { return }
        var won = true
        if challenge.targetSlaps > 0 && currentSlaps < challenge.targetSlaps { won = false }
        if challenge.targetCombo > 0 && currentMaxCombo < challenge.targetCombo { won = false }
        if won { finish(success: true) }
    }

    private func finish(success: Bool) {
        timer?.invalidate()
        isRunning = false
        result = success ? .success : .failure
    }
}
