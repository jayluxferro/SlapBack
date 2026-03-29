import SwiftUI
import UniformTypeIdentifiers

enum SettingsPage: String, CaseIterable {
    case general = "General"
    case sound = "Sound"
    case effects = "Effects"
    case fun = "Fun"
    case stats = "Stats"
    case advanced = "Advanced"

    var icon: String {
        switch self {
        case .general:  return "gear"
        case .sound:    return "speaker.wave.2"
        case .effects:  return "sparkles"
        case .fun:      return "gamecontroller"
        case .stats:    return "chart.bar"
        case .advanced: return "wrench.and.screwdriver"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var engine: SlapEngine
    @ObservedObject var settings: SettingsStore
    @State private var selectedPage: SettingsPage = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsPage.allCases, id: \.self, selection: $selectedPage) { page in
                Label(page.rawValue, systemImage: page.icon)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 140, ideal: 160, max: 180)
        } detail: {
            ScrollView {
                detailView
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(selectedPage.rawValue)
        }
        .frame(width: 600, height: 500)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedPage {
        case .general:  GeneralTab(engine: engine, settings: settings)
        case .sound:    SoundTab(engine: engine, settings: settings)
        case .effects:  FeedbackTab(engine: engine, settings: settings)
        case .fun:      FunTab(engine: engine, challenge: engine.challenge, beatbox: engine.beatbox)
        case .stats:    StatsTab(stats: engine.stats)
        case .advanced: AdvancedTab(engine: engine, settings: settings)
        }
    }
}

// MARK: - General

private struct GeneralTab: View {
    @ObservedObject var engine: SlapEngine
    @ObservedObject var settings: SettingsStore
    @State private var showResetConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Detection") {
                VStack(spacing: 10) {
                    LabeledSlider(label: "Sensitivity", value: $settings.sensitivity,
                                  range: 0...1, trailing: sensitivityLabel) {
                        engine.applySensitivity(settings.sensitivity)
                    }
                    LabeledSlider(label: "Cooldown", value: $settings.cooldown,
                                  range: 0.3...2.0, trailing: String(format: "%.1fs", settings.cooldown)) {
                        engine.applyCooldown(settings.cooldown)
                    }
                    Toggle("Auto-calibrate (learns your pattern)", isOn: $settings.autoCalibrate)
                        .onChange(of: settings.autoCalibrate) { _, v in engine.applyAutoCalibrate(v) }
                    Toggle("Gesture detection (double/triple tap)", isOn: $settings.gestureDetection)
                        .onChange(of: settings.gestureDetection) { _, v in engine.applyGestureDetection(v) }
                    Button("Run Calibration Wizard...") { openCalibrationWindow() }
                        .controlSize(.small)
                }
                .padding(6)
            }

            GroupBox("System") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Show slap count in menu bar", isOn: $settings.showCountInMenuBar)
                    Toggle("Mute when Focus/DND is active", isOn: $settings.focusAwareness)
                        .onChange(of: settings.focusAwareness) { _, v in engine.applyFocusAwareness(v) }
                    Toggle("Launch at login", isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { settings.setLaunchAtLogin($0) }
                    ))
                }
                .padding(6)
            }

            HStack {
                Spacer()
                Button("Reset All to Defaults") { showResetConfirm = true }
                    .foregroundStyle(.red).controlSize(.small)
            }
            .alert("Reset Settings?", isPresented: $showResetConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) { settings.resetToDefaults(applying: engine) }
            } message: {
                Text("This will reset all settings to their default values.")
            }

            Spacer()
        }
        .padding()
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

    private func openCalibrationWindow() {
        WindowManager.shared.openSwiftUI(
            id: "calibration", title: "Calibration Wizard",
            width: 420, height: 340,
            view: CalibrationView(engine: engine, settings: settings)
        )
    }
}

// MARK: - Sound

private struct SoundTab: View {
    @ObservedObject var engine: SlapEngine
    @ObservedObject var settings: SettingsStore
    @State private var importMessage = ""
    @State private var selectedIntensity = "Light"
    @State private var customPacks: [String] = SoundPlayer.customPacks()
    private let intensityFolders = ["Light", "Medium", "Hard", "Extreme"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Playback") {
                VStack(spacing: 10) {
                    LabeledSlider(label: "Volume", value: $settings.volume,
                                  range: 0...1, trailing: String(format: "%.0f%%", settings.volume * 100)) {
                        engine.applyVolume(Float(settings.volume))
                    }
                    Toggle("Dynamic volume (harder slaps play louder)", isOn: $settings.dynamicVolume)
                        .onChange(of: settings.dynamicVolume) { _, v in engine.applyDynamicVolume(v) }
                }
                .padding(6)
            }

