# Haste 📋

<p align="center">
  <strong>A fast, beautiful, and private clipboard manager for macOS</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2013.0%2B-blue" alt="Platform">
  <img src="https://img.shields.io/badge/language-Swift%20%7C%20Rust-orange" alt="Language">
  <img src="https://img.shields.io/badge/license-GPL%20v3-blue" alt="License">
</p>

---

## ✨ Features

- **⚡️ Lightning Fast** - Built with Rust + SQLite FTS5 for instant search across thousands of clipboard items
- **🎨 Modern UI** - Beautiful, card-based interface with smooth animations
- **🔒 100% Private** - Everything stays on your Mac. No cloud, no analytics, no network access
- **⌨️ Keyboard-First** - Navigate entirely with keyboard shortcuts
- **🎯 Native Performance** - Pure AppKit/SwiftUI, no Electron bloat
- **🔍 Smart Search** - Full-text search with fuzzy matching
- **📦 Rich Content Support** - Text, RTF, images, files, and URLs
- **🎭 Type-Based Filtering** - Filter by content type while searching
- **🔄 Auto-Update Check** - Automatically checks for new versions on launch

## 🚀 Quick Start

### Requirements

- macOS 13.0 or later
- Xcode Command Line Tools (for building from source)

### Installation

#### From Source

```bash
# Clone the repository
git clone https://github.com/hasted-project/haste.git
cd haste

# Build and run
make run
```

That's it! Haste will start and appear in your menu bar. Press **Cmd+Shift+V** to open the clipboard history.

#### Install to Applications Folder

```bash
make install
```

This will build and copy Haste.app to `/Applications/`.

## 📖 Usage

### Basic Workflow

1. **Copy anything** - Haste automatically captures everything you copy
2. **Press Cmd+Shift+V** - Open the clipboard history
3. **Search** - Type to filter items instantly
4. **Navigate** - Use arrow keys (← →) to browse items
5. **Select** - Press **Enter** to copy the selected item
6. **Paste** - Press **Cmd+V** in your target app

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+Shift+V` | Open clipboard history |
| `←` `→` | Navigate between items |
| `Enter` | Copy selected item |
| `Escape` | Close window |
| Type text | Search/filter items |

### Content Types

Haste intelligently handles different clipboard content:

- **📝 Text** - Plain text and formatted text
- **📄 RTF** - Rich text with formatting
- **🖼 Images** - Screenshots and copied images
- **📁 Files** - File paths and file references
- **🔗 URLs** - Web links (treated as text)

### Menu Bar

Click the Haste icon in your menu bar for quick actions:

- **Search...** - Open clipboard history
- **Preferences** - Configure settings (coming soon)
- **Quit Haste** - Exit the application

## 🏗️ Development

### Building from Source

```bash
# Build the Rust core and Swift UI
make build

# Run the app
make run

# Run in debug mode with console output
./debug.sh

# Run tests
make test

# Clean build artifacts
make clean
```

### Project Structure

```
haste/
├── core/
│   └── osp_core/           # Rust core library
│       ├── src/
│       │   ├── lib.rs      # Core API
│       │   ├── db.rs       # SQLite database
│       │   ├── search.rs   # Full-text search
│       │   ├── models.rs   # Data models
│       │   └── ffi.rs      # FFI bindings
│       └── tests/          # Integration tests
├── gui/
│   └── macos/
│       └── Haste/
│           └── Sources/
│               ├── AppDelegate.swift      # App lifecycle
│               ├── SearchWindow.swift     # Main UI
│               ├── ClipboardMonitor.swift # Clipboard watching
│               ├── CoreBridge.swift       # Rust FFI bridge
│               └── GlobalHotkey.swift     # Hotkey registration
└── Makefile                # Build system
```

### Architecture

**Haste** is built with a hybrid architecture:

- **Rust Core** - High-performance database operations, search, and data management
- **Swift UI** - Native macOS interface using AppKit
- **FFI Bridge** - Zero-copy communication between Rust and Swift

This design provides:
- Native performance and low memory usage
- Type-safe database operations
- Fast full-text search (FTS5)
- Beautiful native macOS UI

### Development Tools

```bash
# Open Swift files in Xcode for autocomplete
open -a Xcode gui/macos/Haste/Sources/*.swift

# Run Rust tests
cargo test -p osp_core

# Format Rust code
cargo fmt

# Lint Rust code
cargo clippy
```

## 🗄️ Data Storage

Haste stores all data locally on your Mac:

- **Database**: `~/Library/Application Support/Haste/haste.db`
- **Images**: `~/Library/Application Support/Haste/images/`
- **Blobs**: `~/Library/Application Support/Haste/blobs/`

To clear all clipboard history, use the **Clear History** option from the three-dot menu in the app.

## 🔧 Configuration

Haste works great out of the box! Advanced configuration options coming soon.

## 🔄 Updates

Haste automatically checks for new versions when you launch the app (once per day). 

**Manual Check:**
- Click the Haste menu bar icon
- Select "Check for Updates..."

**What gets checked:**
- GitHub releases for your configured repository
- Compares semantic versions (e.g., 0.1.0 vs 0.2.0)
- Shows release notes and download link

**Privacy:**
- Only connects to GitHub API when checking updates
- No analytics or tracking
- You control when to update

## 🤝 Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Bug Reports

Found a bug? Please open an issue with:
- macOS version
- Steps to reproduce
- Expected vs actual behavior
- Screenshots if applicable

### Feature Requests

Have an idea? Open an issue with the `enhancement` label!

## 🛣️ Roadmap

- [ ] Preferences UI
- [ ] Custom hotkey configuration
- [ ] Sync between Macs (optional, encrypted)
- [ ] Pinned items
- [ ] Smart collections
- [ ] iCloud sync support

## 📄 License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

**What this means:**
- ✅ You can freely use, modify, and distribute this software
- ✅ You can use it for commercial purposes
- ⚠️ If you distribute modified versions, you must also license them under GPLv3
- ⚠️ You must disclose your source code when distributing
- ⚠️ Changes must be documented

For more information, see [https://www.gnu.org/licenses/gpl-3.0.html](https://www.gnu.org/licenses/gpl-3.0.html)

## 🙏 Acknowledgments

Built with:
- [Rust](https://www.rust-lang.org/) - Core engine
- [Swift](https://swift.org/) - Native macOS UI
- [SQLite](https://www.sqlite.org/) - Database with FTS5
- [AppKit](https://developer.apple.com/documentation/appkit) - macOS UI framework

## 💬 Support

- **Issues**: [GitHub Issues](https://github.com/hasted-project/haste/issues)
- **Discussions**: [GitHub Discussions](https://github.com/hasted-project/haste/discussions)

---

<p align="center">
  Made with ❤️ for macOS
</p>
