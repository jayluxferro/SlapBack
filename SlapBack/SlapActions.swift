import AppKit

/// Runs user-configured actions when a slap is detected.
/// Supports per-intensity scripts.
final class SlapActions {
    var enabled: Bool = false
    var scriptPath: String = ""

    func run(intensity: SlapIntensity) {
        guard enabled, !scriptPath.isEmpty else { return }
        let path = scriptPath

        let expanded = (path as NSString).expandingTildeInPath

        DispatchQueue.global(qos: .utility).async {
            if path.hasSuffix(".scpt") || path.hasSuffix(".applescript") {
                self.runAppleScript(path: expanded, intensity: intensity)
            } else if path.hasSuffix(".shortcut") {
                let name = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
                self.runShortcut(name: name, intensity: intensity)
            } else {
                self.runShellScript(path: expanded, intensity: intensity)
            }
        }
    }

    private func runAppleScript(path: String, intensity: SlapIntensity) {
        let url = URL(fileURLWithPath: path)
        guard let script = NSAppleScript(contentsOf: url, error: nil) else { return }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
    }

    private func runShortcut(name: String, intensity: SlapIntensity) {
        let task = Process()
        task.launchPath = "/usr/bin/shortcuts"
        task.arguments = ["run", name, "--input-type", "text", "--input", intensity.label]
        do { try task.run() } catch { print("[SlapBack] Script error: \(error)") }
    }

    private func runShellScript(path: String, intensity: SlapIntensity) {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = [path, intensity.label]
        var env = ProcessInfo.processInfo.environment
        env["SLAPBACK_INTENSITY"] = intensity.label
        env["SLAPBACK_INTENSITY_RAW"] = "\(intensity.rawValue)"
        task.environment = env
        do { try task.run() } catch { print("[SlapBack] Script error: \(error)") }
    }
}
