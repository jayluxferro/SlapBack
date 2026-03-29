import AVFoundation
import AppKit

enum SoundPack: String, CaseIterable, Identifiable {
    case bundled = "Bundled Sounds"
    case speech = "Speech"
    case systemSounds = "System Sounds"
    case custom = "Custom"

    var id: String { rawValue }
}

final class SoundPlayer {
    var volume: Float = 0.7
    var dynamicVolume: Bool = true
    var selectedPack: SoundPack = .bundled
    var selectedBundledPack: String = "all"
    var selectedBundledFile: String = ""

    private let synthesizer = AVSpeechSynthesizer()
    private var playerPool: [AVAudioPlayer] = []
    private let maxPoolSize = 6

    // Bundled sounds: folder name -> [URLs]
    private(set) var bundledSounds: [String: [URL]] = [:]
    private(set) var bundledSoundsLoaded = false

    var availableBundledPacks: [String] {
        bundledSounds.keys
            .filter { !announcementPacks.contains($0) }
            .sorted()
    }

    private let speechPhrases: [SlapIntensity: [String]] = [
        .light: ["Hey!", "Watch it.", "Excuse me?", "Hmm?", "I felt that.", "Easy there.", "Ahem."],
        .medium: ["Ow!", "That hurt!", "What was that for?", "Cut it out!", "Rude.", "Seriously?", "Not cool."],
        .hard: ["OUCH!", "Stop it!", "That's gonna leave a mark!", "This is abuse!", "WHY?!"],
        .extreme: ["HELP!", "I'M DYING!", "CALL 911!", "MAYDAY!", "WHAT DID I EVER DO TO YOU?!"]
    ]

    private let comboPhrases: [ComboTier: [String]] = [
        .double: ["Again?!", "Round two!"],
        .triple: ["Combo!", "A triple!"],
        .mega: ["Mega combo!", "STOP! I YIELD!"],
        .ultra: ["ULTRA COMBO!", "I need a doctor!"],
        .godlike: ["GODLIKE!", "THIS IS MADNESS!"]
    ]

    private let systemSoundMap: [SlapIntensity: [String]] = [
        .light: ["Tink", "Pop", "Morse"],
        .medium: ["Basso", "Frog", "Purr"],
        .hard: ["Funk", "Sosumi", "Blow"],
        .extreme: ["Hero", "Submarine", "Glass"]
    ]

    init() {
        loadBundledSounds()
    }

    func play(for event: SlapEvent, combo: ComboState) {
        let effectiveVolume: Float
        if dynamicVolume {
            // Scale 0.3-1.0 of max volume based on magnitude (0.08-1.0+ range)
            let scale = Float(min(1.0, max(0.3, event.magnitude * 1.5)))
            effectiveVolume = volume * scale
        } else {
            effectiveVolume = volume
        }

        switch selectedPack {
        case .bundled:
            playBundledSound(for: event, volume: effectiveVolume)
        case .speech:
            playSpeech(for: event, combo: combo, volume: effectiveVolume)
        case .systemSounds:
            playSystemSound(for: event, volume: effectiveVolume)
        case .custom:
            playCustomSound(for: event, volume: effectiveVolume)
        }
    }

    func previewPack(_ packName: String) {
        guard let file = candidatesForPack(packName).randomElement() else { return }
        playAudioFile(file, volume: volume)
    }

    func previewFile(_ url: URL) {
        playAudioFile(url, volume: volume)
    }

    func soundFiles(for packName: String) -> [URL] {
        bundledSounds[packName] ?? []
    }

    /// Delete a custom sound pack from Application Support
    static func deleteCustomPack(_ name: String) -> Bool {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let packDir = supportDir.appendingPathComponent("SlapBack/Sounds/\(name)", isDirectory: true)
        do {
            try FileManager.default.removeItem(at: packDir)
            return true
        } catch {
            print("[SlapBack] Failed to delete pack \(name): \(error)")
            return false
        }
    }

