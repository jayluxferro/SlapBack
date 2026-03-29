import AVFoundation
import Foundation

/// Plays taunting phrases after a period of no slaps
final class IdleTaunts {
    var enabled: Bool = false
    var idleMinutes: Double = 5.0
    var volume: Float = 0.6
    weak var focusMonitor: FocusMonitor?

    private var timer: Timer?
    private var lastSlapTime: Date = Date()
    private let synthesizer = AVSpeechSynthesizer()

    private let taunts = [
        "Is that all you've got?",
        "I'm getting bored over here.",
        "Hello? Anyone there?",
        "You call yourself a slapper?",
        "I've felt stronger breezes.",
        "Come on, hit me!",
        "Sleeping on the job?",
        "I thought we were having fun.",
        "Don't be shy!",
        "My grandma slaps harder than you.",
    ]

    func start() {
        timer?.invalidate()
        lastSlapTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.checkIdle()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    func recordSlap() {
        lastSlapTime = Date()
    }

    private func checkIdle() {
        guard enabled else { return }
        if let focus = focusMonitor, focus.isFocusActive { return }
        let elapsed = Date().timeIntervalSince(lastSlapTime)
        if elapsed > idleMinutes * 60 {
            playTaunt()
            lastSlapTime = Date() // Reset so we don't spam
        }
    }

    private func playTaunt() {
        guard let phrase = taunts.randomElement() else { return }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: phrase)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        utterance.volume = volume
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }
        synthesizer.speak(utterance)
    }
}
