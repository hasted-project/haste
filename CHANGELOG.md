# Changelog

All notable changes to Haste will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

