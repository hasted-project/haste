/*
 * CoreBridge.swift
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

/// Swift wrapper around the Rust osp_core library
public class CoreBridge {
    private var handle: OpaquePointer?
    
    /// Represents a clipboard item
    public struct Item {
        public let id: Int64
        public let kind: ItemKind
        public let contentRef: String
        public let sourceApp: String?
        public let createdAt: Int64
        public let pinned: Bool
        public let tags: [String]
        
        public enum ItemKind: Int32 {
            case text = 0
            case rtf = 1
            case image = 2
            case file = 3
        }
    }
    
    /// Initialize with database path
    public init?(dbPath: String, blobsDir: String) {
        guard let handle = core_new(dbPath, blobsDir) else {
            return nil
        }
        self.handle = handle
    }
    
    deinit {
        if let handle = handle {
            core_free(handle)
        }
    }
    
    /// Add a new item to the clipboard
    public func addItem(
        kind: Item.ItemKind,
        contentRef: String,
        sourceApp: String? = nil,
        createdAt: Int64? = nil
    ) -> Int64? {
        guard let handle = handle else { return nil }
        
        let timestamp = createdAt ?? Int64(Date().timeIntervalSince1970 * 1000)
        let id = core_add_item(
            handle,
            kind.rawValue,
            contentRef,
            sourceApp,
            timestamp
        )
        
        return id >= 0 ? id : nil
    }
    
    /// Add item with deduplication
    /// Returns: item ID if inserted, nil if duplicate or error
    public func dedupeInsert(
        kind: Item.ItemKind,
        contentRef: String,
        sourceApp: String? = nil,
        createdAt: Int64? = nil
    ) -> Int64? {
        guard let handle = handle else { return nil }
        
        let timestamp = createdAt ?? Int64(Date().timeIntervalSince1970 * 1000)
        let result = core_dedupe_insert(
            handle,
            kind.rawValue,
            contentRef,
            sourceApp,
            timestamp
        )
        
        switch result {
        case let id where id > 0: return id
        case 0: return nil // Duplicate
        default: return nil // Error
        }
    }
    
    /// Search for items
    public func search(query: String, limit: UInt32 = 100) -> [Item] {
        guard let handle = handle else { return [] }
        guard let arrayPtr = core_search(handle, query, limit) else { return [] }
        defer { item_array_free(arrayPtr) }
        
        let array = arrayPtr.pointee
        guard array.count > 0, let items = array.items else { return [] }
        
        var results: [Item] = []
        for i in 0..<array.count {
            let cItem = items[i]
            if let item = convertCItem(cItem) {
                results.append(item)
            }
        }
        
        return results
    }
    
    /// Get a single item by ID
    public func getItem(id: Int64) -> Item? {
        guard let handle = handle else { return nil }
        guard let itemPtr = core_get_item(handle, id) else { return nil }
        defer { item_free(itemPtr) }
        
        return convertCItem(itemPtr.pointee)
    }
    
    /// Delete an item
    public func deleteItem(id: Int64) -> Bool {
        guard let handle = handle else { return false }
        return core_delete_item(handle, id) == 0
    }
    
    /// Pin or unpin an item
    public func pinItem(id: Int64, pinned: Bool) -> Bool {
        guard let handle = handle else { return false }
        return core_pin_item(handle, id, pinned ? 1 : 0) == 0
    }
    
    // MARK: - Private Helpers
    
    private func convertCItem(_ cItem: CItem) -> Item? {
        guard let contentRef = String(cString: cItem.content_ref, encoding: .utf8) else {
            return nil
        }
        
        let sourceApp = cItem.source_app != nil
            ? String(cString: cItem.source_app, encoding: .utf8)
            : nil
        
        let tags = cItem.tags_json != nil
            ? parseTagsJSON(String(cString: cItem.tags_json, encoding: .utf8) ?? "[]")
            : []
        
        guard let kind = Item.ItemKind(rawValue: cItem.kind) else {
            return nil
        }
        
        return Item(
            id: cItem.id,
            kind: kind,
            contentRef: contentRef,
            sourceApp: sourceApp,
            createdAt: cItem.created_at,
            pinned: cItem.pinned != 0,
            tags: tags
        )
    }
    
    private func parseTagsJSON(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let tags = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return tags
    }
}

