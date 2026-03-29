import SwiftUI

struct CalibrationView: View {
    @ObservedObject var engine: SlapEngine
    @ObservedObject var settings: SettingsStore
    @State private var step = 0
    @State private var lightMag: Double = 0
    @State private var hardMag: Double = 0
    @State private var originalOnSlap: ((SlapEvent) -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            switch step {
            case 0: introStep
            case 1: lightStep
            case 2: hardStep
            case 3: doneStep
            default: EmptyView()
            }
        }
        .frame(width: 380, height: 280)
        .padding()
        .onDisappear { restoreDetector() }
    }

    private var introStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 40)).foregroundStyle(.blue)
            Text("Calibration Wizard").font(.title2.bold())
            Text("We'll calibrate sensitivity for your MacBook.\nYou'll do a light tap and a hard slap.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Spacer()
            Button("Start") { hookDetector(); step = 1 }
                .buttonStyle(.borderedProminent)
        }
    }

    private var lightStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.tap")
                .font(.system(size: 40)).foregroundStyle(.orange)
            Text("Step 1: Light Tap").font(.title2.bold())
            Text("Give your MacBook a gentle tap.")
                .foregroundStyle(.secondary)
            if lightMag > 0 {
                Text(String(format: "Detected: %.3fg", lightMag))
                    .font(.headline).foregroundStyle(.green)
                Button("Next") { step = 2; hardMag = 0 }
                    .buttonStyle(.borderedProminent)
            } else {
                ProgressView().scaleEffect(0.8)
                Text("Waiting for tap...").foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var hardStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 40)).foregroundStyle(.red)
            Text("Step 2: Hard Slap").font(.title2.bold())
            Text("Now give it a proper slap.")
                .foregroundStyle(.secondary)
            if hardMag > 0 {
                Text(String(format: "Detected: %.3fg", hardMag))
                    .font(.headline).foregroundStyle(.green)
                Button("Apply") { applyCalibration(); step = 3 }
                    .buttonStyle(.borderedProminent)
            } else {
                ProgressView().scaleEffect(0.8)
                Text("Waiting for slap...").foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var doneStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40)).foregroundStyle(.green)
            Text("Calibrated!").font(.title2.bold())
            Text(String(format: "Sensitivity: %.0f%%  Cooldown: %.1fs",
                         settings.sensitivity * 100, settings.cooldown))
                .foregroundStyle(.secondary)
            Spacer()
            Button("Done") {
                restoreDetector()
                closeWindow()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func closeWindow() {
        WindowManager.shared.close(id: "calibration")
    }

    private func hookDetector() {
        engine.detector.sensitivity = 0.9
        engine.detector.cooldown = 0.2
        originalOnSlap = engine.detector.onSlap
        engine.detector.onSlap = { event in
            DispatchQueue.main.async {
                if self.step == 1 && self.lightMag == 0 {
                    self.lightMag = event.magnitude
                } else if self.step == 2 && self.hardMag == 0 {
                    self.hardMag = event.magnitude
                }
            }
            self.originalOnSlap?(event)
        }
    }

    private func restoreDetector() {
        if let original = originalOnSlap {
            engine.detector.onSlap = original
            originalOnSlap = nil
        }
        engine.applySensitivity(settings.sensitivity)
        engine.applyCooldown(settings.cooldown)
    }

    private func applyCalibration() {
        guard lightMag > 0, hardMag > 0 else { return }
        // If user hit harder on "light" step, swap them
        let (light, hard) = lightMag < hardMag ? (lightMag, hardMag) : (hardMag, lightMag)
        let targetMinDev = light * 0.8
        let sens = max(0.05, min(0.95, (0.25 - targetMinDev) / 0.20))
        settings.sensitivity = sens
        engine.applySensitivity(sens)
        let cd = max(0.4, min(1.5, 1.0 - hard * 0.3))
        settings.cooldown = cd
        engine.applyCooldown(cd)
    }
}