    /// List custom packs in Application Support
    static func customPacks() -> [String] {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let soundsDir = supportDir.appendingPathComponent("SlapBack/Sounds", isDirectory: true)
        guard let dirs = try? FileManager.default.contentsOfDirectory(at: soundsDir, includingPropertiesForKeys: [.isDirectoryKey])
            .filter({ (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true })
        else { return [] }
        return dirs.map(\.lastPathComponent).sorted()
    }

    func soundCount(for packName: String) -> Int {
        if packName == "all" {
            return bundledSounds
                .filter { !announcementPacks.contains($0.key) }
                .values.reduce(0) { $0 + $1.count }
        }
        return bundledSounds[packName]?.count ?? 0
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        playerPool.forEach { $0.stop() }
        playerPool.removeAll()
    }

    /// Play a combo tier announcement from the numbered sounds.
    /// Stops any in-flight slap sound so the announcement plays cleanly.
    func playComboAnnouncement(tier: Int) {
        playerPool.forEach { $0.stop() }
        playerPool.removeAll()
        synthesizer.stopSpeaking(at: .immediate)

        let tierStr = "\(tier)"
        if let files = bundledSounds["numbered"]?.filter({ $0.lastPathComponent.hasPrefix("\(tierStr)_") }),
           let file = files.randomElement() {
            playAudioFile(file, volume: volume)
        }
    }

    /// Packs reserved for combo announcements — excluded from "all" rotation
    private let announcementPacks: Set<String> = ["numbered"]

    private func candidatesForPack(_ packName: String) -> [URL] {
        if packName == "all" {
            return bundledSounds
                .filter { !announcementPacks.contains($0.key) }
                .values.flatMap { $0 }
        }
        return bundledSounds[packName] ?? []
    }

    // MARK: - Bundled Sounds

    private func loadBundledSounds() {
        guard let resourcePath = Bundle.main.resourcePath else { return }
        let soundsPath = (resourcePath as NSString).appendingPathComponent("Sounds")
        let fm = FileManager.default
        let audioExtensions = Set(["mp3", "wav", "aiff", "m4a", "caf", "ogg"])

        guard let enumerator = fm.enumerator(atPath: soundsPath) else { return }
        while let relativePath = enumerator.nextObject() as? String {
            let url = URL(fileURLWithPath: soundsPath).appendingPathComponent(relativePath)
            guard audioExtensions.contains(url.pathExtension.lowercased()) else { continue }
            let folder = (relativePath as NSString).deletingLastPathComponent
            guard !folder.isEmpty else { continue }
            bundledSounds[folder, default: []].append(url)
        }
        bundledSoundsLoaded = !bundledSounds.isEmpty
    }

    private func playBundledSound(for event: SlapEvent, volume: Float) {
        guard bundledSoundsLoaded else { playSystemSound(for: event, volume: volume); return }

        if !selectedBundledFile.isEmpty {
            let allFiles = bundledSounds.values.flatMap { $0 }
            if let pinned = allFiles.first(where: { $0.lastPathComponent == selectedBundledFile }) {
                playAudioFile(pinned, volume: volume); return
            }
        }

        let candidates = candidatesForPack(selectedBundledPack)
        guard let file = candidates.randomElement() else { playSystemSound(for: event, volume: volume); return }
        playAudioFile(file, volume: volume)
    }

    // MARK: - Speech

    private func playSpeech(for event: SlapEvent, combo: ComboState, volume: Float) {
        synthesizer.stopSpeaking(at: .immediate)
        let phrase: String
        if combo.tier != .none, let combos = comboPhrases[combo.tier], !combos.isEmpty {
            phrase = combos.randomElement() ?? "Combo!"
        } else if let phrases = speechPhrases[event.intensity], !phrases.isEmpty {
            phrase = phrases.randomElement() ?? "Ow!"
        } else { phrase = "Ow!" }

        let utterance = AVSpeechUtterance(string: phrase)
        utterance.volume = volume
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.1
        if let voice = AVSpeechSynthesisVoice(language: "en-US") { utterance.voice = voice }
        synthesizer.speak(utterance)
    }

    // MARK: - System / Custom

    private func playSystemSound(for event: SlapEvent, volume: Float) {
        guard let soundNames = systemSoundMap[event.intensity], let name = soundNames.randomElement() else { return }
        if let sound = NSSound(named: NSSound.Name(name)) { sound.volume = volume; sound.play() }
    }

    private func playCustomSound(for event: SlapEvent, volume: Float) {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let soundsDir = supportDir.appendingPathComponent("SlapBack/Sounds/\(event.intensity.label)", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(at: soundsDir, includingPropertiesForKeys: nil)
            .filter({ ["aiff", "wav", "mp3", "m4a", "caf"].contains($0.pathExtension.lowercased()) }),
              let file = files.randomElement() else {
            playSpeech(for: event, combo: .none, volume: volume); return
        }
        playAudioFile(file, volume: volume)
    }

    // MARK: - Player Pool

    private func playAudioFile(_ url: URL, volume: Float) {
        // Evict finished players
        playerPool.removeAll { !$0.isPlaying }
        // Evict oldest if pool full
        if playerPool.count >= maxPoolSize {
            playerPool.first?.stop()
            playerPool.removeFirst()
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = volume
            player.play()
            playerPool.append(player)
        } catch {
            print("[SlapBack] Failed to play \(url.lastPathComponent): \(error)")
        }
    }
}
