import Carbon.HIToolbox
import Foundation

final class HotKeyManager {
    static let shared = HotKeyManager()

    private let signature = OSType(0x464C4B59) // "FLKY"
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var eventHandler: EventHandlerRef?

    private init() {}

    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, identifier: UInt32, handler: @escaping () -> Void) -> Bool {
        installEventHandlerIfNeeded()
        unregister(identifier: identifier)
        handlers[identifier] = handler

        var hotKeyID = EventHotKeyID(signature: signature, id: identifier)
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef)
        guard status == noErr, let ref = hotKeyRef else {
            handlers.removeValue(forKey: identifier)
            return false
        }
        hotKeyRefs[identifier] = ref
        return true
    }

    func unregister(identifier: UInt32) {
        if let ref = hotKeyRefs.removeValue(forKey: identifier) {
            UnregisterEventHotKey(ref)
        }
        handlers.removeValue(forKey: identifier)
    }

    func unregisterAll() {
        for ref in hotKeyRefs.values {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        handlers.removeAll()

        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }

        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let handlerStatus = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, eventRef, userData in
                guard let userData = userData else { return noErr }
                guard let eventRef else { return noErr }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handlers[hotKeyID.id]?()
                return noErr
            },
            1,
            &eventSpec,
            selfPointer,
            &eventHandler
        )

        if handlerStatus != noErr {
            eventHandler = nil
        }
    }
}
