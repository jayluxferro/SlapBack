import SwiftUI
import Combine
import ServiceManagement

final class SettingsStore: ObservableObject {
    @AppStorage("sensitivity") var sensitivity: Double = 0.2
    @AppStorage("volume") var volume: Double = 0.7
    @AppStorage("cooldown") var cooldown: Double = 0.7
    @AppStorage("soundPack") var soundPackRaw: String = SoundPack.bundled.rawValue
    @AppStorage("bundledPack") var bundledPack: String = "all"
    @AppStorage("bundledFile") var bundledFile: String = ""
    @AppStorage("dynamicVolume") var dynamicVolume: Bool = true
    @AppStorage("screenFlash") var screenFlash: Bool = true
    @AppStorage("confetti") var confetti: Bool = true
    @AppStorage("screenShake") var screenShake: Bool = false
    @AppStorage("showCountInMenuBar") var showCountInMenuBar: Bool = true
    @AppStorage("comboAnnouncer") var comboAnnouncer: Bool = true
    @AppStorage("usbSounds") var usbSounds: Bool = false
    @AppStorage("hapticFeedback") var hapticFeedback: Bool = true
    @AppStorage("idleTaunts") var idleTaunts: Bool = false
    @AppStorage("idleMinutes") var idleMinutes: Double = 5.0
    @AppStorage("gestureDetection") var gestureDetection: Bool = false
    @AppStorage("audioDucking") var audioDucking: Bool = false
    @AppStorage("focusAwareness") var focusAwareness: Bool = true
    @AppStorage("notifications") var notifications: Bool = true
    @AppStorage("slapActions") var slapActionsEnabled: Bool = false
    @AppStorage("slapActionScript") var slapActionScript: String = ""
    @AppStorage("hapticPatterns") var hapticPatterns: Bool = false
    @AppStorage("autoCalibrate") var autoCalibrate: Bool = false
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false

    var soundPack: SoundPack {
        get { SoundPack(rawValue: soundPackRaw) ?? .bundled }
        set { soundPackRaw = newValue.rawValue }
    }

    @MainActor
    func applyAll(to engine: SlapEngine) {
        engine.applySensitivity(sensitivity)
        engine.applyCooldown(cooldown)
        engine.applyVolume(Float(volume))
        engine.applySoundPack(soundPack)
        engine.applyBundledPack(bundledPack)
        engine.applyBundledFile(bundledFile)
        engine.applyDynamicVolume(dynamicVolume)
        engine.applyScreenFlash(screenFlash)
        engine.applyConfetti(confetti)
        engine.applyScreenShake(screenShake)
        engine.applyComboAnnouncer(comboAnnouncer)
        engine.applyUSBSounds(usbSounds)
        engine.applyHaptic(hapticFeedback)
        engine.applyIdleTaunts(idleTaunts)
        engine.applyIdleMinutes(idleMinutes)
        engine.applyGestureDetection(gestureDetection)
        engine.applyAudioDucking(audioDucking)
        engine.applyFocusAwareness(focusAwareness)
        engine.applyNotifications(notifications)
        engine.applyHapticPatterns(hapticPatterns)
        engine.applyAutoCalibrate(autoCalibrate)
        engine.applySlapActions(enabled: slapActionsEnabled, script: slapActionScript)
    }

    func resetToDefaults() {
        sensitivity = 0.2; volume = 0.7; cooldown = 0.7
        soundPackRaw = SoundPack.bundled.rawValue; bundledPack = "all"; bundledFile = ""
        dynamicVolume = true; screenFlash = true; confetti = true; screenShake = false
        showCountInMenuBar = true; comboAnnouncer = true; usbSounds = false
        hapticFeedback = true; idleTaunts = false; idleMinutes = 5.0
        gestureDetection = false; audioDucking = false; focusAwareness = true
        notifications = true; hapticPatterns = false; autoCalibrate = false
        slapActionsEnabled = false; slapActionScript = ""
        objectWillChange.send()
    }

    @MainActor
    func resetToDefaults(applying engine: SlapEngine) {
        resetToDefaults()
        applyAll(to: engine)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = enabled
        if #available(macOS 13.0, *) {
            do {
                if enabled { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch { print("[SlapBack] Login item error: \(error)") }
        }
    }
}
