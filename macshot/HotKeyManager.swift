import Carbon.HIToolbox
import Foundation
import os.log

/// Registers one global hotkey via Carbon's RegisterEventHotKey, and lets
/// the binding be changed later (e.g. when the user picks a new one in
/// Settings) without reinstalling the event handler.
///
/// Each instance needs its own `id`: the keyboard event handler is
/// installed on the shared application event target, so with more than one
/// manager alive, every instance's handler receives every hotkey event —
/// the `id` is how a handler tells "my hotkey fired" from "some other
/// manager's did".
final class HotKeyManager {
    private static let log = Logger(subsystem: "at.teibler.macshot", category: "hotkey")

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let onTrigger: () -> Void
    private let hotKeyID: EventHotKeyID

    init(id: UInt32, onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
        self.hotKeyID = EventHotKeyID(signature: OSType(UInt32(bitPattern: 0x6D637368)), id: id) // 'mcsh'
        installHandler()
    }

    deinit {
        unregister()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    /// `RegisterEventHotKey`'s status was previously discarded — a failed
    /// registration (e.g. a combo already claimed by another app, or by
    /// this app's *other* hotkey) meant the hotkey silently never fired
    /// again, with no way to tell why. Now logged instead.
    func update(keyCode: UInt32, modifiers: UInt32) {
        unregister()
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        if status != noErr {
            Self.log.error("RegisterEventHotKey failed for id \(self.hotKeyID.id, privacy: .public): OSStatus \(status, privacy: .public)")
        }
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

        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return noErr }

            var receivedID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &receivedID
            )
            guard status == noErr else { return noErr }

            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            if receivedID.signature == manager.hotKeyID.signature && receivedID.id == manager.hotKeyID.id {
                manager.onTrigger()
            }
            return noErr
        }, 1, &eventType, selfPtr, &eventHandler)
    }
}
