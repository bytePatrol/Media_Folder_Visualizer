# Contributing to Video Analyzer

Thank you for your interest in contributing to Video Analyzer! This document provides guidelines and information for contributors.

## Getting Started

### Prerequisites
- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later
- ffprobe (install via `brew install ffmpeg`)

### Setting Up the Development Environment

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/yourusername/VideoAnalyzer.git
   cd VideoAnalyzer
   ```
3. Open the project in Xcode:
   ```bash
   open VideoAnalyzer.xcodeproj
   ```
4. Build and run (Cmd+R)

## Development Guidelines

### Code Style
- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Keep functions focused and concise
- Add comments for complex logic

### Architecture
- **Models**: Data structures and database models
- **Views**: SwiftUI views, organized by feature
- **Services**: Business logic, organized by domain
  - Use Swift Actors for thread safety
  - Use Combine for reactive data flow

### Design System
The app uses a comprehensive design system in `Views/DesignSystem.swift`. When adding UI:

- **Use design tokens**: `VaultColors`, `VaultSpacing`, `VaultTypography`, `VaultRadius`
- **Use reusable components**: `VaultCard`, `VaultBadge`, `VaultFilterChip`, etc.
- **Follow the "Premium Media Vault" aesthetic**:
  - Dark surfaces with warm amber accents
  - Premium content (HDR, Atmos) should glow
  - Text uses "celluloid" warm white tones
- See `.interface-design/system.md` for full design documentation

### Commit Messages
- Use clear, descriptive commit messages
- Start with a verb (Add, Fix, Update, Remove, Refactor)
- Keep the first line under 72 characters

Examples:
```
Add duplicate detection by file hash
Fix crash when scanning network volumes
Update resolution labels to simplified format
```

## Pull Request Process

1. Create a feature branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes and test thoroughly

3. Ensure the project builds without warnings:
   ```bash
   xcodebuild -project VideoAnalyzer.xcodeproj -scheme VideoAnalyzer -configuration Debug
   ```

4. Commit your changes with a clear message

5. Push to your fork and create a Pull Request

6. Describe your changes in the PR description:
   - What does this PR do?
   - How was it tested?
   - Any breaking changes?

## Reporting Issues

When reporting issues, please include:
- macOS version
- App version
- Steps to reproduce
- Expected vs actual behavior
- Any error messages or logs

## Feature Requests

Feature requests are welcome! Please:
- Check existing issues first to avoid duplicates
- Describe the use case and expected behavior
- Explain why this would benefit other users

## Testing

### Manual Testing Checklist
- [ ] Scan a folder with various video formats
- [ ] Verify HDR detection (if you have HDR content)
- [ ] Test pause/resume during a scan
- [ ] Force-quit and verify recovery on relaunch
- [ ] Test with a large library (1000+ files)
- [ ] Verify export functionality (CSV, JSON, PDF)
- [ ] Test duplicate detection
- [ ] Test integrity checking

### Test Content
For comprehensive testing, include videos with:
- Various codecs (H.264, H.265, VP9, AV1)
- Different resolutions (480p to 4K)
- HDR formats (Dolby Vision, HDR10)
- Atmos/DTS:X audio tracks
- Various containers (MKV, MP4, MOV)

## Questions?

Feel free to open an issue for any questions about contributing.
