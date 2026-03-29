import Foundation
import IOKit
import IOKit.usb

final class USBMonitor {
    var enabled: Bool = false
    var onDeviceEvent: ((String) -> Void)?

    private var notifyPort: IONotificationPortRef?
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0
    private var started = false

    func start() {
        guard !started else { return }
        started = true

        notifyPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let notifyPort else { return }

        let runLoopSource = IONotificationPortGetRunLoopSource(notifyPort).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)

        guard let matching = IOServiceMatching(kIOUSBDeviceClassName) else { return }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        // Monitor device additions
        IOServiceAddMatchingNotification(
            notifyPort,
            kIOFirstMatchNotification,
            matching,
            { refcon, iterator in
                guard let refcon else { return }
                let monitor = Unmanaged<USBMonitor>.fromOpaque(refcon).takeUnretainedValue()
                monitor.handleDevices(iterator: iterator, connected: true)
            },
            selfPtr,
            &addedIterator
        )
        // Drain existing devices (required to arm notification)
        drainIterator(addedIterator)

        // Monitor device removals
        guard let matchingRemove = IOServiceMatching(kIOUSBDeviceClassName) else { return }
        IOServiceAddMatchingNotification(
            notifyPort,
            kIOTerminatedNotification,
            matchingRemove,
            { refcon, iterator in
                guard let refcon else { return }
                let monitor = Unmanaged<USBMonitor>.fromOpaque(refcon).takeUnretainedValue()
                monitor.handleDevices(iterator: iterator, connected: false)
            },
            selfPtr,
            &removedIterator
        )
        drainIterator(removedIterator)

        print("[SlapBack] USB monitor started")
    }

    func stop() {
        if addedIterator != 0 { IOObjectRelease(addedIterator); addedIterator = 0 }
        if removedIterator != 0 { IOObjectRelease(removedIterator); removedIterator = 0 }
        if let notifyPort {
            IONotificationPortDestroy(notifyPort)
            self.notifyPort = nil
        }
        started = false
    }

    private func handleDevices(iterator: io_iterator_t, connected: Bool) {
        guard enabled else { drainIterator(iterator); return }
        var service = IOIteratorNext(iterator)
        while service != 0 {
            let event = connected ? "connected" : "disconnected"
            onDeviceEvent?(event)
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
    }

    private func drainIterator(_ iterator: io_iterator_t) {
        var service = IOIteratorNext(iterator)
        while service != 0 {
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
    }

    deinit { stop() }
}
