# Haste Makefile
# Simple commands to build and run Haste

# Paths
PROJECT_ROOT := $(shell pwd)
RUST_LIB := $(PROJECT_ROOT)/target/release/libosp_core.a
SWIFT_SRC := $(PROJECT_ROOT)/gui/macos/Haste/Sources
SWIFT_BIN := $(PROJECT_ROOT)/gui/macos/Haste/Haste
APP_BUNDLE := $(PROJECT_ROOT)/gui/macos/Haste.app

# Colors
BLUE := \033[0;34m
GREEN := \033[0;32m
NC := \033[0m # No Color

.PHONY: all build run clean install help

# Default target
all: build

# Build everything
build: rust swift bundle
	@echo "$(GREEN)✅ Build complete!$(NC)"
	@echo ""
	@echo "Run with: make run"

# Build Rust core library
rust:
	@echo "$(BLUE)📦 Building Rust core library...$(NC)"
	@cargo build --release -p osp_core --quiet

# Compile Swift application
swift: rust
	@echo "$(BLUE)🦅 Compiling Swift code...$(NC)"
	@mkdir -p gui/macos/Haste/lib
	@cp $(RUST_LIB) gui/macos/Haste/lib/
	@cd gui/macos/Haste && swiftc \
		-o Haste \
		-module-name Haste \
		-target arm64-apple-macos13.0 \
		-I . \
		-I lib \
		-L lib \
		lib/libosp_core.a \
		-import-objc-header osp_core-Bridging-Header.h \
		-framework Cocoa \
		-framework Carbon \
		Sources/*.swift

# Create .app bundle
bundle: swift
	@echo "$(BLUE)📦 Creating app bundle...$(NC)"
	@rm -rf $(APP_BUNDLE)
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@cp $(SWIFT_BIN) $(APP_BUNDLE)/Contents/MacOS/
	@printf '<?xml version="1.0" encoding="UTF-8"?>\n' > $(APP_BUNDLE)/Contents/Info.plist
	@printf '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n' >> $(APP_BUNDLE)/Contents/Info.plist
	@printf '<plist version="1.0">\n<dict>\n' >> $(APP_BUNDLE)/Contents/Info.plist
	@printf '  <key>CFBundleExecutable</key>\n  <string>Haste</string>\n' >> $(APP_BUNDLE)/Contents/Info.plist
	@printf '  <key>CFBundleIdentifier</key>\n  <string>com.haste.clipboard</string>\n' >> $(APP_BUNDLE)/Contents/Info.plist
	@printf '  <key>CFBundleName</key>\n  <string>Haste</string>\n' >> $(APP_BUNDLE)/Contents/Info.plist
	@printf '  <key>CFBundlePackageType</key>\n  <string>APPL</string>\n' >> $(APP_BUNDLE)/Contents/Info.plist
	@printf '  <key>CFBundleShortVersionString</key>\n  <string>1.0</string>\n' >> $(APP_BUNDLE)/Contents/Info.plist
	@printf '  <key>LSMinimumSystemVersion</key>\n  <string>13.0</string>\n' >> $(APP_BUNDLE)/Contents/Info.plist
	@printf '  <key>LSUIElement</key>\n  <true/>\n' >> $(APP_BUNDLE)/Contents/Info.plist
	@printf '  <key>NSPrincipalClass</key>\n  <string>NSApplication</string>\n' >> $(APP_BUNDLE)/Contents/Info.plist
	@printf '</dict>\n</plist>\n' >> $(APP_BUNDLE)/Contents/Info.plist
	@chmod +x $(APP_BUNDLE)/Contents/MacOS/Haste

# Run the application
run: build
	@echo "$(GREEN)🚀 Starting Haste...$(NC)"
	@pkill -9 Haste 2>/dev/null || true
	@sleep 0.5
	@open $(APP_BUNDLE)
	@echo "$(GREEN)✅ Haste is running!$(NC)"
	@echo ""
	@echo "Press Cmd+Shift+V to open search"

# Quick run without rebuild
start:
	@echo "$(GREEN)🚀 Starting Haste...$(NC)"
	@pkill -9 Haste 2>/dev/null || true
	@sleep 0.5
	@open $(APP_BUNDLE)

# Stop the application
stop:
	@echo "Stopping Haste..."
	@pkill -9 Haste 2>/dev/null || true
	@echo "$(GREEN)✅ Haste stopped$(NC)"

# Install to Applications folder
install: build
	@echo "$(BLUE)📦 Installing Haste to /Applications...$(NC)"
	@rm -rf /Applications/Haste.app
	@cp -r $(APP_BUNDLE) /Applications/
	@echo "$(GREEN)✅ Installed to /Applications/Haste.app$(NC)"
	@echo ""
	@echo "You can now:"
	@echo "  - Open from Spotlight (Cmd+Space, type 'Haste')"
	@echo "  - Add to Login Items in System Settings"

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	@rm -rf $(APP_BUNDLE)
	@rm -f $(SWIFT_BIN)
	@rm -rf gui/macos/Haste/lib
	@cargo clean
	@echo "$(GREEN)✅ Clean complete$(NC)"

# Development: watch and rebuild on file changes (requires fswatch)
watch:
	@echo "👀 Watching for changes... (Ctrl+C to stop)"
	@fswatch -o $(SWIFT_SRC)/*.swift | xargs -n1 -I{} make run

# Show help
help:
	@echo "$(GREEN)Haste Build System$(NC)"
	@echo ""
	@echo "Available commands:"
	@echo "  make build    - Build Rust core + Swift app"
	@echo "  make run      - Build and run Haste"
	@echo "  make start    - Run without rebuilding"
	@echo "  make stop     - Stop Haste"
	@echo "  make install  - Install to /Applications"
	@echo "  make clean    - Clean build artifacts"
	@echo "  make watch    - Auto-rebuild on changes (requires fswatch)"
	@echo ""
	@echo "Quick start:"
	@echo "  make run      - Build and launch Haste"

