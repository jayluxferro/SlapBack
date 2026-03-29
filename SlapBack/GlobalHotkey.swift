import AppKit
import Carbon

final class GlobalHotkey {
    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    var onToggle: (() -> Void)?

    /// Register Ctrl+Shift+S as global hotkey
    func register() {
        var hotKeyID = EventHotKeyID(signature: OSType(0x534C4150), id: 1) // "SLAP"

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handlerBlock: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let hotkey = Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue()
            hotkey.onToggle?()
            return noErr
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), handlerBlock, 1, &eventType, selfPtr, &eventHandler)

        // Ctrl+Shift+S: modifiers = controlKey + shiftKey, keyCode = 1 (S)
        let modifiers: UInt32 = UInt32(controlKey | shiftKey)
        RegisterEventHotKey(UInt32(kVK_ANSI_S), modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)

        print("[SlapBack] Global hotkey registered: Ctrl+Shift+S")
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef); self.hotKeyRef = nil }
        if let eventHandler { RemoveEventHandler(eventHandler); self.eventHandler = nil }
    }

    deinit { unregister() }
}
