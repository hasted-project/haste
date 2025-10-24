/*
 * AppDelegate.swift
 * Haste - Fast, native clipboard manager for macOS
 *
 * Copyright (C) 2025 Haste Project Contributors
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
import Carbon.HIToolbox

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var core: CoreBridge!
    private var clipboardMonitor: ClipboardMonitor!
    private var searchWindow: SearchWindow?
    private var globalHotkey: GlobalHotkey?
    private var versionChecker: VersionChecker?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup Core
        do {
            try setupCore()
        } catch {
            NSAlert.showError("Failed to initialize Haste: \(error.localizedDescription)")
            NSApp.terminate(nil)
            return
        }
        
        // Setup Menu Bar
        setupMenuBar()
        
        // Setup Global Hotkey (Cmd+Shift+V)
        setupGlobalHotkey()
        
        // Start clipboard monitoring
        clipboardMonitor = ClipboardMonitor(core: core)
        clipboardMonitor.start()
        
        // Setup version checker and check for updates
        versionChecker = VersionChecker(githubRepo: "hasted-project/haste")
        versionChecker?.checkForUpdates()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor.stop()
        globalHotkey?.unregister()
    }
    
    // MARK: - Setup
    
    private func setupCore() throws {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let appSupport = homeDir
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
            .appendingPathComponent("Haste")
        
        // Create directory if needed
        try FileManager.default.createDirectory(
            at: appSupport,
            withIntermediateDirectories: true
        )
        
        let dbPath = appSupport.appendingPathComponent("haste.db").path
        let blobsDir = appSupport.appendingPathComponent("blobs").path
        
        guard let core = CoreBridge(dbPath: dbPath, blobsDir: blobsDir) else {
            throw NSError(domain: "HasteCore", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to initialize Haste core"
            ])
        }
        
        self.core = core
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Use SF Symbol for clipboard
            if let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Haste") {
                button.image = image
            } else {
                button.title = "📋"
            }
        }
        
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(
            title: "Search... (⌘⇧V)",
            action: #selector(showSearch),
            keyEquivalent: ""
        ))
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(
            title: "Preferences...",
            action: #selector(showPreferences),
            keyEquivalent: ","
        ))
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(
            title: "Check for Updates...",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        ))
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(
            title: "Quit Haste",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        
        statusItem.menu = menu
    }
    
    private func setupGlobalHotkey() {
        // Register the global hotkey (Cmd+Shift+V)
        globalHotkey = GlobalHotkey(
            keyCode: UInt32(kVK_ANSI_V),
            modifiers: [.command, .shift]
        ) { [weak self] in
            self?.showSearch()
        }
        
        globalHotkey?.register()
    }
    
    // MARK: - Actions
    
    @objc private func showSearch() {
        if searchWindow == nil {
            searchWindow = SearchWindow(core: core)
        }
        searchWindow?.show()
    }
    
    @objc private func showPreferences() {
        let alert = NSAlert()
        alert.messageText = "Preferences"
        alert.informativeText = "Preferences UI coming soon!\n\nFor now, check ~/Library/Application Support/Haste/"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func checkForUpdates() {
        versionChecker?.checkForUpdates(force: true)
    }
}

extension NSAlert {
    static func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
