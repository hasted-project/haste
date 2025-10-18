/*
 * ClipboardMonitor.swift
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

import AppKit
import Foundation

/// Monitors the system clipboard and saves new items to the database
public class ClipboardMonitor {
    private let core: CoreBridge
    private var lastChangeCount: Int = 0
    private var timer: Timer?
    private let pollInterval: TimeInterval = 0.5 // 500ms
    
    public init(core: CoreBridge) {
        self.core = core
        self.lastChangeCount = NSPasteboard.general.changeCount
    }
    
    /// Start monitoring the clipboard
    public func start() {
        timer = Timer.scheduledTimer(
            withTimeInterval: pollInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkClipboard()
        }
        
        // Run immediately
        checkClipboard()
    }
    
    /// Stop monitoring the clipboard
    public func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    /// Check if clipboard has changed and capture content
    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let changeCount = pasteboard.changeCount
        
        // No change
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount
        
        // Check for images FIRST before text, because browsers often include both
        // image data and URL text when you copy an image
        let imageTypes: [NSPasteboard.PasteboardType] = [
            .tiff,
            .png,
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("public.png"),
            NSPasteboard.PasteboardType("public.image")
        ]
        
        if pasteboard.availableType(from: imageTypes) != nil {
            captureImage(pasteboard, sourceApp: getActiveApp())
        } else if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty {
            // Only treat as files if they are actual file:// URLs, not web URLs
            let fileURLs = urls.filter { $0.isFileURL }
            if !fileURLs.isEmpty {
                captureFiles(fileURLs, sourceApp: getActiveApp())
            } else {
                // Web URLs - treat as text
                if let string = pasteboard.string(forType: .string) {
                    captureText(string, sourceApp: getActiveApp())
                }
            }
        } else if let rtf = pasteboard.data(forType: .rtf) {
            captureRTF(rtf, sourceApp: getActiveApp())
        } else if let string = pasteboard.string(forType: .string) {
            captureText(string, sourceApp: getActiveApp())
        }
    }
    
    /// Capture plain text
    private func captureText(_ text: String, sourceApp: String?) {
        // Skip empty strings
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { 
            return
        }
        
        // Use dedupe_insert to avoid duplicate clipboard entries
        _ = core.dedupeInsert(
            kind: .text,
            contentRef: text,
            sourceApp: sourceApp
        )
    }
    
    /// Capture RTF content
    private func captureRTF(_ data: Data, sourceApp: String?) {
        if let string = String(data: data, encoding: .utf8) {
            _ = core.dedupeInsert(
                kind: .rtf,
                contentRef: string,
                sourceApp: sourceApp
            )
        }
    }
    
    /// Capture files
    private func captureFiles(_ urls: [URL], sourceApp: String?) {
        for url in urls {
            _ = core.dedupeInsert(
                kind: .file,
                contentRef: url.path,
                sourceApp: sourceApp
            )
        }
    }
    
    /// Capture image from pasteboard
    private func captureImage(_ pasteboard: NSPasteboard, sourceApp: String?) {
        // Try multiple image formats that browsers might provide
        let imageData = pasteboard.data(forType: .tiff) 
            ?? pasteboard.data(forType: .png)
            ?? pasteboard.data(forType: NSPasteboard.PasteboardType("public.jpeg"))
            ?? pasteboard.data(forType: NSPasteboard.PasteboardType("public.png"))
            ?? pasteboard.data(forType: NSPasteboard.PasteboardType("public.image"))
        
        guard let imageData = imageData else { return }
        
        // Create images directory if it doesn't exist
        let imagesDir = getImagesDirectory()
        
        // Save image to disk
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let fileName = "image_\(timestamp).png"
        let imagePath = imagesDir.appendingPathComponent(fileName)
        
        // Convert to PNG and save
        if let image = NSImage(data: imageData),
           let tiffData = image.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapImage.representation(using: .png, properties: [:]) {
            
            do {
                try pngData.write(to: imagePath)
                
                // Store the full path in the database
                _ = core.addItem(
                    kind: .image,
                    contentRef: imagePath.path,
                    sourceApp: sourceApp
                )
            } catch {
                // Silently fail - image couldn't be saved
            }
        }
    }
    
    /// Get or create the images storage directory
    private func getImagesDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let hasteDir = appSupport.appendingPathComponent("Haste")
        let imagesDir = hasteDir.appendingPathComponent("images")
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: imagesDir.path) {
            try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        }
        
        return imagesDir
    }
    
    /// Get the currently active application name
    private func getActiveApp() -> String? {
        // This requires accessibility permissions
        // For MVP, we'll return nil and add this later
        if let app = NSWorkspace.shared.frontmostApplication {
            return app.localizedName
        }
        return nil
    }
}

