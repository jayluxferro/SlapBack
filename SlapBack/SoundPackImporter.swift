import AppKit
import Foundation

final class SoundPackImporter {
    /// Import a .zip file as a custom sound pack
    static func importZip(from url: URL) -> (success: Bool, packName: String, message: String) {
        let fm = FileManager.default
        let supportDir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let soundsDir = supportDir.appendingPathComponent("SlapBack/Sounds", isDirectory: true)

        // Use the zip filename (without extension) as pack name
        let packName = url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()
        let destDir = soundsDir.appendingPathComponent(packName, isDirectory: true)

        do {
            try fm.createDirectory(at: destDir, withIntermediateDirectories: true)

            // Unzip using ditto (built-in macOS tool)
            let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? fm.removeItem(at: tempDir) }

            let task = Process()
            task.launchPath = "/usr/bin/ditto"
            task.arguments = ["-xk", url.path, tempDir.path]
            try task.run()
            task.waitUntilExit()

            guard task.terminationStatus == 0 else {
                return (false, packName, "Failed to unzip file")
            }

            // Move audio files to the pack directory
            let audioExtensions = Set(["mp3", "wav", "aiff", "m4a", "caf", "ogg"])
            var count = 0

            if let enumerator = fm.enumerator(at: tempDir, includingPropertiesForKeys: nil) {
                while let fileURL = enumerator.nextObject() as? URL {
                    if audioExtensions.contains(fileURL.pathExtension.lowercased()) {
                        let dest = destDir.appendingPathComponent(fileURL.lastPathComponent)
                        try? fm.removeItem(at: dest) // Overwrite existing
                        try fm.moveItem(at: fileURL, to: dest)
                        count += 1
                    }
                }
            }

            if count == 0 {
                try? fm.removeItem(at: destDir)
                return (false, packName, "No audio files found in zip")
            }

            return (true, packName, "Imported \(count) sounds as '\(packName)'")
        } catch {
            return (false, packName, "Import failed: \(error.localizedDescription)")
        }
    }

    /// Open file picker for .zip import
    static func showImportDialog(completion: @escaping (Bool, String) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "Import Sound Pack"
        panel.allowedContentTypes = [.zip]
        panel.allowsMultipleSelection = false

        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                completion(false, "Cancelled")
                return
            }
            let result = importZip(from: url)
            completion(result.success, result.message)
        }
    }
}
