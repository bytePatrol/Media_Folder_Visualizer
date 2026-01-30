import SwiftUI

struct FileListView: View {
    @EnvironmentObject var appState: AppState
    @State private var showFilterPopover = false

    var body: some View {
        VStack(spacing: 0) {
            FileListToolbar(showFilterPopover: $showFilterPopover)

            // Quick filter bar
            if hasActiveFilters || !appState.videoFiles.isEmpty {
                QuickFilterBar()
            }

            VaultDivider()

            if appState.videoFiles.isEmpty {
                EmptyFileListView()
            } else {
                FileTableView(files: appState.videoFiles)
            }

            VaultDivider()

            FileListStatusBar()
        }
        .background(VaultColors.vault)
        .navigationTitle("Files")
    }

    private var hasActiveFilters: Bool {
        !appState.filterVideoCodecs.isEmpty ||
        !appState.filterHDRFormats.isEmpty ||
        !appState.filterAudioCodecs.isEmpty ||
        !appState.filterContainers.isEmpty ||
        !appState.filterResolutions.isEmpty ||
        appState.filterHasAtmos != nil ||
        appState.filterHasDTSX != nil ||
        appState.filterImmersiveAudio != nil
    }
}

struct QuickFilterBar: View {
    @EnvironmentObject var appState: AppState

    private let resolutionOptions = ["8K", "4K", "1440p", "1080p", "720p"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VaultSpacing.sm) {
                // Active filters indicator
                if hasActiveFilters {
                    ActiveFiltersIndicator()
                }

                VaultDivider()
                    .frame(height: 20)

                // Resolution quick filters
                Text("Resolution:")
                    .font(VaultTypography.caption)
                    .foregroundColor(VaultColors.celluloidFaint)

                ForEach(resolutionOptions, id: \.self) { resolution in
                    QuickFilterChip(
                        label: resolution,
                        isSelected: appState.filterResolutions.contains(resolution),
                        color: VaultColors.chartBlue
                    ) {
                        toggleResolutionFilter(resolution)
                    }
                }

                VaultDivider()
                    .frame(height: 20)

                // HDR quick filters
                Text("HDR:")
                    .font(VaultTypography.caption)
                    .foregroundColor(VaultColors.celluloidFaint)

                QuickFilterChip(
                    label: "Dolby Vision",
                    isSelected: appState.filterHDRFormats.contains(.dolbyVision) || appState.filterHDRFormats.contains(.dolbyVisionHDR10),
                    color: VaultColors.dolby
                ) {
                    toggleDolbyVisionFilter()
                }

                QuickFilterChip(
                    label: "HDR10",
                    isSelected: appState.filterHDRFormats.contains(.hdr10),
                    color: VaultColors.hdr
                ) {
                    toggleHDRFormat(.hdr10)
                }

                QuickFilterChip(
                    label: "HDR10+",
                    isSelected: appState.filterHDRFormats.contains(.hdr10Plus),
                    color: VaultColors.chartAmber
                ) {
                    toggleHDRFormat(.hdr10Plus)
                }

                VaultDivider()
                    .frame(height: 20)

                // Audio quick filters
                Text("Audio:")
                    .font(VaultTypography.caption)
                    .foregroundColor(VaultColors.celluloidFaint)

                QuickFilterChip(
                    label: "Atmos",
                    isSelected: appState.filterHasAtmos == true,
                    color: VaultColors.atmos
                ) {
                    appState.filterHasAtmos = appState.filterHasAtmos == true ? nil : true
                    applyFilters()
                }

                QuickFilterChip(
                    label: "DTS:X",
                    isSelected: appState.filterHasDTSX == true,
                    color: VaultColors.dolby
                ) {
                    appState.filterHasDTSX = appState.filterHasDTSX == true ? nil : true
                    applyFilters()
                }
            }
            .padding(.horizontal, VaultSpacing.lg)
            .padding(.vertical, VaultSpacing.sm)
        }
        .background(VaultColors.screen)
    }

    private var hasActiveFilters: Bool {
        !appState.filterVideoCodecs.isEmpty ||
        !appState.filterHDRFormats.isEmpty ||
        !appState.filterAudioCodecs.isEmpty ||
        !appState.filterContainers.isEmpty ||
        !appState.filterResolutions.isEmpty ||
        appState.filterHasAtmos != nil ||
        appState.filterHasDTSX != nil ||
        appState.filterImmersiveAudio != nil
    }

    private func toggleResolutionFilter(_ resolution: String) {
        if appState.filterResolutions.contains(resolution) {
            appState.filterResolutions.remove(resolution)
        } else {
            appState.filterResolutions.insert(resolution)
        }
        applyFilters()
    }

    private func toggleDolbyVisionFilter() {
        let dvFormats: Set<HDRFormat> = [.dolbyVision, .dolbyVisionHDR10]
        if appState.filterHDRFormats.isSuperset(of: dvFormats) || appState.filterHDRFormats.contains(.dolbyVision) {
            appState.filterHDRFormats.subtract(dvFormats)
        } else {
            appState.filterHDRFormats.formUnion(dvFormats)
        }
        applyFilters()
    }

    private func toggleHDRFormat(_ format: HDRFormat) {
        if appState.filterHDRFormats.contains(format) {
            appState.filterHDRFormats.remove(format)
        } else {
            appState.filterHDRFormats.insert(format)
        }
        applyFilters()
    }

    private func applyFilters() {
        Task {
            await appState.refreshData()
        }
    }
}

