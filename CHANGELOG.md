# Changelog

All notable changes to Haste will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2025-01-25

### Added
- **Pin Favorites** - Right-click any item to pin/unpin it for quick access
- **Pinned Filter** - New "Pinned" button to view only your favorite items
- **Visual Pin Indicator** - Yellow star icon shows which items are pinned
- **Clickable Search Icon** - Click the search icon to focus the search field
- **Enhanced Search Icon** - More visible search button with blue background
- **Link Detection** - URLs are now properly detected and labeled as "Link"
- **Improved RTF Display** - Rich text content now shows as readable text instead of raw markup

### Fixed
- Fixed type detection for copied URLs (now shows "Link" instead of "Text")
- Fixed RTF items displaying raw markup instead of formatted text
- Fixed search field focus behavior

### Changed
- Updated copyright year to 2025
- Simplified README for better user experience
- Prioritized DMG installation over building from source

## [0.1.0] - 2025-10-18

### Added
- Initial release of Haste
- Automatic clipboard monitoring
- Beautiful card-based UI with smooth animations
- Full-text search with fuzzy matching
- Support for text, RTF, images, and files
- Keyboard-first navigation (arrow keys, Enter, Escape)
- Global hotkey (Cmd+Shift+V) to open clipboard history
- Click outside to dismiss
- Clear history functionality
- Menu bar integration
- Auto-update checker (checks GitHub releases on launch)
- Manual "Check for Updates" menu option
- 100% local storage (no cloud, no analytics)
- SQLite database with FTS5 for fast search
- Rust core for performance
- Native macOS UI with AppKit

### Technical
- Hybrid Rust + Swift architecture
- FFI bridge between Rust and Swift
- Deduplication logic to avoid storing identical items
- Image storage system (PNG format)
- Type-based filtering during search
- Zero-copy data operations where possible

## [0.0.0] - 2025-10-18

### Initial Release

First public release of Haste clipboard manager.

**Features:**
- ⚡️ Lightning fast clipboard history
- 🎨 Modern, beautiful UI
- 🔒 100% private (everything stays local)
- ⌨️ Keyboard-driven workflow
- 🔍 Smart search and filtering

---

**Note**: This project is under active development. Breaking changes may occur before v1.0.0.

