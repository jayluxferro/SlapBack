import Foundation
import Combine
import AppKit

@MainActor
final class SlapEngine: ObservableObject {
    @Published var isRunning = false
    @Published var slapCount = 0
    @Published var currentCombo = ComboState.none
    @Published var lastIntensity: SlapIntensity?
    @Published var errorMessage: String?
    @Published var lastGesture: GestureType?
    @Published var menuBarBounce = false

    let reader = AccelerometerReader()
    let detector = SlapDetector()
    let combo = ComboTracker()
    let sound = SoundPlayer()
    let flash = ScreenFlash()
    let confetti = ConfettiManager()
    let screenShake = ScreenShake()
    let usb = USBMonitor()
    let hotkey = GlobalHotkey()
    let actions = SlapActions()
    let stats = SlapStats()
    let haptic = HapticManager()
    let focus = FocusMonitor()
    let idle = IdleTaunts()
    let gesture = GestureDetector()
    let beatbox = BeatboxMode()
    let challenge = SlapChallengeManager()

    var comboAnnouncerEnabled = true
    var audioDuckingEnabled = false

    var availableBundledPacks: [String] { sound.availableBundledPacks }

    init() {
        beatbox.setSoundPlayer(sound)
        idle.focusMonitor = focus

        reader.onSample = { [weak self] sample in
            self?.detector.processSample(sample)
        }

        reader.onError = { [weak self] message in
            Task { @MainActor in
                self?.errorMessage = message
                self?.isRunning = false
            }
        }

        detector.onSlap = { [weak self] event in
            // All UI/audio work dispatched to main thread with weak self
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.focus.isFocusActive { return }

                self.slapCount += 1
                self.lastIntensity = event.intensity
                self.stats.recordSlap(magnitude: event.magnitude)
                self.challenge.recordSlap()
                self.gesture.recordTap(at: event.timestamp)

                self.menuBarBounce = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.menuBarBounce = false
                }

                if self.audioDuckingEnabled { self.focus.duckSystemAudio(duration: 0.4) }

                self.combo.registerHit(at: event.timestamp)
                let comboState = self.combo.currentCombo
                let effectiveCombo = self.comboAnnouncerEnabled ? comboState : .none
                self.sound.play(for: event, combo: effectiveCombo)
                self.flash.flash(intensity: event.intensity)
                self.confetti.trigger(intensity: event.intensity, comboCount: comboState.count)
                self.screenShake.shake(intensity: event.intensity)
                self.haptic.trigger(intensity: event.intensity)
                self.actions.run(intensity: event.intensity)
                self.idle.recordSlap()

                if self.beatbox.isRecordingPattern {
                    self.beatbox.recordBeat(intensity: event.intensity, magnitude: event.magnitude, timestamp: event.timestamp)
                }

                if comboState.count >= 2 {
                    self.haptic.triggerComboPattern(count: comboState.count)
                }
            }
        }

        combo.onComboUpdated = { [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                let previousTier = self.currentCombo.tier
                self.currentCombo = state
                self.stats.recordCombo(state.count)
                self.challenge.recordCombo(state.count)

                // Only announce on tier CHANGE (not every hit)
                if self.comboAnnouncerEnabled && state.tier != .none && state.tier != previousTier {
                    let tier = min(state.count, 9)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                        self?.sound.playComboAnnouncement(tier: tier)
                    }
                }
            }
        }

        gesture.onGesture = { [weak self] type in
            Task { @MainActor in self?.lastGesture = type }
        }

        usb.onDeviceEvent = { [weak self] event in
            guard let self else { return }
            DispatchQueue.main.async {
                guard !self.focus.isFocusActive else { return }
                let name = event == "connected" ? "Blow" : "Basso"
                if let s = NSSound(named: NSSound.Name(name)) {
                    s.volume = self.sound.volume; s.play()
                }
            }
        }

        hotkey.onToggle = { [weak self] in
            Task { @MainActor in self?.toggle() }
        }
        hotkey.register()
    }

    func start() {
        guard !isRunning else { return }
        errorMessage = nil
        detector.reset()
        combo.reset()
        gesture.reset()
        reader.start()
        usb.start()
        idle.start()
        focus.startMonitoring()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        reader.stop()
        sound.stop()
        combo.reset()
        detector.reset()
        idle.stop()
        focus.stopMonitoring()
        beatbox.stopPlayback()
        challenge.cancel()
        gesture.reset()
        isRunning = false
    }

    func toggle() { if isRunning { stop() } else { start() } }
    func resetCount() { slapCount = 0 }

    // MARK: - Apply Settings
    func applySensitivity(_ value: Double) { detector.sensitivity = value }
    func applyCooldown(_ value: Double) { detector.cooldown = value }
    func applyVolume(_ value: Float) { sound.volume = value; idle.volume = value }
    func applySoundPack(_ pack: SoundPack) { sound.selectedPack = pack }
    func applyBundledPack(_ name: String) { sound.selectedBundledPack = name }
    func applyBundledFile(_ name: String) { sound.selectedBundledFile = name }
    func applyDynamicVolume(_ enabled: Bool) { sound.dynamicVolume = enabled }
    func applyScreenFlash(_ enabled: Bool) { flash.enabled = enabled }
    func applyConfetti(_ enabled: Bool) { confetti.enabled = enabled }
    func applyScreenShake(_ enabled: Bool) { screenShake.enabled = enabled }
    func applyComboAnnouncer(_ enabled: Bool) { comboAnnouncerEnabled = enabled }
    func applyUSBSounds(_ enabled: Bool) { usb.enabled = enabled }
    func applyHaptic(_ enabled: Bool) { haptic.enabled = enabled }
    func applyHapticPatterns(_ enabled: Bool) { haptic.patternsEnabled = enabled }
    func applyIdleTaunts(_ enabled: Bool) { idle.enabled = enabled }
    func applyIdleMinutes(_ minutes: Double) { idle.idleMinutes = minutes }
    func applyGestureDetection(_ enabled: Bool) { gesture.enabled = enabled }
    func applyAudioDucking(_ enabled: Bool) { audioDuckingEnabled = enabled }
    func applyFocusAwareness(_ enabled: Bool) { focus.respectFocus = enabled }
    func applyNotifications(_ enabled: Bool) { stats.notificationsEnabled = enabled }
    func applyAutoCalibrate(_ enabled: Bool) { detector.autoCalibrate = enabled }
    func applySlapActions(enabled: Bool, script: String) {
        actions.enabled = enabled; actions.scriptPath = script
    }
    func previewPack(_ name: String) { sound.previewPack(name) }
}