struct ActiveFiltersIndicator: View {
    @EnvironmentObject var appState: AppState

    private var filterCount: Int {
        var count = 0
        count += appState.filterVideoCodecs.count
        count += appState.filterHDRFormats.count
        count += appState.filterAudioCodecs.count
        count += appState.filterContainers.count
        count += appState.filterResolutions.count
        if appState.filterHasAtmos != nil { count += 1 }
        if appState.filterHasDTSX != nil { count += 1 }
        if appState.filterImmersiveAudio != nil { count += 1 }
        return count
    }

    var body: some View {
        HStack(spacing: VaultSpacing.sm) {
            HStack(spacing: VaultSpacing.xs) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 10, weight: .medium))
                Text("\(filterCount) active")
                    .font(VaultTypography.captionMedium)
            }
            .foregroundColor(VaultColors.projection)

            Button {
                appState.clearFilters()
            } label: {
                HStack(spacing: VaultSpacing.xxs) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                    Text("Clear")
                        .font(VaultTypography.micro)
                }
                .foregroundColor(VaultColors.celluloidMuted)
                .padding(.horizontal, VaultSpacing.sm)
                .padding(.vertical, VaultSpacing.xs)
                .background(VaultColors.screenElevated)
                .clipShape(RoundedRectangle(cornerRadius: VaultRadius.sm, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

struct QuickFilterChip: View {
    let label: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(VaultTypography.captionMedium)
                .foregroundColor(isSelected ? VaultColors.vault : color)
                .padding(.horizontal, VaultSpacing.md)
                .padding(.vertical, VaultSpacing.xs)
                .background(isSelected ? color : color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: VaultRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: VaultRadius.md, style: .continuous)
                        .stroke(color.opacity(0.4), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct FileListToolbar: View {
    @EnvironmentObject var appState: AppState
    @Binding var showFilterPopover: Bool

    var body: some View {
        HStack(spacing: VaultSpacing.md) {
            VaultSearchField(
                text: $appState.searchText,
                placeholder: "Search files..."
            ) {
                Task {
                    await appState.refreshData()
                }
            }
            .frame(maxWidth: 280)

            Button {
                showFilterPopover.toggle()
            } label: {
                HStack(spacing: VaultSpacing.xs) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 12, weight: .medium))
                    Text("Filter")
                        .font(VaultTypography.bodyMedium)
                }
                .foregroundColor(hasActiveFilters ? VaultColors.projection : VaultColors.celluloidMuted)
            }
            .buttonStyle(VaultSecondaryButton())
            .popover(isPresented: $showFilterPopover) {
                FilterView()
                    .frame(width: 380)
            }

            if hasActiveFilters {
                Button {
                    appState.clearFilters()
                } label: {
                    HStack(spacing: VaultSpacing.xs) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                        Text("Clear")
                            .font(VaultTypography.captionMedium)
                    }
                }
                .buttonStyle(VaultGhostButton(color: VaultColors.projection))
            }

            Spacer()

            Menu {
                ForEach(SortColumn.allCases, id: \.self) { column in
                    Button {
                        if appState.sortColumn == column {
                            appState.sortAscending.toggle()
                        } else {
                            appState.sortColumn = column
                            appState.sortAscending = true
                        }
                        Task {
                            await appState.refreshData()
                        }
                    } label: {
                        HStack {
                            Text(column.rawValue)
                            if appState.sortColumn == column {
                                Image(systemName: appState.sortAscending ? "chevron.up" : "chevron.down")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: VaultSpacing.xs) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 12, weight: .medium))
                    Text("Sort")
                        .font(VaultTypography.bodyMedium)
                }
                .foregroundColor(VaultColors.celluloidMuted)
            }
            .buttonStyle(VaultSecondaryButton())

            Button {
                Task {
                    await appState.refreshData()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(VaultGhostButton())
        }
        .padding(.horizontal, VaultSpacing.lg)
        .padding(.vertical, VaultSpacing.md)
        .background(VaultColors.screen)
    }

    private var hasActiveFilters: Bool {
        !appState.filterVideoCodecs.isEmpty ||
        !appState.filterHDRFormats.isEmpty ||
        !appState.filterAudioCodecs.isEmpty ||
        !appState.filterContainers.isEmpty ||
        !appState.filterResolutions.isEmpty ||
        appState.filterHasAtmos != nil ||
        appState.filterHasDTSX != nil ||
        appState.filterImmersiveAudio != nil
    }
}

struct FileTableView: View {
    let files: [VideoFile]
    @EnvironmentObject var appState: AppState
    @State private var sortOrder: [KeyPathComparator<VideoFile>] = [
        KeyPathComparator(\VideoFile.fileName, order: .forward)
    ]

    var body: some View {
        Table(files, selection: $appState.selectedFiles, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.fileName) { file in
                HStack(spacing: VaultSpacing.md) {
                    FileIconView(file: file)
                    VStack(alignment: .leading, spacing: VaultSpacing.xxs) {
                        Text(file.fileName)
                            .font(VaultTypography.bodyMedium)
                            .foregroundColor(VaultColors.celluloid)
                            .lineLimit(1)
                        Text(file.filePath)
                            .font(VaultTypography.micro)
                            .foregroundColor(VaultColors.celluloidFaint)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                }
            }
            .width(min: 150, ideal: 300, max: 600)

            TableColumn("Size", value: \.fileSize) { file in
                Text(file.formattedFileSize)
                    .font(VaultTypography.monoSmall)
                    .foregroundColor(VaultColors.celluloidMuted)
                    .monospacedDigit()
            }
            .width(min: 60, ideal: 80, max: 120)

            TableColumn("Duration", sortUsing: KeyPathComparator(\VideoFile.durationSeconds)) { file in
                Text(file.formattedDuration)
                    .font(VaultTypography.monoSmall)
                    .foregroundColor(VaultColors.celluloidMuted)
                    .monospacedDigit()
            }
            .width(min: 60, ideal: 80, max: 120)

            TableColumn("Resolution", sortUsing: KeyPathComparator(\VideoFile.height)) { file in
                HStack(spacing: VaultSpacing.sm) {
                    Text(file.resolutionCategory)
                        .font(VaultTypography.captionMedium)
                        .foregroundColor(VaultColors.celluloid)
                    if file.hdrFormat != .sdr {
                        HDRBadge(format: file.hdrFormat)
                    }
                }
            }
            .width(min: 80, ideal: 130, max: 200)

            TableColumn("Video", sortUsing: KeyPathComparator(\VideoFile.videoCodec.rawValue)) { file in
                Text(file.videoCodec.displayName)
                    .font(VaultTypography.caption)
                    .foregroundColor(VaultColors.celluloidMuted)
            }
            .width(min: 60, ideal: 100, max: 150)

            TableColumn("Audio", sortUsing: KeyPathComparator(\VideoFile.audioCodec.rawValue)) { file in
                HStack(spacing: VaultSpacing.xs) {
                    Text(file.audioDescription)
                        .font(VaultTypography.caption)
                        .foregroundColor(VaultColors.celluloidMuted)
                        .lineLimit(1)
                    if file.isAtmos {
                        VaultBadge(text: "Atmos", color: VaultColors.atmos, glow: true, size: .small)
                    }
                    if file.isDTSX {
                        VaultBadge(text: "DTS:X", color: VaultColors.dolby, glow: true, size: .small)
                    }
                }
            }
            .width(min: 100, ideal: 180, max: 280)

            TableColumn("Bitrate", sortUsing: KeyPathComparator(\VideoFile.bitRate)) { file in
                Text(file.formattedBitRate)
                    .font(VaultTypography.monoSmall)
                    .foregroundColor(VaultColors.celluloidMuted)
                    .monospacedDigit()
            }
            .width(min: 60, ideal: 80, max: 120)

            TableColumn("Container", sortUsing: KeyPathComparator(\VideoFile.containerFormat.rawValue)) { file in
                Text(file.containerFormat.displayName)
                    .font(VaultTypography.caption)
                    .foregroundColor(VaultColors.celluloidMuted)
            }
            .width(min: 60, ideal: 80, max: 120)
        }
        .onChange(of: sortOrder) { _, newOrder in
            guard let firstComparator = newOrder.first else { return }

            let ascending = firstComparator.order == .forward
            let column = mapKeyPathToSortColumn(firstComparator)

            if appState.sortColumn != column || appState.sortAscending != ascending {
                appState.sortColumn = column
                appState.sortAscending = ascending
                Task {
                    await appState.refreshData()
                }
            }
        }
        .contextMenu(forSelectionType: VideoFile.ID.self) { selection in
            if let fileId = selection.first,
               let file = files.first(where: { $0.id == fileId }) {
                Button {
                    revealInFinder(file.filePath)
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }

                Button {
                    openFile(file.filePath)
                } label: {
                    Label("Open with Default App", systemImage: "play.rectangle")
                }

                Divider()

                Button {
                    copyToClipboard(file.filePath)
                } label: {
                    Label("Copy Path", systemImage: "doc.on.doc")
                }

                Button {
                    copyToClipboard(file.fileName)
                } label: {
                    Label("Copy File Name", systemImage: "textformat")
                }
            }
        } primaryAction: { selection in
            if let fileId = selection.first,
               let file = files.first(where: { $0.id == fileId }) {
                revealInFinder(file.filePath)
            }
        }
    }

    private func mapKeyPathToSortColumn(_ comparator: KeyPathComparator<VideoFile>) -> SortColumn {
        let keyPathString = String(describing: comparator.keyPath)

        if keyPathString.contains("fileName") {
            return .fileName
        } else if keyPathString.contains("fileSize") {
            return .fileSize
        } else if keyPathString.contains("durationSeconds") {
            return .duration
        } else if keyPathString.contains("height") {
            return .resolution
        } else if keyPathString.contains("videoCodec") {
            return .videoCodec
        } else if keyPathString.contains("audioCodec") {
            return .audioCodec
        } else if keyPathString.contains("bitRate") {
            return .bitRate
        } else if keyPathString.contains("containerFormat") {
            return .container
        } else {
            return .fileName
        }
    }

    private func revealInFinder(_ path: String) {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }

    private func openFile(_ path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

struct FileIconView: View {
    let file: VideoFile

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: VaultRadius.sm, style: .continuous)
                .fill(iconColor.opacity(0.15))
                .frame(width: 32, height: 32)

            Image(systemName: "film")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(iconColor)
        }
        .shadow(color: shouldGlow ? iconColor.opacity(0.4) : .clear, radius: 6, x: 0, y: 0)
    }

    private var iconColor: Color {
        if file.hdrFormat == .dolbyVision || file.hdrFormat == .dolbyVisionHDR10 {
            return VaultColors.dolby
        } else if file.hdrFormat != .sdr {
            return VaultColors.hdr
        } else if file.isAtmos || file.isDTSX {
            return VaultColors.atmos
        } else if file.resolutionCategory == "4K" || file.resolutionCategory == "8K" {
            return VaultColors.chartBlue
        } else {
            return VaultColors.celluloidMuted
        }
    }

    private var shouldGlow: Bool {
        file.hdrFormat != .sdr || file.isAtmos || file.isDTSX
    }
}

struct HDRBadge: View {
    let format: HDRFormat

    var body: some View {
        VaultBadge(
            text: badgeText,
            color: badgeColor,
            glow: format == .dolbyVision || format == .dolbyVisionHDR10,
            size: .small
        )
    }

    private var badgeText: String {
        switch format {
        case .dolbyVision, .dolbyVisionHDR10:
            return "DV"
        case .hdr10:
            return "HDR10"
        case .hdr10Plus:
            return "HDR10+"
        case .hlg:
            return "HLG"
        case .sdr:
            return ""
        }
    }

    private var badgeColor: Color {
        switch format {
        case .dolbyVision, .dolbyVisionHDR10:
            return VaultColors.dolby
        case .hdr10, .hdr10Plus:
            return VaultColors.hdr
        case .hlg:
            return VaultColors.chartGreen
        case .sdr:
            return .clear
        }
    }
}

struct EmptyFileListView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VaultEmptyState(
            icon: "film.stack",
            title: "No Video Files",
            subtitle: "Scan a folder to analyze your video library",
            action: { appState.showFolderPicker = true },
            actionLabel: "Select Folder..."
        )
    }
}

struct FileListStatusBar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: VaultSpacing.lg) {
            HStack(spacing: VaultSpacing.xs) {
                Image(systemName: "film")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(VaultColors.celluloidFaint)
                Text("\(appState.videoFiles.count) files")
                    .font(VaultTypography.caption)
                    .foregroundColor(VaultColors.celluloidMuted)
            }

            if !appState.selectedFiles.isEmpty {
                HStack(spacing: VaultSpacing.xs) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(VaultColors.projection)
                    Text("\(appState.selectedFiles.count) selected")
                        .font(VaultTypography.caption)
                        .foregroundColor(VaultColors.celluloidMuted)
                }
            }

            Spacer()

            HStack(spacing: VaultSpacing.xs) {
                Image(systemName: "externaldrive")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(VaultColors.celluloidFaint)
                Text(appState.statistics.formattedTotalSize)
                    .font(VaultTypography.captionMedium)
                    .foregroundColor(VaultColors.celluloidMuted)
            }
        }
        .padding(.horizontal, VaultSpacing.lg)
        .padding(.vertical, VaultSpacing.sm)
        .background(VaultColors.screen)
    }
}