            GroupBox("Sound Pack") {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("", selection: Binding(
                        get: { settings.soundPack },
                        set: { settings.soundPack = $0; engine.applySoundPack($0) }
                    )) {
                        Text("Bundled — pre-loaded packs (punch, sexy, goat, etc.)").tag(SoundPack.bundled)
                        Text("Speech — computer-generated voice reactions").tag(SoundPack.speech)
                        Text("System — macOS alert sounds (Basso, Funk, etc.)").tag(SoundPack.systemSounds)
                        Text("Custom — your own audio files").tag(SoundPack.custom)
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }
                .padding(6)
            }

            if settings.soundPack == .bundled {
                GroupBox("Bundled Pack") {
                    ScrollView {
                        VStack(spacing: 4) {
                            packRow(name: "all", display: "All Packs")
                            ForEach(engine.availableBundledPacks, id: \.self) { pack in
                                packRow(name: pack, display: pack.capitalized)
                            }
                        }
                        .padding(4)
                    }
                    .frame(maxHeight: 120)
                }

                // Individual sound file selection within the chosen pack
                if settings.bundledPack != "all" {
                    GroupBox("Sound — \(settings.bundledPack.capitalized)") {
                        VStack(alignment: .leading, spacing: 4) {
                            // Random option
                            HStack {
                                Button {
                                    settings.bundledFile = ""
                                    engine.applyBundledFile("")
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: settings.bundledFile.isEmpty ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(settings.bundledFile.isEmpty ? .blue : .secondary)
                                            .frame(width: 16)
                                        Text("Random (any from pack)")
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .buttonStyle(.plain)
                            }

                            Divider()

                            // Individual files
                            ScrollView(.vertical, showsIndicators: true) {
                                VStack(spacing: 3) {
                                    let files = engine.sound.soundFiles(for: settings.bundledPack)
                                        .sorted { $0.lastPathComponent < $1.lastPathComponent }
                                    ForEach(files, id: \.lastPathComponent) { file in
                                        let name = file.deletingPathExtension().lastPathComponent
                                        let isSelected = settings.bundledFile == file.lastPathComponent
                                        HStack(spacing: 8) {
                                            Button {
                                                settings.bundledFile = file.lastPathComponent
                                                engine.applyBundledFile(file.lastPathComponent)
                                            } label: {
                                                HStack(spacing: 6) {
                                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                                        .foregroundStyle(isSelected ? .blue : .secondary)
                                                        .frame(width: 16)
                                                    Text(name)
                                                        .font(.caption)
                                                        .lineLimit(1)
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                }
                                            }
                                            .buttonStyle(.plain)

                                            Button { engine.sound.previewFile(file) } label: {
                                                Image(systemName: "play.circle")
                                                    .font(.system(size: 14))
                                            }
                                            .buttonStyle(.plain)
                                            .help("Preview this sound")
                                        }
                                        .padding(.trailing, 12) // Space for scrollbar
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                            .frame(maxHeight: 130)
                        }
                        .padding(4)
                    }
                }
            }

            if settings.soundPack == .custom {
                GroupBox("Custom Sounds") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add your own .mp3, .wav, or .aiff files organized by intensity folder.")
                            .font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Picker("Intensity:", selection: $selectedIntensity) {
                                ForEach(intensityFolders, id: \.self) { Text($0) }
                            }
                            .frame(width: 200)
                            Button("Browse & Add Files...") { browseAndAddFiles() }
                            Button("Import .zip Pack...") {
                                SoundPackImporter.showImportDialog { _, msg in
                                    importMessage = msg
                                    customPacks = SoundPlayer.customPacks()
                                }
                            }
                            Button("Open Folder") { openSoundsFolder() }
                                .controlSize(.small)
                        }
                        if !importMessage.isEmpty {
                            Text(importMessage).font(.caption).foregroundStyle(.green)
                        }
                        if !customPacks.isEmpty {
                            Divider()
                            Text("Installed custom packs:").font(.caption).foregroundStyle(.secondary)
                            ForEach(customPacks, id: \.self) { pack in
                                HStack {
                                    Text(pack).font(.caption)
                                    Spacer()
                                    Button("Delete") {
                                        if SoundPlayer.deleteCustomPack(pack) {
                                            customPacks = SoundPlayer.customPacks()
                                        }
                                    }
                                    .foregroundStyle(.red).controlSize(.mini)
                                }
                            }
                        }
                    }
                    .padding(6)
                }
            }

            Spacer()
        }
        .padding()
    }

    private func packRow(name: String, display: String) -> some View {
        HStack {
            Button {
                settings.bundledPack = name; settings.bundledFile = ""
                engine.applyBundledPack(name); engine.applyBundledFile("")
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: settings.bundledPack == name ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(settings.bundledPack == name ? .blue : .secondary)
                        .frame(width: 16)
                    Text(display)
                    Spacer()
                    Text("\(engine.sound.soundCount(for: name))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Button { engine.previewPack(name) } label: {
                Image(systemName: "play.circle").font(.caption)
            }
            .buttonStyle(.plain).help("Preview")
        }
        .padding(.vertical, 2)
    }

    private func browseAndAddFiles() {
        let intensity = selectedIntensity
        let panel = NSOpenPanel()
        panel.title = "Select Audio Files"
        panel.allowedContentTypes = [.audio, .mp3, .wav, .aiff]
        panel.allowsMultipleSelection = true
        panel.begin { response in
            guard response == .OK, !panel.urls.isEmpty else { return }
            let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
            let destDir = supportDir.appendingPathComponent("SlapBack/Sounds/\(intensity)", isDirectory: true)
            try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
            let audioExts = Set(["mp3", "wav", "aiff", "m4a", "caf", "ogg"])
            var count = 0
            for url in panel.urls {
                guard audioExts.contains(url.pathExtension.lowercased()) else { continue }
                let dest = destDir.appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.removeItem(at: dest)
                try? FileManager.default.copyItem(at: url, to: dest)
                count += 1
            }
            importMessage = "Added \(count) file(s) to \(intensity) custom sounds"
        }
    }

    private func openSoundsFolder() {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let soundsDir = supportDir.appendingPathComponent("SlapBack/Sounds", isDirectory: true)
        for f in ["Light", "Medium", "Hard", "Extreme"] {
            try? FileManager.default.createDirectory(at: soundsDir.appendingPathComponent(f), withIntermediateDirectories: true)
        }
        NSWorkspace.shared.open(soundsDir)
    }
}

