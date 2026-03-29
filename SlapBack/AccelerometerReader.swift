import Foundation
import AppKit
import IOKit
import IOKit.hid

struct AccelerometerSample {
    let x: Double
    let y: Double
    let z: Double
    let timestamp: TimeInterval

    var magnitude: Double {
        sqrt(x * x + y * y + z * z)
    }
}

final class AccelerometerReader {
    private var manager: IOHIDManager?
    private var thread: Thread?
    private var runLoop: CFRunLoop?
    private var reportBuffer = [UInt8](repeating: 0, count: 64)
    private var sampleCount: UInt64 = 0
    private var paused = false

    var onSample: ((AccelerometerSample) -> Void)?
    var onError: ((String) -> Void)?

    /// Decimation: process every Nth sample (8 = ~15Hz from 125Hz sensor)
    var decimation: UInt64 = 8

    private(set) var isRunning = false

    // Scale factor from SlapMac: 0x37800000 as Float = 1/65536
    private static let scale: Double = 1.0 / 65536.0

    func start() {
        guard !isRunning else { return }
        isRunning = true
        sampleCount = 0

        // Observe sleep/wake to pause/resume
        let wsnc = NSWorkspace.shared.notificationCenter
        wsnc.addObserver(self, selector: #selector(systemWillSleep), name: NSWorkspace.willSleepNotification, object: nil)
        wsnc.addObserver(self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)

        thread = Thread { [weak self] in
            self?.runHIDManager()
        }
        thread?.name = "com.slapback.accelerometer"
        thread?.qualityOfService = .userInteractive
        thread?.start()
    }

    @objc private func systemWillSleep(_ note: Notification) {
        paused = true
    }

    @objc private func systemDidWake(_ note: Notification) {
        paused = false
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        NSWorkspace.shared.notificationCenter.removeObserver(self)

        // Wake up the run loop so the background thread exits its while loop.
        // Do NOT nil out runLoop here — the background thread still needs it for cleanup.
        if let rl = runLoop {
            CFRunLoopStop(rl)
        }
        // thread and runLoop are cleaned up by the background thread after it exits the loop.
    }

    /// Activate the accelerometer sensor by setting properties on AppleSPUHIDDriver.
    /// The sensor is powered off by default and must be explicitly enabled.
    /// (Confirmed from SlapMac binary: sub_10002a568)
    private func activateSensor() {
        guard let matching = IOServiceMatching("AppleSPUHIDDriver") else { return }
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else { return }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            // Enable reporting, power on sensor, set report interval
            IORegistryEntrySetCFProperty(service, "SensorPropertyReportingState" as CFString, 1 as CFNumber)
            IORegistryEntrySetCFProperty(service, "SensorPropertyPowerState" as CFString, 1 as CFNumber)
            IORegistryEntrySetCFProperty(service, "ReportInterval" as CFString, 1000 as CFNumber)
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        print("[SlapBack] Sensor activated")
    }

    private func runHIDManager() {
        // Step 1: Activate the sensor (must happen BEFORE HID manager setup)
        activateSensor()

        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = manager

        // Match AppleSPUHIDDevice with PrimaryUsagePage=0xFF00, PrimaryUsage=3
        // (confirmed from SlapMac binary analysis)
        guard let matching = IOServiceMatching("AppleSPUHIDDevice") as? NSMutableDictionary else {
            reportError("Failed to create IOService matching dictionary")
            return
        }
        matching["PrimaryUsagePage"] = 0xFF00 as UInt32
        matching["PrimaryUsage"] = 3 as UInt32
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        // Schedule BEFORE opening (matching SlapMac's order)
        self.runLoop = CFRunLoopGetCurrent()
        let mode = CFRunLoopMode.defaultMode!.rawValue
        IOHIDManagerScheduleWithRunLoop(manager, self.runLoop!, mode)

        let openStatus = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if openStatus != kIOReturnSuccess {
            reportError("Failed to open HID manager (status: \(openStatus))")
            IOHIDManagerUnscheduleFromRunLoop(manager, self.runLoop!, mode)
            return
        }

        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
              !devices.isEmpty else {
            reportError("No accelerometer found. This Mac may not have a compatible sensor.")
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerUnscheduleFromRunLoop(manager, self.runLoop!, mode)
            return
        }

        // Register input report callback on the manager (handles all matched devices)
        let context = Unmanaged.passUnretained(self).toOpaque()

        IOHIDManagerRegisterInputReportCallback(
            manager,
            { context, result, sender, type, reportID, report, reportLength in
                guard let context = context else { return }
                let reader = Unmanaged<AccelerometerReader>.fromOpaque(context).takeUnretainedValue()
                reader.handleReport(report: report, length: reportLength)
            },
            context
        )

        print("[SlapBack] Accelerometer reader running (\(devices.count) device(s))")

        // Run until stopped
        while isRunning {
            let result = CFRunLoopRunInMode(.defaultMode, 0.25, true)
            if result == .finished || result == .stopped { break }
            if Thread.current.isCancelled { break }
        }

        // Cleanup on the background thread (safe — we still own runLoop/manager here)
        if let rl = self.runLoop {
            IOHIDManagerUnscheduleFromRunLoop(manager, rl, mode)
        }
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = nil
        self.runLoop = nil
        self.thread = nil
    }

    private func handleReport(report: UnsafeMutablePointer<UInt8>, length: Int) {
        guard length >= 18, !paused else { return }

        sampleCount &+= 1
        guard (sampleCount & (decimation - 1)) == 0 else { return }

        // Extract 3× Int32 at offsets 6, 10, 14 (confirmed from SlapMac binary)
        // Scale by 1/65536.0 (0x37800000 as IEEE 754 float)
        let x = Double(readInt32(report, offset: 6)) * Self.scale
        let y = Double(readInt32(report, offset: 10)) * Self.scale
        let z = Double(readInt32(report, offset: 14)) * Self.scale

        let sample = AccelerometerSample(
            x: x, y: y, z: z,
            timestamp: ProcessInfo.processInfo.systemUptime
        )

        onSample?(sample)
    }

    private func readInt32(_ buffer: UnsafeMutablePointer<UInt8>, offset: Int) -> Int32 {
        let b0 = UInt32(buffer[offset])
        let b1 = UInt32(buffer[offset + 1])
        let b2 = UInt32(buffer[offset + 2])
        let b3 = UInt32(buffer[offset + 3])
        return Int32(bitPattern: (b3 << 24) | (b2 << 16) | (b1 << 8) | b0)
    }

    private func reportError(_ message: String) {
        print("[SlapBack] ERROR: \(message)")
        DispatchQueue.main.async { [weak self] in
            self?.onError?(message)
            self?.isRunning = false
        }
    }

    deinit {
        stop()
    }
}
