import SwiftUI

/// Real-time visualizer for accelerometer data, STA/LTA ratio, and detection thresholds.
/// Runs in its own window managed by DebugWindowController to prevent crashes on close.
struct DebugVisualizerView: View {
    @ObservedObject var engine: SlapEngine
    @StateObject private var sampler = DebugSampler()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accelerometer Debug")
                .font(.headline)

            HStack(spacing: 20) {
                StatBox(title: "STA/LTA", value: String(format: "%.1f", sampler.ratio),
                        color: sampler.ratio > sampler.threshold ? .red : .green)
                StatBox(title: "Deviation", value: String(format: "%.4fg", sampler.deviation), color: .primary)
                StatBox(title: "Threshold", value: String(format: "%.1f", sampler.threshold), color: .orange)
            }

            Text("Magnitude").font(.caption).foregroundStyle(.secondary)
            GraphView(data: sampler.magnitudeHistory, color: .blue, maxPoints: sampler.maxPoints)
                .frame(height: 80)
                .background(Color.black.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Text("STA/LTA Ratio (red line = threshold)").font(.caption).foregroundStyle(.secondary)
            ZStack {
                GraphView(data: sampler.ratioHistory, color: .green, maxPoints: sampler.maxPoints)
                if !sampler.ratioHistory.isEmpty {
                    let maxVal = max(sampler.ratioHistory.max() ?? 1, sampler.threshold * 1.2)
                    let thresholdY = sampler.threshold / maxVal
                    GeometryReader { geo in
                        Path { path in
                            let y = geo.size.height * (1 - CGFloat(thresholdY))
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geo.size.width, y: y))
                        }
                        .stroke(.red.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    }
                }
            }
            .frame(height: 80)
            .background(Color.black.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding()
        .frame(width: 420, height: 350)
        .onAppear { sampler.start(detector: engine.detector) }
        .onDisappear { sampler.stop() }
    }
}

private struct StatBox: View {
    let title: String
    let value: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold().monospacedDigit()).foregroundStyle(color)
        }
    }
}

/// Owns the timer so it can be reliably invalidated
final class DebugSampler: ObservableObject {
    @Published var magnitudeHistory: [Double] = []
    @Published var ratioHistory: [Double] = []
    @Published var ratio: Double = 0
    @Published var deviation: Double = 0
    @Published var threshold: Double = 0
    let maxPoints = 200

    private var timer: Timer?
    private weak var detector: SlapDetector?

    func start(detector: SlapDetector) {
        self.detector = detector
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let self, let det = self.detector else { return }
            self.ratio = det.currentRatio
            self.deviation = det.currentDeviation
            self.threshold = det.currentThreshold
            self.magnitudeHistory.append(det.currentDeviation)
            self.ratioHistory.append(det.currentRatio)
            if self.magnitudeHistory.count > self.maxPoints { self.magnitudeHistory.removeFirst() }
            if self.ratioHistory.count > self.maxPoints { self.ratioHistory.removeFirst() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        detector = nil
    }

    deinit { stop() }
}

struct GraphView: View {
    let data: [Double]
    let color: Color
    let maxPoints: Int

    var body: some View {
        GeometryReader { geo in
            if data.count >= 2 {
                let maxVal = max(data.max() ?? 1, 0.01)
                Path { path in
                    for (i, val) in data.enumerated() {
                        let x = geo.size.width * CGFloat(i) / CGFloat(maxPoints - 1)
                        let y = geo.size.height * (1 - CGFloat(val / maxVal))
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(color, lineWidth: 1.5)
            }
        }
    }
}

enum DebugWindow {
    @MainActor
    static func open(engine: SlapEngine) {
        WindowManager.shared.openSwiftUI(
            id: "debug", title: "Accelerometer Debug",
            width: 440, height: 370,
            view: DebugVisualizerView(engine: engine)
        )
    }
}