// MARK: - Feedback / Effects

private struct FeedbackTab: View {
    @ObservedObject var engine: SlapEngine
    @ObservedObject var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Visual") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Screen flash on slap", isOn: $settings.screenFlash)
                        .onChange(of: settings.screenFlash) { _, v in engine.applyScreenFlash(v) }
                    Toggle("Confetti on hard hits & combos", isOn: $settings.confetti)
                        .onChange(of: settings.confetti) { _, v in engine.applyConfetti(v) }
                    Toggle("Screen shake on extreme hits", isOn: $settings.screenShake)
                        .onChange(of: settings.screenShake) { _, v in engine.applyScreenShake(v) }
                }
                .padding(6)
            }

            GroupBox("Audio") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Combo announcer voice", isOn: $settings.comboAnnouncer)
                        .onChange(of: settings.comboAnnouncer) { _, v in engine.applyComboAnnouncer(v) }
                    Toggle("Audio ducking (lower music during slap)", isOn: $settings.audioDucking)
                        .onChange(of: settings.audioDucking) { _, v in engine.applyAudioDucking(v) }
                }
                .padding(6)
            }

            GroupBox("Haptic") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Trackpad haptic feedback", isOn: $settings.hapticFeedback)
                        .onChange(of: settings.hapticFeedback) { _, v in engine.applyHaptic(v) }
                    if settings.hapticFeedback {
                        Toggle("Morse-style patterns (accessibility)", isOn: $settings.hapticPatterns)
                            .onChange(of: settings.hapticPatterns) { _, v in engine.applyHapticPatterns(v) }
                            .padding(.leading, 20)
                    }
                }
                .padding(6)
            }

            GroupBox("Other") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Idle taunts (speak after no slaps)", isOn: $settings.idleTaunts)
                        .onChange(of: settings.idleTaunts) { _, v in engine.applyIdleTaunts(v) }
                    if settings.idleTaunts {
                        LabeledSlider(label: "After", value: $settings.idleMinutes,
                                      range: 1...30, trailing: String(format: "%.0f min", settings.idleMinutes)) {
                            engine.applyIdleMinutes(settings.idleMinutes)
                        }
                    }
                    Toggle("Milestone notifications", isOn: $settings.notifications)
                        .onChange(of: settings.notifications) { _, v in engine.applyNotifications(v) }
                }
                .padding(6)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Fun

