/*
 * SearchWindow.swift
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

/// Main search window with modern card-based horizontal layout
class SearchWindow: NSObject, NSWindowDelegate, NSCollectionViewDataSource, NSCollectionViewDelegate, NSTextFieldDelegate {
    private let core: CoreBridge
    private var window: NSPanel!
    private var searchField: NSTextField!
    private var collectionView: NSCollectionView!
    private var allItems: [CoreBridge.Item] = [] // All items for fuzzy filtering
    private var items: [CoreBridge.Item] = [] // Currently displayed items
    private var previousApp: NSRunningApplication?
    private var filterButtons: [NSButton] = []
    private var currentFilter: FilterType = .all
    
    enum FilterType {
        case all
        case pinned
    }
    
    init(core: CoreBridge) {
        self.core = core
        super.init()
        setupWindow()
    }
    
    func show() {
        // Remember the currently active app so we can return to it after pasting
        previousApp = NSWorkspace.shared.frontmostApplication
        
        // ALWAYS refresh items when window is shown to get latest clipboard items
        allItems.removeAll()
        
        // Clear search field and reload recent items
        searchField.stringValue = ""
        performSearch("")
        
        // Select first item by default
        if items.count > 0 {
            collectionView.selectItems(at: [IndexPath(item: 0, section: 0)], scrollPosition: .centeredHorizontally)
        }
        
        // Position at bottom before showing
        positionWindowAtBottom()
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        searchField.becomeFirstResponder()
        
        // Set up click-outside-to-dismiss
        setupClickOutsideMonitor()
    }
    
    private var clickOutsideMonitor: Any?
    
    private func setupClickOutsideMonitor() {
        // Remove existing monitor if any
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        // Monitor clicks outside the window
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return }
            
            // Get the click location in screen coordinates
            let clickLocation = NSEvent.mouseLocation
            let windowFrame = self.window.frame
            
            // Check if click is outside window bounds
            if !NSPointInRect(clickLocation, windowFrame) {
                self.window.orderOut(nil)
                self.removeClickOutsideMonitor()
            }
        }
    }
    
    private func removeClickOutsideMonitor() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
    }
    
    // MARK: - Setup
    
    private func setupWindow() {
        // Get screen dimensions first
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        
        // Create borderless floating panel that spans full width
        let windowHeight: CGFloat = 500
        let windowWidth = screenFrame.width
        
        window = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.level = .floating
        window.delegate = self
        window.isMovableByWindowBackground = false
        window.backgroundColor = NSColor(calibratedRed: 0.11, green: 0.12, blue: 0.15, alpha: 0.95)
        window.hasShadow = true
        window.isOpaque = false
        
        // Allow window to accept input
        window.acceptsMouseMovedEvents = true
        window.ignoresMouseEvents = false
        
        // Position at bottom of screen
        positionWindowAtBottom()
        
        setupUI()
        
        // Load initial results (empty query = recent items)
        performSearch("")
    }
    
    private func positionWindowAtBottom() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let windowSize = window.frame.size
        
        // Align with screen edges at bottom
        let x = screenFrame.origin.x
        let y = screenFrame.origin.y
        
        window.setFrame(NSRect(x: x, y: y, width: screenFrame.width, height: windowSize.height), display: true)
    }
    
    private func setupUI() {
        guard let contentView = window.contentView else { return }
        
        // Add rounded corners only on top (since window spans full width at bottom)
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 16
        contentView.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner] // Top corners only
        contentView.layer?.masksToBounds = true
        
        // Top bar container
        let topBar = NSView(frame: .zero)
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.wantsLayer = true
        topBar.layer?.backgroundColor = NSColor(calibratedWhite: 0.1, alpha: 0.95).cgColor
        contentView.addSubview(topBar)
        
        // Search icon button with background
        let searchIconBtn = NSButton(frame: .zero)
        searchIconBtn.translatesAutoresizingMaskIntoConstraints = false
        searchIconBtn.wantsLayer = true
        searchIconBtn.layer?.backgroundColor = NSColor(calibratedRed: 0.2, green: 0.4, blue: 0.8, alpha: 0.3).cgColor
        searchIconBtn.layer?.cornerRadius = 8
        searchIconBtn.isBordered = false
        searchIconBtn.bezelStyle = .regularSquare
        searchIconBtn.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")!
        searchIconBtn.contentTintColor = NSColor(calibratedRed: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)
        searchIconBtn.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        searchIconBtn.target = self
        searchIconBtn.action = #selector(focusSearchField(_:))
        topBar.addSubview(searchIconBtn)
        
        // All button
        let allBtn = createFilterButton(title: "All", isActive: true)
        allBtn.target = self
        allBtn.action = #selector(filterAll(_:))
        topBar.addSubview(allBtn)
        filterButtons.append(allBtn)
        
        // Pinned button
        let pinnedBtn = createFilterButton(title: "Pinned", isActive: false)
        pinnedBtn.target = self
        pinnedBtn.action = #selector(filterPinned(_:))
        topBar.addSubview(pinnedBtn)
        filterButtons.append(pinnedBtn)
        
        // Menu button
        let menuBtn = NSButton(frame: .zero)
        menuBtn.translatesAutoresizingMaskIntoConstraints = false
        menuBtn.title = "⋯"
        menuBtn.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        menuBtn.bezelStyle = .rounded
        menuBtn.isBordered = false
        menuBtn.contentTintColor = .white
        menuBtn.target = self
        menuBtn.action = #selector(showMenu(_:))
        topBar.addSubview(menuBtn)
        
        // Hidden search field (for text input)
        searchField = NSTextField(frame: .zero)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = ""
        searchField.delegate = self
        searchField.isBordered = false
        searchField.backgroundColor = .clear
        searchField.textColor = .white
        searchField.font = NSFont.systemFont(ofSize: 14)
        topBar.addSubview(searchField)
        
        // Collection view with horizontal flow layout
        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.scrollDirection = .horizontal
        flowLayout.itemSize = NSSize(width: 240, height: 320)
        flowLayout.minimumInteritemSpacing = 20
        flowLayout.minimumLineSpacing = 20
        flowLayout.sectionInset = NSEdgeInsets(top: 20, left: 30, bottom: 20, right: 30)
        
        collectionView = NSCollectionView(frame: .zero)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.collectionViewLayout = flowLayout
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = false
        collectionView.backgroundColors = [NSColor.clear]
        collectionView.register(ClipboardCardItem.self, forItemWithIdentifier: NSUserInterfaceItemIdentifier("ClipboardCard"))
        
        let scrollView = NSScrollView(frame: .zero)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = collectionView
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        contentView.addSubview(scrollView)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Top bar
            topBar.topAnchor.constraint(equalTo: contentView.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 60),
            
            // Search icon button
            searchIconBtn.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 20),
            searchIconBtn.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            searchIconBtn.widthAnchor.constraint(equalToConstant: 40),
            searchIconBtn.heightAnchor.constraint(equalToConstant: 40),
            
            allBtn.leadingAnchor.constraint(equalTo: searchIconBtn.trailingAnchor, constant: 20),
            allBtn.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            
            pinnedBtn.leadingAnchor.constraint(equalTo: allBtn.trailingAnchor, constant: 20),
            pinnedBtn.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            
            menuBtn.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -20),
            menuBtn.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            
            searchField.leadingAnchor.constraint(equalTo: pinnedBtn.trailingAnchor, constant: 30),
            searchField.trailingAnchor.constraint(equalTo: menuBtn.leadingAnchor, constant: -20),
            searchField.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    private func createFilterButton(title: String, isActive: Bool) -> NSButton {
        let btn = NSButton(frame: .zero)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.title = title
        btn.font = NSFont.systemFont(ofSize: 13, weight: isActive ? .semibold : .regular)
        btn.bezelStyle = .rounded
        btn.isBordered = false
        btn.contentTintColor = isActive ? .white : NSColor.gray
        return btn
    }
    
    @objc private func showMenu(_ sender: NSButton) {
        let menu = NSMenu()
        
        // Clear History option
        let clearHistoryItem = NSMenuItem(
            title: "Clear History",
            action: #selector(clearHistory),
            keyEquivalent: ""
        )
        clearHistoryItem.target = self
        menu.addItem(clearHistoryItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // About option
        let aboutItem = NSMenuItem(
            title: "About Haste",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        // Show menu below button
        let buttonFrame = sender.frame
        let menuOrigin = NSPoint(x: buttonFrame.maxX - 150, y: buttonFrame.minY - 5)
        menu.popUp(positioning: nil, at: menuOrigin, in: sender.superview)
    }
    
    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear Clipboard History?"
        alert.informativeText = "This will permanently delete all clipboard items. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // User confirmed, clear all items
            let itemsToDelete = allItems.map { $0.id }
            var deletedCount = 0
            
            for itemId in itemsToDelete {
                _ = core.deleteItem(id: itemId)
                deletedCount += 1
            }
            
            // Refresh the view
            allItems.removeAll()
            items.removeAll()
            collectionView.reloadData()
            
            // Show confirmation
            let confirmAlert = NSAlert()
            confirmAlert.messageText = "History Cleared"
            confirmAlert.informativeText = "Deleted \(deletedCount) clipboard items."
            confirmAlert.alertStyle = .informational
            confirmAlert.addButton(withTitle: "OK")
            confirmAlert.runModal()
        }
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Haste"
        alert.informativeText = "A fast, native clipboard manager for macOS.\n\nVersion 1.0\n\nPress Cmd+Shift+V to open\nArrow keys to navigate\nEnter to copy\nRight-click to pin/unpin\nEscape to close"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func filterAll(_ sender: NSButton) {
        currentFilter = .all
        updateFilterButtons()
        performSearch(searchField.stringValue)
    }
    
    @objc private func filterPinned(_ sender: NSButton) {
        currentFilter = .pinned
        updateFilterButtons()
        performSearch(searchField.stringValue)
    }
    
    private func updateFilterButtons() {
        for (index, button) in filterButtons.enumerated() {
            let isActive = (index == 0 && currentFilter == .all) || (index == 1 && currentFilter == .pinned)
            button.font = NSFont.systemFont(ofSize: 13, weight: isActive ? .semibold : .regular)
            button.contentTintColor = isActive ? .white : NSColor.gray
        }
    }
    
    @objc private func focusSearchField(_ sender: NSButton) {
        window.makeFirstResponder(searchField)
        searchField.becomeFirstResponder()
    }
    
    // MARK: - Search
    
    private func performSearch(_ query: String) {
        // Load all items if not loaded yet or refresh
        if allItems.isEmpty || query.isEmpty {
            allItems = core.search(query: "", limit: 500) // Get more items for fuzzy filtering
        }
        
        // Apply filter based on current filter type
        var filteredItems = allItems
        if currentFilter == .pinned {
            filteredItems = allItems.filter { $0.pinned }
        }
        
        if query.isEmpty {
            // Show filtered items
            items = Array(filteredItems.prefix(100))
        } else {
            // Fuzzy filter on the client side
            items = fuzzyFilter(items: filteredItems, query: query)
        }
        
        collectionView.reloadData()
        
        // Select first item after reload
        if items.count > 0 {
            collectionView.selectItems(at: [IndexPath(item: 0, section: 0)], scrollPosition: .centeredHorizontally)
        }
    }
    
    /// Fuzzy filter items - matches if query characters appear in order (case insensitive)
    /// Example: "hlo" matches "hello world", "abc" matches "alphabet soup"
    /// Only shows text items during search for better relevance
    private func fuzzyFilter(items: [CoreBridge.Item], query: String) -> [CoreBridge.Item] {
        let lowercaseQuery = query.lowercased()
        let queryChars = Array(lowercaseQuery)
        
        return items.filter { item in
            // Only show text items during search
            guard item.kind == .text else { return false }
            
            let content = item.contentRef.lowercased()
            var queryIndex = 0
            
            // Try to find all query characters in order
            for char in content {
                if queryIndex < queryChars.count && char == queryChars[queryIndex] {
                    queryIndex += 1
                }
            }
            
            // Match if we found all query characters
            return queryIndex == queryChars.count
        }
    }
    
    // MARK: - NSTextFieldDelegate
    
    func controlTextDidChange(_ obj: Notification) {
        let query = searchField.stringValue
        performSearch(query)
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        // Handle arrow keys and Enter
        switch commandSelector {
        case #selector(NSResponder.moveRight(_:)): // Right arrow
            moveSelectionRight()
            return true
            
        case #selector(NSResponder.moveLeft(_:)): // Left arrow
            moveSelectionLeft()
            return true
            
        case #selector(NSResponder.moveDown(_:)): // Down arrow - also navigate right
            moveSelectionRight()
            return true
            
        case #selector(NSResponder.moveUp(_:)): // Up arrow - also navigate left
            moveSelectionLeft()
            return true
            
        case #selector(NSResponder.insertNewline(_:)): // Enter key
            copySelectedItem()
            return true
            
        case #selector(NSResponder.cancelOperation(_:)): // Escape key
            window.orderOut(nil)
            removeClickOutsideMonitor()
            return true
            
        default:
            return false
        }
    }
    
    // MARK: - NSCollectionViewDataSource
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier("ClipboardCard"), for: indexPath) as! ClipboardCardItem
        let dataItem = items[indexPath.item]
        item.configure(with: dataItem, index: indexPath.item)
        item.onPin = { [weak self] itemId, shouldPin in
            self?.togglePin(itemId: itemId, shouldPin: shouldPin)
        }
        return item
    }
    
    private func togglePin(itemId: Int64, shouldPin: Bool) {
        _ = core.pinItem(id: itemId, pinned: shouldPin)
        // Refresh items to reflect the change
        allItems.removeAll()
        performSearch(searchField.stringValue)
    }
    
    // MARK: - NSCollectionViewDelegate
    
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        if let indexPath = indexPaths.first {
            copyItemAt(index: indexPath.item)
        }
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        // Clear search when window closes
        searchField.stringValue = ""
        removeClickOutsideMonitor()
    }
    
    // MARK: - Helpers
    
    private func moveSelectionRight() {
        guard items.count > 0 else { return }
        
        // Get current selection
        let selectedIndexPaths = collectionView.selectionIndexPaths
        let currentIndex = selectedIndexPaths.first?.item ?? -1
        let nextIndex = min(currentIndex + 1, items.count - 1)
        
        // Only move if not at the end
        if nextIndex != currentIndex {
            // Deselect old items explicitly
            for indexPath in selectedIndexPaths {
                if let oldItem = collectionView.item(at: indexPath) as? ClipboardCardItem {
                    oldItem.updateSelection(false)
                }
            }
            
            // Deselect all
            collectionView.deselectAll(nil)
            
            // Select new item
            let newIndexPath = IndexPath(item: nextIndex, section: 0)
            collectionView.selectItems(at: [newIndexPath], scrollPosition: .centeredHorizontally)
            
            // Force visual update
            if let newItem = collectionView.item(at: newIndexPath) as? ClipboardCardItem {
                newItem.updateSelection(true)
            }
        }
    }
    
    private func moveSelectionLeft() {
        guard items.count > 0 else { return }
        
        // Get current selection
        let selectedIndexPaths = collectionView.selectionIndexPaths
        let currentIndex = selectedIndexPaths.first?.item ?? 1
        let prevIndex = max(currentIndex - 1, 0)
        
        // Only move if not at the beginning
        if prevIndex != currentIndex {
            // Deselect old items explicitly
            for indexPath in selectedIndexPaths {
                if let oldItem = collectionView.item(at: indexPath) as? ClipboardCardItem {
                    oldItem.updateSelection(false)
                }
            }
            
            // Deselect all
            collectionView.deselectAll(nil)
            
            // Select new item
            let newIndexPath = IndexPath(item: prevIndex, section: 0)
            collectionView.selectItems(at: [newIndexPath], scrollPosition: .centeredHorizontally)
            
            // Force visual update
            if let newItem = collectionView.item(at: newIndexPath) as? ClipboardCardItem {
                newItem.updateSelection(true)
            }
        }
    }
    
    private func copySelectedItem() {
        let selectedIndexPaths = collectionView.selectionIndexPaths
        guard let indexPath = selectedIndexPaths.first else { return }
        copyItemAt(index: indexPath.item)
    }
    
    private func copyItemAt(index: Int) {
        guard index >= 0, index < items.count else { return }
        
        let item = items[index]
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        // Handle different item types
        switch item.kind {
        case .text:
            // Plain text - just set the string
            _ = pasteboard.setString(item.contentRef, forType: .string)
            
        case .rtf:
            // RTF - convert string back to data and set as RTF
            if let rtfData = item.contentRef.data(using: .utf8) {
                _ = pasteboard.setData(rtfData, forType: .rtf)
                // Also set as plain text fallback
                if let plainText = String(data: rtfData, encoding: .utf8) {
                    _ = pasteboard.setString(plainText, forType: .string)
                }
            }
            
        case .file:
            // File - convert path to URL and set as file URL
            let fileURL = URL(fileURLWithPath: item.contentRef)
            if FileManager.default.fileExists(atPath: item.contentRef) {
                _ = pasteboard.writeObjects([fileURL as NSURL])
            } else {
                // File doesn't exist anymore, copy path as text fallback
                _ = pasteboard.setString(item.contentRef, forType: .string)
            }
            
        case .image:
            // Image - load from stored path and copy to clipboard
            let imageURL = URL(fileURLWithPath: item.contentRef)
            if let image = NSImage(contentsOf: imageURL) {
                _ = pasteboard.writeObjects([image])
            } else {
                // Image file doesn't exist anymore
                _ = pasteboard.setString("[Image not found: \(imageURL.lastPathComponent)]", forType: .string)
            }
        }
        
        // Close window and clean up
        window.orderOut(nil)
        removeClickOutsideMonitor()
        
        // Activate previous app so user can paste with Cmd+V
        if let app = previousApp {
            app.activate(options: .activateIgnoringOtherApps)
        }
    }
    
    private func iconForKind(_ kind: CoreBridge.Item.ItemKind) -> String {
        switch kind {
        case .text: return "📝"
        case .rtf: return "📄"
        case .image: return "🖼"
        case .file: return "📁"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - ClipboardCardItem

class ClipboardCardItem: NSCollectionViewItem {
    private var typeLabel: NSTextField!
    private var timeLabel: NSTextField!
    private var iconView: NSImageView!
    private var contentLabel: NSTextField!
    private var imagePreview: NSImageView!
    private var charCountLabel: NSTextField!
    private var indexLabel: NSTextField!
    private var cardView: NSView!
    private var pinIndicator: NSImageView!
    var onPin: ((Int64, Bool) -> Void)?
    
    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        
        // Card container
        cardView = NSView(frame: .zero)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.wantsLayer = true
        cardView.layer?.cornerRadius = 12
        cardView.layer?.backgroundColor = NSColor(calibratedRed: 0.15, green: 0.16, blue: 0.19, alpha: 1.0).cgColor
        view.addSubview(cardView)
        
        // Type badge
        typeLabel = NSTextField(labelWithString: "Text")
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        typeLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        typeLabel.textColor = .white
        cardView.addSubview(typeLabel)
        
        // Time label
        timeLabel = NSTextField(labelWithString: "15 hours ago")
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = NSFont.systemFont(ofSize: 10)
        timeLabel.textColor = NSColor.gray
        cardView.addSubview(timeLabel)
        
        // Icon
        iconView = NSImageView(image: NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)!)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentTintColor = .white
        cardView.addSubview(iconView)
        
        // Content (text)
        contentLabel = NSTextField(wrappingLabelWithString: "")
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        contentLabel.font = NSFont.systemFont(ofSize: 13)
        contentLabel.textColor = .white
        contentLabel.maximumNumberOfLines = 6
        contentLabel.lineBreakMode = .byTruncatingTail
        cardView.addSubview(contentLabel)
        
        // Image preview (for image items)
        imagePreview = NSImageView()
        imagePreview.translatesAutoresizingMaskIntoConstraints = false
        imagePreview.imageScaling = .scaleProportionallyUpOrDown
        imagePreview.wantsLayer = true
        imagePreview.layer?.cornerRadius = 8
        imagePreview.layer?.masksToBounds = true
        imagePreview.isHidden = true // Hidden by default
        cardView.addSubview(imagePreview)
        
        // Character count
        charCountLabel = NSTextField(labelWithString: "13 characters")
        charCountLabel.translatesAutoresizingMaskIntoConstraints = false
        charCountLabel.font = NSFont.systemFont(ofSize: 10)
        charCountLabel.textColor = NSColor.gray
        cardView.addSubview(charCountLabel)
        
        // Index label
        indexLabel = NSTextField(labelWithString: "1")
        indexLabel.translatesAutoresizingMaskIntoConstraints = false
        indexLabel.font = NSFont.systemFont(ofSize: 10)
        indexLabel.textColor = NSColor.gray
        indexLabel.alignment = .right
        cardView.addSubview(indexLabel)
        
        // Pin indicator (star icon)
        pinIndicator = NSImageView(image: NSImage(systemSymbolName: "star.fill", accessibilityDescription: "Pinned")!)
        pinIndicator.translatesAutoresizingMaskIntoConstraints = false
        pinIndicator.contentTintColor = NSColor.systemYellow
        pinIndicator.isHidden = true
        cardView.addSubview(pinIndicator)
        
        // Add right-click gesture recognizer
        let rightClick = NSClickGestureRecognizer(target: self, action: #selector(handleRightClick(_:)))
        rightClick.buttonMask = 0x2 // Right mouse button
        view.addGestureRecognizer(rightClick)
        
        // Layout
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: view.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            typeLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            typeLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            
            timeLabel.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 4),
            timeLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            
            iconView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            iconView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),
            
            contentLabel.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 20),
            contentLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            contentLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            
            imagePreview.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 20),
            imagePreview.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            imagePreview.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            imagePreview.heightAnchor.constraint(equalToConstant: 120),
            
            charCountLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16),
            charCountLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            
            indexLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16),
            indexLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            
            pinIndicator.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            pinIndicator.leadingAnchor.constraint(equalTo: typeLabel.trailingAnchor, constant: 8),
            pinIndicator.widthAnchor.constraint(equalToConstant: 14),
            pinIndicator.heightAnchor.constraint(equalToConstant: 14)
        ])
    }
    
    @objc private func handleRightClick(_ sender: NSClickGestureRecognizer) {
        guard let item = representedObject as? CoreBridge.Item else { return }
        
        let menu = NSMenu()
        let pinTitle = item.pinned ? "Unpin" : "Pin"
        let pinItem = NSMenuItem(title: pinTitle, action: #selector(togglePinAction), keyEquivalent: "")
        pinItem.target = self
        menu.addItem(pinItem)
        
        NSMenu.popUpContextMenu(menu, with: NSApp.currentEvent!, for: view)
    }
    
    @objc private func togglePinAction() {
        guard let item = representedObject as? CoreBridge.Item else { return }
        onPin?(item.id, !item.pinned)
    }
    
    func configure(with item: CoreBridge.Item, index: Int) {
        // Store item for selection tracking
        self.representedObject = item
        
        // Determine display content first (needed for type detection)
        var displayContent = item.contentRef
        if item.kind == .rtf {
            // Convert RTF to plain text for display
            if let rtfData = item.contentRef.data(using: .utf8),
               let attributedString = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
                displayContent = attributedString.string
            }
        }
        
        // Type (now with correct content for link detection)
        let typeName = typeNameForKind(item.kind, content: displayContent)
        typeLabel.stringValue = typeName
        
        // Time
        let date = Date(timeIntervalSince1970: Double(item.createdAt) / 1000.0)
        timeLabel.stringValue = formatRelativeTime(date)
        
        // Icon
        iconView.image = imageForKind(item.kind, content: displayContent)
        
        // Content - show image preview for images, text for others
        if item.kind == .image {
            // Show image thumbnail
            let imageURL = URL(fileURLWithPath: item.contentRef)
            if let image = NSImage(contentsOf: imageURL) {
                imagePreview.image = image
                imagePreview.isHidden = false
                contentLabel.isHidden = true
                
                // Show file name instead of path for character count
                charCountLabel.stringValue = imageURL.lastPathComponent
            } else {
                // Image not found, show path
                contentLabel.stringValue = "[Image not found]"
                contentLabel.isHidden = false
                imagePreview.isHidden = true
                charCountLabel.stringValue = imageURL.lastPathComponent
            }
        } else {
            // Show text content (use displayContent for RTF)
            contentLabel.stringValue = displayContent
            contentLabel.isHidden = false
            imagePreview.isHidden = true
            charCountLabel.stringValue = "\(displayContent.count) characters"
        }
        
        // Index
        indexLabel.stringValue = "\(index + 1)"
        
        // Pin indicator
        pinIndicator.isHidden = !item.pinned
        
        // Colors based on type
        updateColors(for: item.kind, content: displayContent, isSelected: isSelected)
    }
    
    override var isSelected: Bool {
        didSet {
            if let item = representedObject as? CoreBridge.Item {
                updateColors(for: item.kind, content: contentLabel.stringValue, isSelected: isSelected)
            } else {
                // Fallback: update colors based on content if no represented object
                updateColors(for: .text, content: contentLabel.stringValue, isSelected: isSelected)
            }
        }
    }
    
    func updateSelection(_ selected: Bool) {
        self.isSelected = selected
        if let item = representedObject as? CoreBridge.Item {
            updateColors(for: item.kind, content: contentLabel.stringValue, isSelected: selected)
        }
    }
    
    private func updateColors(for kind: CoreBridge.Item.ItemKind, content: String, isSelected: Bool) {
        if isSelected {
            // Blue for selected
            cardView.layer?.backgroundColor = NSColor(calibratedRed: 0.2, green: 0.4, blue: 0.8, alpha: 1.0).cgColor
            cardView.layer?.borderWidth = 2
            cardView.layer?.borderColor = NSColor(calibratedRed: 0.3, green: 0.5, blue: 0.9, alpha: 1.0).cgColor
        } else {
            // Different colors for different types
            switch kind {
            case .text:
                if isLink(content) {
                    // Cyan for links
                    cardView.layer?.backgroundColor = NSColor(calibratedRed: 0.2, green: 0.7, blue: 0.8, alpha: 1.0).cgColor
                } else {
                    // Dark gray for regular text
                    cardView.layer?.backgroundColor = NSColor(calibratedRed: 0.15, green: 0.16, blue: 0.19, alpha: 1.0).cgColor
                }
            case .rtf:
                // Yellow for RTF/rich content
                cardView.layer?.backgroundColor = NSColor(calibratedRed: 0.9, green: 0.7, blue: 0.2, alpha: 1.0).cgColor
            case .image:
                // Purple for images
                cardView.layer?.backgroundColor = NSColor(calibratedRed: 0.6, green: 0.3, blue: 0.8, alpha: 1.0).cgColor
            case .file:
                // Orange for files
                cardView.layer?.backgroundColor = NSColor(calibratedRed: 0.9, green: 0.5, blue: 0.2, alpha: 1.0).cgColor
            }
            cardView.layer?.borderWidth = 0
        }
    }
    
    private func isLink(_ content: String) -> Bool {
        return content.hasPrefix("http://") || content.hasPrefix("https://") || content.hasPrefix("www.")
    }
    
    private func typeNameForKind(_ kind: CoreBridge.Item.ItemKind, content: String) -> String {
        switch kind {
        case .text:
            if isLink(content) {
                return "Link"
            }
            return "Text"
        case .rtf: return "Rich Text"
        case .image: return "Image"
        case .file: return "File"
        }
    }
    
    private func imageForKind(_ kind: CoreBridge.Item.ItemKind, content: String) -> NSImage? {
        let symbolName: String
        switch kind {
        case .text:
            if isLink(content) {
                symbolName = "link"
            } else {
                symbolName = "doc.text"
            }
        case .rtf: symbolName = "doc.richtext"
        case .image: symbolName = "photo"
        case .file: symbolName = "folder"
        }
        return NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - KeyablePanel

/// Custom NSPanel subclass that can become key window (for keyboard input)
class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

