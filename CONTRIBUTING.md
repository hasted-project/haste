# Contributing to Haste

Thank you for your interest in contributing to Haste! We welcome contributions from the community.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [How to Contribute](#how-to-contribute)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Pull Request Process](#pull-request-process)

## Code of Conduct

Please be respectful and constructive in all interactions. We aim to foster a welcoming and inclusive community.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/your-username/haste.git
   cd haste
   ```
3. **Add the upstream remote**:
   ```bash
   git remote add upstream https://github.com/hasted-project/haste.git
   ```
4. **Build the project**:
   ```bash
   make build
   ```

## Development Setup

### Prerequisites

- macOS 13.0 or later
- Xcode Command Line Tools
- Rust toolchain (installed automatically by cargo)

### Building

```bash
# Full build
make build

# Build Rust core only
cd core/osp_core && cargo build --release

# Run in debug mode with console output
./debug.sh
```

### Project Structure

- `core/osp_core/` - Rust core library (database, search, FFI)
- `gui/macos/Haste/Sources/` - Swift macOS UI
- `Makefile` - Build automation

## How to Contribute

### Reporting Bugs

Before creating a bug report, please check existing issues to avoid duplicates.

**A good bug report should include**:
- Clear, descriptive title
- macOS version
- Steps to reproduce
- Expected behavior
- Actual behavior
- Screenshots/logs if applicable
- Any relevant error messages

### Suggesting Features

We love new ideas! Open an issue with:
- Clear description of the feature
- Use cases and benefits
- Potential implementation approach (if you have ideas)

### Code Contributions

We welcome pull requests for:
- Bug fixes
- New features
- Performance improvements
- Documentation improvements
- Tests

## Coding Standards

### Rust Code

- Follow standard Rust formatting: `cargo fmt`
- Run clippy and fix warnings: `cargo clippy`
- Add tests for new functionality
- Document public APIs with doc comments
- Keep functions focused and small

**Example**:
```rust
/// Inserts a new clipboard item, avoiding duplicates.
///
/// If an item with the same content hash exists, updates its timestamp
/// instead of creating a duplicate.
///
/// # Arguments
/// * `kind` - The type of clipboard item
/// * `content_ref` - The content or reference to content
/// * `source_app` - Optional name of the app where content was copied
///
/// # Returns
/// The ID of the inserted or updated item, or None on error
pub fn dedupe_insert(
    &self,
    kind: ItemKind,
    content_ref: &str,
    source_app: Option<&str>,
) -> Option<i64> {
    // Implementation...
}
```

### Swift Code

- Follow Swift naming conventions
- Use meaningful variable names
- Add comments for complex logic
- Use MARK comments to organize code
- Prefer immutability where possible

**Example**:
```swift
// MARK: - Clipboard Monitoring

/// Monitors the system clipboard and captures new items
private func checkClipboard() {
    let pasteboard = NSPasteboard.general
    let changeCount = pasteboard.changeCount
    
    // Only process if clipboard changed
    guard changeCount != lastChangeCount else { return }
    lastChangeCount = changeCount
    
    // Capture based on content type
    if let text = pasteboard.string(forType: .string) {
        captureText(text, sourceApp: getActiveApp())
    }
}
```

### Commit Messages

Follow conventional commit format:

```
type(scope): subject

body (optional)

footer (optional)
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting)
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Test additions/changes
- `chore`: Build/tooling changes

**Examples**:
```
feat(search): add fuzzy search support

fix(clipboard): handle image capture from browsers

docs(readme): update installation instructions

refactor(core): simplify dedupe logic
```

## Testing

### Running Tests

```bash
# Run all tests
make test

# Run Rust tests only
cargo test -p osp_core

# Run specific test
cargo test -p osp_core test_search_text_items

# Run tests with output
cargo test -p osp_core -- --nocapture
```

### Writing Tests

#### Rust Tests

Add tests in `core/osp_core/tests/` or as inline tests:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_feature_name() {
        // Arrange
        let core = Core::open_in_memory().unwrap();
        
        // Act
        let result = core.some_function();
        
        // Assert
        assert!(result.is_some());
    }
}
```

#### Manual Testing

1. Build and run: `./debug.sh`
2. Test all content types (text, images, files)
3. Test keyboard navigation
4. Test search functionality
5. Test edge cases (empty clipboard, large items)

## Pull Request Process

1. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**:
   - Write clean, focused code
   - Add tests if applicable
   - Update documentation

3. **Test thoroughly**:
   ```bash
   make test
   make build
   # Manual testing...
   ```

4. **Commit your changes**:
   ```bash
   git add .
   git commit -m "feat(search): add amazing feature"
   ```

5. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Create a Pull Request** on GitHub:
   - Use a clear title and description
   - Reference any related issues
   - Include screenshots/GIFs for UI changes
   - Wait for review and address feedback

### PR Checklist

- [ ] Code follows project style guidelines
- [ ] Tests added/updated for new functionality
- [ ] All tests pass (`make test`)
- [ ] Documentation updated if needed
- [ ] Commit messages follow conventional format
- [ ] No unnecessary debug/console logs
- [ ] PR description clearly explains changes

## Questions?

- **GitHub Issues** - For bugs and feature requests
- **GitHub Discussions** - For questions and general discussion

Thank you for contributing to Haste! 🎉

