import AVFoundation
import Foundation

/// Detects slap rhythm and loops it as a beat pattern
final class BeatboxMode: ObservableObject {
    @Published var isRecordingPattern = false
    @Published var isPlaying = false
    @Published var patternLength: Int = 0

    var enabled: Bool = false
    var bpm: Double = 120

    private var pattern: [(timeOffset: TimeInterval, intensity: SlapIntensity, magnitude: Double)] = []
    private var recordStartTime: TimeInterval = 0
    private var loopTimer: Timer?
    private var soundPlayer: SoundPlayer?

    deinit { stopPlayback() }

    func setSoundPlayer(_ player: SoundPlayer) {
        self.soundPlayer = player
    }

    func startRecording() {
        pattern.removeAll()
        recordStartTime = ProcessInfo.processInfo.systemUptime
        isRecordingPattern = true
        patternLength = 0
    }

    func stopRecording() {
        isRecordingPattern = false
        patternLength = pattern.count
    }

    func recordBeat(intensity: SlapIntensity, magnitude: Double, timestamp: TimeInterval) {
        guard isRecordingPattern else { return }
        let offset = timestamp - recordStartTime
        DispatchQueue.main.async {
            self.pattern.append((timeOffset: offset, intensity: intensity, magnitude: magnitude))
            self.patternLength = self.pattern.count
        }
    }

    func startPlayback() {
        guard !pattern.isEmpty else { return }
        isPlaying = true
        loopPattern()
    }

    func stopPlayback() {
        isPlaying = false
        loopTimer?.invalidate()
        loopTimer = nil
    }

    private func loopPattern() {
        guard isPlaying, !pattern.isEmpty else { return }

        let loopDuration = pattern.last?.timeOffset ?? 1.0
        let combo = ComboState.none

        for beat in pattern {
            DispatchQueue.main.asyncAfter(deadline: .now() + beat.timeOffset) { [weak self] in
                guard let self, self.isPlaying else { return }
                let event = SlapEvent(intensity: beat.intensity, magnitude: beat.magnitude, timestamp: ProcessInfo.processInfo.systemUptime)
                self.soundPlayer?.play(for: event, combo: combo)
            }
        }

        // Schedule next loop
        loopTimer = Timer.scheduledTimer(withTimeInterval: loopDuration + 0.1, repeats: false) { [weak self] _ in
            self?.loopPattern()
        }
    }
}
