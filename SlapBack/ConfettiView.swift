import AppKit

final class ConfettiManager {
    var enabled: Bool = true
    private var windows: [NSPanel] = []

    /// Trigger confetti on hard hits or high combos
    func trigger(intensity: SlapIntensity, comboCount: Int) {
        guard enabled else { return }
        guard intensity >= .hard || comboCount >= 3 else { return }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { return }

        let particleCount = switch intensity {
        case .light: 0
        case .medium: 0
        case .hard: 40
        case .extreme: 80
        }
        let count = max(particleCount, comboCount * 15)
        guard count > 0 else { return }

        DispatchQueue.main.async { [weak self] in
            self?.showConfetti(count: count)
        }
    }

    private func showConfetti(count: Int) {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()

        for screen in NSScreen.screens {
            let frame = screen.frame

            let panel = NSPanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered, defer: false
            )
            panel.level = .statusBar
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            let confettiView = ConfettiAnimationView(frame: NSRect(origin: .zero, size: frame.size), particleCount: count)
            panel.contentView = confettiView
            panel.orderFrontRegardless()
            windows.append(panel)

            confettiView.startAnimation()
        }

        let capturedWindows = windows
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            for panel in capturedWindows { panel.orderOut(nil) }
            self?.windows.removeAll()
        }
    }
}

// MARK: - Confetti Animation View

private class ConfettiAnimationView: NSView {
    private var particles: [ConfettiParticle] = []
    private var animationTimer: Timer?
    private let particleCount: Int

    struct ConfettiParticle {
        var x: CGFloat
        var y: CGFloat
        var vx: CGFloat
        var vy: CGFloat
        var rotation: CGFloat
        var rotationSpeed: CGFloat
        var size: CGFloat
        var color: NSColor
        var shape: Shape
        var alpha: CGFloat = 1.0

        enum Shape: CaseIterable {
            case rectangle, circle, triangle
        }
    }

    init(frame: NSRect, particleCount: Int) {
        self.particleCount = particleCount
        super.init(frame: frame)
        wantsLayer = true
    }
    required init?(coder: NSCoder) { fatalError() }

    func startAnimation() {
        let colors: [NSColor] = [.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemBlue, .systemPurple, .systemPink]
        let centerX = bounds.midX
        let topY = bounds.maxY

        particles = (0..<particleCount).map { _ in
            ConfettiParticle(
                x: centerX + CGFloat.random(in: -200...200),
                y: topY + CGFloat.random(in: 0...100),
                vx: CGFloat.random(in: -4...4),
                vy: CGFloat.random(in: -12 ... -4),
                rotation: CGFloat.random(in: 0...360),
                rotationSpeed: CGFloat.random(in: -8...8),
                size: CGFloat.random(in: 4...10),
                color: colors.randomElement() ?? .systemRed,
                shape: ConfettiParticle.Shape.allCases.randomElement() ?? .rectangle
            )
        }

        // Use timer for animation (simpler than CVDisplayLink for this use case)
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] timer in
            guard let self, self.window != nil else { timer.invalidate(); return }
            self.updateParticles()
            self.needsDisplay = true
        }
    }

    private func updateParticles() {
        for i in particles.indices {
            particles[i].x += particles[i].vx
            particles[i].y += particles[i].vy
            particles[i].vy -= 0.15 // gravity
            particles[i].vx *= 0.99  // air resistance
            particles[i].rotation += particles[i].rotationSpeed
            // Fade out as they fall below midpoint
            if particles[i].y < bounds.midY {
                particles[i].alpha = max(0, particles[i].alpha - 0.02)
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        for p in particles where p.alpha > 0.01 {
            ctx.saveGState()
            ctx.translateBy(x: p.x, y: p.y)
            ctx.rotate(by: p.rotation * .pi / 180)
            ctx.setAlpha(p.alpha)
            ctx.setFillColor(p.color.cgColor)

            let s = p.size
            switch p.shape {
            case .rectangle:
                ctx.fill(CGRect(x: -s/2, y: -s/4, width: s, height: s/2))
            case .circle:
                ctx.fillEllipse(in: CGRect(x: -s/3, y: -s/3, width: s*0.66, height: s*0.66))
            case .triangle:
                ctx.beginPath()
                ctx.move(to: CGPoint(x: 0, y: s/2))
                ctx.addLine(to: CGPoint(x: -s/2, y: -s/2))
                ctx.addLine(to: CGPoint(x: s/2, y: -s/2))
                ctx.closePath()
                ctx.fillPath()
            }
            ctx.restoreGState()
        }
    }
}
