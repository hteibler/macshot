import Carbon.HIToolbox
import Foundation

/// Registers one global hotkey via Carbon's RegisterEventHotKey, and lets
/// the binding be changed later (e.g. when the user picks a new one in
/// Settings) without reinstalling the event handler.
final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let onTrigger: () -> Void
    private let hotKeyID = EventHotKeyID(signature: OSType(UInt32(bitPattern: 0x6D637368)), id: 1) // 'mcsh'

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
        installHandler()
    }

    deinit {
        unregister()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    func update(keyCode: UInt32, modifiers: UInt32) {
        unregister()
        var ref: EventHotKeyRef?
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        hotKeyRef = ref
    }

    private func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
    }

    private func installHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue().onTrigger()
            return noErr
        }, 1, &eventType, selfPtr, &eventHandler)
    }
}