private struct FunTab: View {
    @ObservedObject var engine: SlapEngine
    @ObservedObject var challenge: SlapChallengeManager
    @ObservedObject var beatbox: BeatboxMode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Challenges
                GroupBox("Slap Challenges") {
                    VStack(alignment: .leading, spacing: 8) {
                        if let ch = challenge.activeChallenge, challenge.isRunning {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(ch.name).font(.subheadline.bold())
                                    Text(ch.description).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(String(format: "%.1fs", challenge.timeRemaining))
                                    .font(.title3.bold().monospacedDigit())
                            }
                            ProgressView(value: max(0, challenge.timeRemaining), total: ch.timeLimit)
                            Button("Cancel") { challenge.cancel() }
                                .foregroundStyle(.red).controlSize(.small)
                        } else if let result = challenge.result {
                            HStack {
                                Image(systemName: result == .success ? "trophy.fill" : "xmark.circle")
                                    .foregroundStyle(result == .success ? .yellow : .red)
                                Text(result == .success ? "Challenge Complete!" : "Try Again!")
                                    .font(.headline)
                            }
                        } else {
                            ForEach(Challenge.presets) { ch in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(ch.name).font(.caption.bold())
                                        Text(ch.description).font(.caption2).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Go") { challenge.start(challenge: ch) }
                                        .controlSize(.small)
                                }
                            }
                        }
                    }
                    .padding(6)
                }

                // Beatbox
                GroupBox("Beatbox Mode") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Record a slap rhythm, then loop it.")
                            .font(.caption).foregroundStyle(.secondary)
                        HStack {
                            if beatbox.isRecordingPattern {
                                Button("Stop (\(beatbox.patternLength) beats)") {
                                    beatbox.stopRecording()
                                }
                                .foregroundStyle(.red)
                                Circle().fill(.red).frame(width: 8, height: 8)
                            } else if beatbox.isPlaying {
                                Button("Stop Playback") { beatbox.stopPlayback() }
                                    .foregroundStyle(.orange)
                            } else {
                                Button("Record") { beatbox.startRecording() }
                                if beatbox.patternLength > 0 {
                                    Button("Play (\(beatbox.patternLength))") {
                                        beatbox.startPlayback()
                                    }
                                }
                            }
                        }
                    }
                    .padding(6)
                }

                // Debug
                GroupBox("Debug") {
                    Button("Open Accelerometer Visualizer") {
                        openDebugWindow()
                    }
                    .controlSize(.small)
                    .padding(6)
                }

                Spacer()
            }
            .padding()
        }
    }

    private func openDebugWindow() {
        DebugWindow.open(engine: engine)
    }
}

// MARK: - Stats

