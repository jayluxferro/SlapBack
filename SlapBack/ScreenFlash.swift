import AppKit

final class ScreenFlash {
    var enabled: Bool = true
    private var panels: [NSPanel] = []
    private var isAnimating = false

    func flash(intensity: SlapIntensity) {
        guard enabled, !isAnimating else { return }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { return }

        DispatchQueue.main.async { [weak self] in
            self?.showFlash(intensity: intensity)
        }
    }

    private func showFlash(intensity: SlapIntensity) {
        guard !isAnimating else { return }
        isAnimating = true

        // Clean up any leftover panels
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()

        let color: NSColor
        let alpha: CGFloat
        let borderWidth: CGFloat
        switch intensity {
        case .light:   color = .systemYellow; alpha = 0.15; borderWidth = 4
        case .medium:  color = .systemOrange; alpha = 0.22; borderWidth = 6
        case .hard:    color = .systemRed;    alpha = 0.30; borderWidth = 8
        case .extreme: color = .systemRed;    alpha = 0.40; borderWidth = 10
        }

        for screen in NSScreen.screens {
            let panel = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered, defer: false
            )
            panel.level = .popUpMenu
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.alphaValue = 1

            let view = FlashBorderView(color: color.withAlphaComponent(alpha), borderWidth: borderWidth)
            view.frame = NSRect(origin: .zero, size: screen.frame.size)
            panel.contentView = view
            panel.orderFrontRegardless()
            panels.append(panel)
        }

        let capturedPanels = panels
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            for p in capturedPanels { p.animator().alphaValue = 0 }
        }, completionHandler: { [weak self] in
            for p in capturedPanels { p.orderOut(nil) }
            self?.panels.removeAll()
            self?.isAnimating = false
        })
    }
}

private class FlashBorderView: NSView {
    let color: NSColor
    let borderWidth: CGFloat
    init(color: NSColor, borderWidth: CGFloat) {
        self.color = color; self.borderWidth = borderWidth
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        let outer = NSBezierPath(rect: bounds)
        let inner = NSBezierPath(rect: bounds.insetBy(dx: borderWidth, dy: borderWidth))
        outer.append(inner.reversed)
        color.setFill()
        outer.fill()
    }
}
