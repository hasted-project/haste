/*
 * GlobalHotkey.swift
 * Haste - Fast, native clipboard manager for macOS
 *
 * Copyright (C) 2024 Haste Project Contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

import Cocoa
import Carbon

/// Global hotkey manager using Carbon Event Manager
class GlobalHotkey {
    private let keyCode: UInt32
    private let modifiers: NSEvent.ModifierFlags
    private let callback: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    init(keyCode: UInt32, modifiers: NSEvent.ModifierFlags, callback: @escaping () -> Void) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.callback = callback
    }
    
    deinit {
        unregister()
    }
    
    func register() {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = UTGetOSTypeFromString("hast" as CFString)
        hotKeyID.id = 1
        
        var carbonModifiers: UInt32 = 0
        if modifiers.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if modifiers.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        if modifiers.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if modifiers.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        
        let eventSpec = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                         eventKind: UInt32(kEventHotKeyPressed))
        ]
        
        // Store callback in a way we can access it
        let callbackPtr = UnsafeMutablePointer<() -> Void>.allocate(capacity: 1)
        callbackPtr.pointee = callback
        
        var handler: EventHandlerRef?
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                if let userData = userData {
                    let callback = userData.load(as: (() -> Void).self)
                    callback()
                }
                return noErr
            },
            1,
            eventSpec,
            callbackPtr,
            &handler
        )
        
        self.eventHandler = handler
        
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        
        if status == noErr {
            self.hotKeyRef = ref
        }
    }
    
    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }
}

