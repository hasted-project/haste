/*
 * VersionChecker.swift
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

import Foundation
import AppKit

/// Checks for new versions of Haste on GitHub
class VersionChecker {
    
    /// Current app version (from Info.plist)
    private let currentVersion: String
    private let githubRepo: String
    
    init(githubRepo: String) {
        self.githubRepo = githubRepo
        
        // Get version from Info.plist
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            self.currentVersion = version
        } else {
            self.currentVersion = "0.1.0"
        }
    }
    
    /// Check for updates (always checks on every call)
    func checkForUpdates(force: Bool = false) {
        print("🔍 [Update Check] Starting check")
        // Always perform the check
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.performUpdateCheck()
        }
    }
    
    /// Perform the actual update check
    private func performUpdateCheck() {
        guard let url = URL(string: "https://api.github.com/repos/\(githubRepo)/releases/latest") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Check for errors
            if error != nil {
                // Silently fail - don't bother user with network errors
                return
            }
            
            // Check response
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data else {
                return
            }
            
            // Parse JSON
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let tagName = json?["tag_name"] as? String else {
                    return
                }
                
                // Remove 'v' prefix if present (e.g., "v1.0.0" -> "1.0.0")
                let latestVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
                
                // Compare versions
                if self.isNewerVersion(latestVersion, than: self.currentVersion) {
                    // New version available!
                    let downloadURL = json?["html_url"] as? String
                    let releaseNotes = json?["body"] as? String
                    
                    DispatchQueue.main.async {
                        self.showUpdateAlert(
                            currentVersion: self.currentVersion,
                            latestVersion: latestVersion,
                            downloadURL: downloadURL,
                            releaseNotes: releaseNotes
                        )
                    }
                }
            } catch {
                // Silently fail on JSON parsing errors
            }
        }
        
        task.resume()
    }
    
    /// Compare two semantic versions (e.g., "1.2.3")
    private func isNewerVersion(_ new: String, than current: String) -> Bool {
        let newComponents = new.split(separator: ".").compactMap { Int($0) }
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }
        
        // Pad arrays to same length
        let maxLength = max(newComponents.count, currentComponents.count)
        let newPadded = newComponents + Array(repeating: 0, count: maxLength - newComponents.count)
        let currentPadded = currentComponents + Array(repeating: 0, count: maxLength - currentComponents.count)
        
        // Compare component by component
        for i in 0..<maxLength {
            if newPadded[i] > currentPadded[i] {
                return true
            } else if newPadded[i] < currentPadded[i] {
                return false
            }
        }
        
        return false // Versions are equal
    }
    
    /// Format markdown text for display in alert
    private func formatReleaseNotes(_ notes: String?) -> String {
        guard let notes = notes, !notes.isEmpty else {
            return "No release notes available."
        }
        
        // Clean up markdown formatting
        var formatted = notes
            .replacingOccurrences(of: "### ", with: "• ")
            .replacingOccurrences(of: "## ", with: "")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "`", with: "")
            
        
        return formatted.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Show alert to user about available update
    private func showUpdateAlert(currentVersion: String, latestVersion: String, downloadURL: String?, releaseNotes: String?) {
        let alert = NSAlert()
        alert.messageText = "✨ Haste v\(latestVersion) is Available!"
        
        // Create a custom view for better formatting
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 450, height: 280))
        view.wantsLayer = true
        
        
        // Title label
        let title = NSTextField(labelWithString: "A new version of Haste is ready to install!")
        title.font = NSFont.boldSystemFont(ofSize: 13)
        title.frame = NSRect(x: 0, y: 250, width: 430, height: 20)
        view.addSubview(title)
        
        // Version info
        let versionText = "You're currently on v\(currentVersion). Update to v\(latestVersion) for the latest features and improvements."
        let versionLabel = NSTextField(wrappingLabelWithString: versionText)
        versionLabel.frame = NSRect(x: 0, y: 210, width: 430, height: 40)
        versionLabel.font = NSFont.systemFont(ofSize: 12)
        versionLabel.textColor = .secondaryLabelColor
        view.addSubview(versionLabel)
        
        // Release notes container with border
        let container = NSView(frame: NSRect(x: 0, y: 50, width: 430, height: 160))
        container.wantsLayer = true
        container.layer?.cornerRadius = 4
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.separatorColor.cgColor
        
        // Scroll view for release notes
        let scrollView = NSScrollView(frame: NSRect(x: 5, y: 5, width: 420, height: 150))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.verticalScrollElasticity = .automatic

        
        // Text view for release notes
        let notesLabel = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 0))
        notesLabel.string = formatReleaseNotes(releaseNotes)
        notesLabel.font = NSFont.systemFont(ofSize: 12)
        notesLabel.textContainerInset = NSSize(width: 8, height: 8)
        notesLabel.isEditable = false
        notesLabel.isSelectable = true
        notesLabel.isAutomaticLinkDetectionEnabled = true
        notesLabel.drawsBackground = true
        notesLabel.backgroundColor = .clear
        notesLabel.wantsLayer = true

        guard let layoutManager = notesLabel.layoutManager,
              let textContainer = notesLabel.textContainer else {
            fatalError("NSTextView setup failed") 
        }

        // 2. Force them to lay out the text
        layoutManager.ensureLayout(for: textContainer)

        // 3. Get the *actual* height of the laid-out text
        let textHeight = layoutManager.usedRect(for: textContainer).height
        let verticalInsets = notesLabel.textContainerInset.height * 2
        let totalHeight = textHeight + verticalInsets

        // 6. Set the frame, using your new minimum height logic
        // This sets the width you want, and a height of *at least* 150.
        notesLabel.frame = NSRect(x: 0, y: 0, width: 400, height: max(150, totalHeight))
        
        // Setup scroll view
        scrollView.contentView.wantsLayer = true
        scrollView.documentView = notesLabel
        container.addSubview(scrollView)
        view.addSubview(container)
        
        // Divider
        let divider = NSBox()
        divider.boxType = .separator
        divider.frame = NSRect(x: 0, y: 40, width: 430, height: 1)
        view.addSubview(divider)
        
        // Configure alert
        alert.accessoryView = view
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download Update").keyEquivalent = "\r"
        alert.addButton(withTitle: "Later")
        
        // Show alert and handle response
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn, let urlString = downloadURL, let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
            NSApp.terminate(nil)
        }
    }
}

