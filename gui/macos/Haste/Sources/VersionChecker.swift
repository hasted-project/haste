/*
 * VersionChecker.swift
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

import Foundation
import AppKit

/// Checks for new versions of Haste on GitHub
class VersionChecker {
    
    /// Current app version (from Info.plist)
    private let currentVersion: String
    
    /// GitHub repository owner/name (e.g., "username/haste")
    private let githubRepo: String
    
    /// UserDefaults key for last check date
    private let lastCheckKey = "LastUpdateCheckDate"
    
    /// Minimum time between checks (24 hours)
    private let checkInterval: TimeInterval = 24 * 60 * 60
    
    init(githubRepo: String) {
        self.githubRepo = githubRepo
        
        // Get version from Info.plist
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            self.currentVersion = version
        } else {
            self.currentVersion = "0.1.0"
        }
    }
    
    /// Check for updates (respects check interval)
    func checkForUpdates(force: Bool = false) {
        // Check if we should skip (unless forced)
        if !force {
            if let lastCheck = UserDefaults.standard.object(forKey: lastCheckKey) as? Date {
                let timeSinceLastCheck = Date().timeIntervalSince(lastCheck)
                if timeSinceLastCheck < checkInterval {
                    return // Skip check, too soon
                }
            }
        }
        
        // Update last check date
        UserDefaults.standard.set(Date(), forKey: lastCheckKey)
        
        // Perform check asynchronously
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
    
    /// Show alert to user about available update
    private func showUpdateAlert(currentVersion: String, latestVersion: String, downloadURL: String?, releaseNotes: String?) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = """
        A new version of Haste is available!
        
        Current version: \(currentVersion)
        Latest version: \(latestVersion)
        
        \(releaseNotes?.prefix(200) ?? "")
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // User clicked "Download"
            if let urlString = downloadURL,
               let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

