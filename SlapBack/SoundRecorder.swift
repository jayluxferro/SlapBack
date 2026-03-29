import AVFoundation
import AppKit

final class SoundRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var recordedURL: URL?
    @Published var error: String?

    private var audioRecorder: AVAudioRecorder?

    private var recordingsDir: URL {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        return supportDir.appendingPathComponent("SlapBack/Recordings", isDirectory: true)
    }

    func startRecording() {
        do {
            try FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        } catch {
            self.error = "Cannot create recordings directory"
            return
        }

        let filename = "recording_\(Int(Date().timeIntervalSince1970)).m4a"
        let url = recordingsDir.appendingPathComponent(filename)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            isRecording = true
            recordedURL = nil
            error = nil
        } catch {
            self.error = "Failed to start recording: \(error.localizedDescription)"
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        recordedURL = audioRecorder?.url
        audioRecorder = nil
    }

    /// Save the last recording to a custom sound pack folder
    func saveToCustomPack(name: String) -> Bool {
        guard let url = recordedURL else { return false }
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let destDir = supportDir.appendingPathComponent("SlapBack/Sounds/\(name)", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
            let destURL = destDir.appendingPathComponent(url.lastPathComponent)
            try FileManager.default.copyItem(at: url, to: destURL)
            return true
        } catch {
            self.error = "Failed to save: \(error.localizedDescription)"
            return false
        }
    }

    /// List all recordings
    func listRecordings() -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: recordingsDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "m4a" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }) ?? []
    }
}
