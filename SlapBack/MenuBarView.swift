import SwiftUI

struct MenuBarView: View {
    @ObservedObject var engine: SlapEngine
    @ObservedObject var settings: SettingsStore

    var body: some View {
        // Status
        HStack {
            Circle()
                .fill(engine.isRunning ? .green : .gray)
                .frame(width: 8, height: 8)
            Text(engine.isRunning ? "Listening" : "Paused")
                .font(.headline)
            Spacer()
            if engine.currentCombo.tier != .none {
                Text("\(engine.currentCombo.count)x \(engine.currentCombo.tier.rawValue)")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)

        HStack {
            Label("\(engine.slapCount) slaps", systemImage: "hand.raised")
                .font(.subheadline)
            Spacer()
            if let intensity = engine.lastIntensity {
                Text(intensity.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)

        if let error = engine.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.horizontal, 12)
        }

        Divider()

        // Sliders
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "dial.low")
                    .frame(width: 16)
                    .help("Sensitivity")
                Slider(value: $settings.sensitivity, in: 0...1)
                Text(sensitivityLabel)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .trailing)
            }
            .onChange(of: settings.sensitivity) { _, v in
                engine.applySensitivity(v)
            }
            HStack {
                Image(systemName: "speaker.wave.2")
                    .frame(width: 16)
                    .help("Volume")
                Slider(value: $settings.volume, in: 0...1)
                Text(String(format: "%.0f%%", settings.volume * 100))
                    .font(.caption)
                    .monospacedDigit()
                    .frame(width: 32, alignment: .trailing)
            }
            .onChange(of: settings.volume) { _, v in
                engine.applyVolume(Float(v))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)

        Divider()

        // Sound pack submenu
        Menu("Sound: \(currentPackLabel)") {
            Menu("Bundled Sounds") {
                Button { selectBundledPack("all") } label: {
                    if settings.soundPack == .bundled && settings.bundledPack == "all" { Image(systemName: "checkmark") }
                    Text("All Packs")
                }
                Divider()
                ForEach(engine.availableBundledPacks, id: \.self) { pack in
                    Button { selectBundledPack(pack) } label: {
                        if settings.soundPack == .bundled && settings.bundledPack == pack { Image(systemName: "checkmark") }
                        Text("\(pack.capitalized) (\(engine.sound.soundCount(for: pack)))")
                    }
                }
            }
            Divider()
            Button { settings.soundPack = .speech; engine.applySoundPack(.speech) } label: {
                if settings.soundPack == .speech { Image(systemName: "checkmark") }
                Text("Speech (text-to-speech voices)")
            }
            Button { settings.soundPack = .systemSounds; engine.applySoundPack(.systemSounds) } label: {
                if settings.soundPack == .systemSounds { Image(systemName: "checkmark") }
                Text("System Sounds (macOS built-in)")
            }
            Button { settings.soundPack = .custom; engine.applySoundPack(.custom) } label: {
                if settings.soundPack == .custom { Image(systemName: "checkmark") }
                Text("Custom (your own audio files)")
            }
        }

        Divider()

        // Toggles
        Toggle("Screen Flash", isOn: $settings.screenFlash)
            .onChange(of: settings.screenFlash) { _, v in engine.applyScreenFlash(v) }
        Toggle("Confetti", isOn: $settings.confetti)
            .onChange(of: settings.confetti) { _, v in engine.applyConfetti(v) }
        Toggle("Combo Announcer", isOn: $settings.comboAnnouncer)
            .onChange(of: settings.comboAnnouncer) { _, v in engine.applyComboAnnouncer(v) }
        Toggle("USB Sounds", isOn: $settings.usbSounds)
            .onChange(of: settings.usbSounds) { _, v in engine.applyUSBSounds(v) }

        Divider()

        Button(engine.isRunning ? "Pause Detection" : "Start Detection") {
            engine.toggle()
        }
        .keyboardShortcut("s")

        Button("Reset Count") { engine.resetCount() }

        Divider()

        Button("Settings...") {
            openSettingsWindow()
        }
        .keyboardShortcut(",")

        Button("Quit SlapBack") {
            engine.stop()
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private var sensitivityLabel: String {
        switch settings.sensitivity {
        case 0..<0.2: return "Hard only"
        case 0.2..<0.4: return "Low"
        case 0.4..<0.6: return "Medium"
        case 0.6..<0.8: return "High"
        default: return "Very high"
        }
    }

    private var currentPackLabel: String {
        switch settings.soundPack {
        case .bundled:
            return settings.bundledPack == "all" ? "All" : settings.bundledPack.capitalized
        case .speech: return "Speech"
        case .systemSounds: return "System"
        case .custom: return "Custom"
        }
    }

    private func openSettingsWindow() {
        WindowManager.shared.openSwiftUI(
            id: "settings", title: "SlapBack Settings",
            width: 600, height: 500,
            view: SettingsView(engine: engine, settings: settings)
        )
    }

    private func selectBundledPack(_ name: String) {
        settings.soundPack = .bundled
        settings.bundledPack = name
        settings.bundledFile = ""
        engine.applySoundPack(.bundled)
        engine.applyBundledPack(name)
        engine.applyBundledFile("")
    }
}