private struct StatsTab: View {
    @ObservedObject var stats: SlapStats
    @State private var showResetConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("This Session") {
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 6) {
                    GridRow {
                        Text("Slaps").foregroundStyle(.secondary)
                        Text("\(stats.sessionSlaps)").monospacedDigit().bold()
                    }
                    GridRow {
                        Text("Max Combo").foregroundStyle(.secondary)
                        Text("\(stats.sessionMaxCombo)x").monospacedDigit().bold()
                    }
                    GridRow {
                        Text("Hardest Hit").foregroundStyle(.secondary)
                        Text(String(format: "%.2fg", stats.sessionHardestHit)).monospacedDigit().bold()
                    }
                }
                .padding(6)
            }

            GroupBox("All Time") {
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 6) {
                    GridRow {
                        Text("Total Slaps").foregroundStyle(.secondary)
                        Text("\(stats.allTimeSlaps)").monospacedDigit().bold()
                    }
                    GridRow {
                        Text("Best Combo").foregroundStyle(.secondary)
                        Text("\(stats.allTimeMaxCombo)x").monospacedDigit().bold()
                    }
                    GridRow {
                        Text("Hardest Hit").foregroundStyle(.secondary)
                        Text(String(format: "%.2fg", stats.allTimeHardestHit)).monospacedDigit().bold()
                    }
                    GridRow {
                        Text("Sessions").foregroundStyle(.secondary)
                        Text("\(stats.allTimeSessions)").monospacedDigit().bold()
                    }
                }
                .padding(6)
            }

            HStack {
                Button("Copy Stats") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(stats.exportText(), forType: .string)
                }
                .controlSize(.small)
                Button("Reset All-Time") { showResetConfirm = true }
                    .foregroundStyle(.red).controlSize(.small)
            }
            .alert("Reset All-Time Stats?", isPresented: $showResetConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) { stats.resetAllTime() }
            } message: {
                Text("This will permanently erase all your accumulated statistics.")
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Advanced

private struct AdvancedTab: View {
    @ObservedObject var engine: SlapEngine
    @ObservedObject var settings: SettingsStore
    @StateObject private var recorder = SoundRecorder()
    @State private var recordIntensity = "Light"
    @State private var backupMessage = ""
    private let intensityFolders = ["Light", "Medium", "Hard", "Extreme"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("USB Device Sounds") {
                    Toggle("Play sound on USB plug/unplug", isOn: $settings.usbSounds)
                        .onChange(of: settings.usbSounds) { _, v in engine.applyUSBSounds(v) }
                        .padding(6)
                }

                GroupBox("Slap Actions") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Run script on slap", isOn: $settings.slapActionsEnabled)
                            .onChange(of: settings.slapActionsEnabled) { _, v in
                                engine.applySlapActions(enabled: v, script: settings.slapActionScript)
                            }
                        if settings.slapActionsEnabled {
                            HStack {
                                TextField("Script path", text: $settings.slapActionScript)
                                    .textFieldStyle(.roundedBorder)
                                Button("Browse...") { browseScript() }
                                    .controlSize(.small)
                            }
                            .onChange(of: settings.slapActionScript) { _, v in
                                engine.applySlapActions(enabled: settings.slapActionsEnabled, script: v)
                            }
                            Text(".sh, .applescript, .scpt, .shortcut supported")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(6)
                }

                GroupBox("Record Custom Sound") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            if recorder.isRecording {
                                Button("Stop") { recorder.stopRecording() }.foregroundStyle(.red)
                                Circle().fill(.red).frame(width: 8, height: 8)
                                Text("Recording...").font(.caption)
                            } else {
                                Button("Record from Mic") { recorder.startRecording() }
                            }
                        }
                        if let url = recorder.recordedURL {
                            HStack {
                                Text(url.lastPathComponent).font(.caption).lineLimit(1)
                                Spacer()
                                Picker("", selection: $recordIntensity) {
                                    ForEach(intensityFolders, id: \.self) { Text($0) }
                                }
                                .frame(width: 100)
                                Button("Save to Custom") {
                                    if recorder.saveToCustomPack(name: recordIntensity) { recorder.recordedURL = nil }
                                }
                                .controlSize(.small)
                            }
                        }
                        if let error = recorder.error {
                            Text(error).font(.caption).foregroundStyle(.red)
                        }
                    }
                    .padding(6)
                }

                GroupBox("Backup") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Button("Backup to Keychain") {
                                backupMessage = KeychainStore.backupSettings() ? "Backup saved" : "Backup failed"
                            }
                            .controlSize(.small)
                            Button("Restore from Keychain") {
                                if KeychainStore.restoreSettings() {
                                    settings.objectWillChange.send()
                                    settings.applyAll(to: engine)
                                    backupMessage = "Settings restored"
                                } else {
                                    backupMessage = "No backup found"
                                }
                            }
                            .controlSize(.small)
                        }
                        if !backupMessage.isEmpty {
                            Text(backupMessage)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(6)
                }

                GroupBox("Keyboard") {
                    HStack {
                        Text("Toggle detection")
                        Spacer()
                        Text("Ctrl + Shift + S").font(.caption.monospaced())
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(.quaternary).clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .padding(6)
                }

                Spacer()
            }
            .padding()
        }
    }

    private func browseScript() {
        let panel = NSOpenPanel()
        panel.title = "Select Script"
        panel.allowedContentTypes = [.shellScript, .appleScript, .script]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            settings.slapActionScript = url.path
        }
    }
}

// MARK: - Reusable slider

private struct LabeledSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let trailing: String
    var onChange: () -> Void

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 75, alignment: .leading)
            Slider(value: $value, in: range)
            Text(trailing)
                .font(.caption).foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
        .onChange(of: value) { _, _ in onChange() }
    }
}
