# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-01-30

### Added - Premium Media Vault Design System
- **Complete UI redesign** with "Premium Media Vault" aesthetic
  - Deep cinematic blacks as foundation (`#0F0F14`)
  - Warm amber accents for actions (`#FFC24D`)
  - Purple luminosity for Dolby Vision content (`#AD73FA`)
  - Spatial audio blue for Atmos badges (`#59BFF2`)
- **Design System** (`DesignSystem.swift`) with comprehensive tokens:
  - VaultColors: Surface colors, text hierarchy, accent colors
  - VaultSpacing: Consistent spacing scale (xxs to xxxl)
  - VaultTypography: Display, headline, body, caption, mono styles
  - VaultRadius: Border radius scale
- **Reusable components**: VaultCard, VaultBadge, VaultMetric, VaultProgressRing, VaultFilterChip, VaultEmptyState
- **Quality Gradient signature**: Premium content (HDR, Atmos) literally glows

### Added - Interactive Dashboard
- **Clickable metrics**:
  - Total Files → Shows all files in Files tab
  - HDR Content → Filters to HDR files only
  - Immersive Audio → Filters to Atmos/DTS:X files
- **Clickable chart legends**: Click any item to filter Files tab
  - Resolution chart items (4K, 1080p, etc.)
  - Video codec items (HEVC, H.264, etc.)
  - HDR format items (Dolby Vision, HDR10, etc.)
  - Audio codec items
  - Container format items

### Added - Enhanced Filtering
- **Quick Filter Bar** on Files tab with horizontal scroll
  - Resolution quick filters: 8K, 4K, 1440p, 1080p, 720p
  - HDR quick filters: Dolby Vision, HDR10, HDR10+
  - Audio quick filters: Atmos, DTS:X
  - Active filter count indicator with Clear button
- **Resolution filtering** in main filter popover
- **Multi-select support** for all filter categories

### Added - Clickable Error Logs
- Error log entries for failed files now show folder icon
- Click error entry to reveal file location in Finder
- Helps manual inspection of problematic files

### Changed
- Dashboard metrics now show chevron indicators when clickable
- Charts use gradient fills and custom styled legends
- File icons glow based on content quality (HDR, Atmos)
- HDR badges use VaultBadge component with glow effect
- Sidebar redesigned with LIBRARY and IMMERSIVE stat sections

### Technical
- Added `filterResolutions: Set<String>` to AppState
- Added `filterImmersiveAudio: Bool?` for OR logic filtering
- Added navigation helper methods in AppState
- LogEntry now includes optional `filePath` for clickable errors
- Resolution filtering implemented in VideoFileRepository

## [1.1.0] - 2025-01-30

### Added
- Column header click-to-sort functionality
- Resizable columns (drag header dividers)
- Click file row to reveal in Finder with file pre-selected
- Comprehensive project documentation (PROJECT_CONTEXT.md, ARCHITECTURE.md)
- Inline code comments for complex logic

### Changed
- Resolution display simplified: "1920x1080" → "1080p", "3840x2160" → "4K"
- Duration format: "01:23:45" → "1:23:45" (no leading zero on hours)
- Bitrate display: Added Gbps support for high bitrate files
- Added 8K and 360p resolution categories

## [1.0.0] - 2025-01-30

### Added
- Initial release
- High-performance concurrent scanning (12 parallel ffprobe processes)
- Comprehensive metadata extraction for video, audio, and container formats
- HDR detection: Dolby Vision, HDR10, HDR10+, HLG
- Immersive audio detection: Dolby Atmos, DTS:X
- Dashboard with Swift Charts visualizations
- File browser with sorting, filtering, and search
- Pause/resume scanning with checkpoint saves
- Crash recovery on app relaunch
- Export to CSV, JSON, and PDF formats
- Integrity checking via full decode test
- Duplicate detection (exact hash, partial hash, fuzzy matching)
- Retry logic with exponential backoff for network volumes
- Context menu actions: Reveal in Finder, Open, Copy path
- Keyboard shortcuts for common actions
- Clear All Data option to reset the library

### Technical
- Built with SwiftUI and Swift Actors
- SQLite database with GRDB.swift (WAL mode)
- Optimized for 20,000+ file libraries
- Bundled ffprobe support with Homebrew fallback
