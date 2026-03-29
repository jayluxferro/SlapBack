import AppKit
import SwiftUI

/// Centralized window management. Avoids NSWindowTransformAnimation dealloc crashes
/// by disabling animations and using orderOut instead of close.
@MainActor
final class WindowManager: NSObject, NSWindowDelegate {
    static let shared = WindowManager()
    private var windows: [String: NSWindow] = [:]

    func open(id: String, title: String, width: CGFloat, height: CGFloat, content: @escaping () -> NSView) {
        if let existing = windows[id], existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false
        )
        w.title = title
        w.center()
        w.animationBehavior = .none
        w.delegate = self
        w.contentView = content()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        windows[id] = w
    }

    func openSwiftUI<V: View>(id: String, title: String, width: CGFloat, height: CGFloat, view: V) {
        open(id: id, title: title, width: width, height: height) {
            NSHostingView(rootView: view)
        }
    }

    func close(id: String) {
        guard let w = windows[id] else { return }
        w.orderOut(nil)
        w.contentView = nil
        windows.removeValue(forKey: id)
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Hide instead of close to avoid animation dealloc crash
        sender.orderOut(nil)
        sender.contentView = nil
        // Remove from our tracking
        windows = windows.filter { $0.value !== sender }
        return false
    }
}
