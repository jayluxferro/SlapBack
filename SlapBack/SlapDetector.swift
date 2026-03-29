import Foundation

enum SlapIntensity: Int, Comparable {
    case light = 1
    case medium = 2
    case hard = 3
    case extreme = 4

    static func < (lhs: SlapIntensity, rhs: SlapIntensity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .light: return "Light"
        case .medium: return "Medium"
        case .hard: return "Hard"
        case .extreme: return "Extreme"
        }
    }
}

struct SlapEvent {
    let intensity: SlapIntensity
    let magnitude: Double
    let timestamp: TimeInterval
}

/// STA/LTA impact detector with arming logic and thread-safe access.
final class SlapDetector {
    var sensitivity: Double = 0.2 {
        didSet { updateThresholdsSafe() }
    }

    private func updateThresholdsSafe() {
        // Try lock to avoid deadlock if called while processSample holds the lock
        guard lock.try() else {
            // If locked, the next processSample call will pick up the new sensitivity
            return
        }
        updateThresholds()
        lock.unlock()
    }
    var cooldown: TimeInterval = 0.7
    var onSlap: ((SlapEvent) -> Void)?

    // Auto-calibration: track recent magnitudes to adapt
    var autoCalibrate: Bool = false
    private var recentMagnitudes: [Double] = []
    private let autoCalWindow = 50

    // Debug: expose current STA/LTA ratio for visualizer
    private(set) var currentRatio: Double = 0
    private(set) var currentDeviation: Double = 0
    private(set) var currentThreshold: Double = 0

    private let lock = NSLock()

    private let staWindowSize: Int = 5
    private let ltaWindowSize: Int = 75
    private var staBuffer: [Double] = []
    private var ltaBuffer: [Double] = []
    private var staSum: Double = 0
    private var ltaSum: Double = 0
    private var baselineMag: Double = 1.0
    private let baselineAlpha: Double = 0.002

    private var staLtaThreshold: Double = 5.0
    private var offThreshold: Double = 1.5
    private var minDeviation: Double = 0.08
    private var lastDetectionTime: TimeInterval = 0
    private var sampleCount: Int = 0
    private let warmupSamples: Int = 12
    private var isArmed: Bool = true

    private let lightThreshold: Double = 0.15
    private let mediumThreshold: Double = 0.4
    private let hardThreshold: Double = 0.8

    init() { updateThresholds() }

    func processSample(_ sample: AccelerometerSample) {
        lock.lock()
        defer { lock.unlock() }

        sampleCount += 1
        let mag = sample.magnitude
        let deviation = abs(mag - baselineMag)

        if deviation < 0.15 {
            baselineMag = baselineMag * (1.0 - baselineAlpha) + mag * baselineAlpha
        }

        let squaredDev = deviation * deviation

        staBuffer.append(squaredDev)
        staSum += squaredDev
        if staBuffer.count > staWindowSize { staSum -= staBuffer.removeFirst() }

        ltaBuffer.append(squaredDev)
        ltaSum += squaredDev
        if ltaBuffer.count > ltaWindowSize { ltaSum -= ltaBuffer.removeFirst() }

        guard sampleCount > warmupSamples,
              ltaBuffer.count >= ltaWindowSize / 2,
              staBuffer.count >= staWindowSize else { return }

        let sta = staSum / Double(staBuffer.count)
        let lta = ltaSum / Double(ltaBuffer.count)
        guard lta > 1e-12 else { return }
        let ratio = sta / lta

        currentRatio = ratio
        currentDeviation = deviation
        currentThreshold = staLtaThreshold

        if !isArmed {
            if ratio < offThreshold { isArmed = true }
            return
        }

        if ratio > staLtaThreshold && deviation > minDeviation {
            let now = sample.timestamp
            guard now - lastDetectionTime > cooldown else { return }
            lastDetectionTime = now
            isArmed = false

            // Auto-calibration — update thresholds directly since we already hold the lock
            if autoCalibrate {
                recentMagnitudes.append(deviation)
                if recentMagnitudes.count > autoCalWindow { recentMagnitudes.removeFirst() }
                if recentMagnitudes.count >= 10 {
                    let avg = recentMagnitudes.reduce(0, +) / Double(recentMagnitudes.count)
                    let targetMin = avg * 0.5
                    let newSens = max(0.05, min(0.95, (0.25 - targetMin) / 0.20))
                    sensitivity = newSens
                    updateThresholds()
                }
            }

            let intensity = classifyIntensity(deviation: deviation)
            let event = SlapEvent(intensity: intensity, magnitude: deviation, timestamp: now)

            staBuffer.removeAll(keepingCapacity: true)
            staSum = 0

            // Call outside lock
            lock.unlock()
            onSlap?(event)
            lock.lock()
        }
    }

    func reset() {
        lock.lock()
        staBuffer.removeAll(); ltaBuffer.removeAll()
        staSum = 0; ltaSum = 0; sampleCount = 0
        lastDetectionTime = 0; baselineMag = 1.0; isArmed = true
        recentMagnitudes.removeAll()
        lock.unlock()
    }

    private func classifyIntensity(deviation: Double) -> SlapIntensity {
        if deviation > hardThreshold { return .extreme }
        if deviation > mediumThreshold { return .hard }
        if deviation > lightThreshold { return .medium }
        return .light
    }

    private func updateThresholds() {
        staLtaThreshold = 12.0 - (sensitivity * 9.0)
        minDeviation = 0.25 - (sensitivity * 0.20)
        currentThreshold = staLtaThreshold
    }
}
