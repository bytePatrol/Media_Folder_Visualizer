import SwiftUI

struct MainView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            Group {
                switch appState.selectedTab {
                case .dashboard:
                    DashboardView()
                case .files:
                    FileListView()
                case .scanner:
                    ScannerView()
                }
            }
            .vaultBackground()
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        .sheet(isPresented: $appState.showFolderPicker) {
            FolderPickerSheet()
        }
        .sheet(isPresented: $appState.showExportSheet) {
            ExportSheet()
        }
        .sheet(isPresented: $appState.showIntegritySheet) {
            IntegritySheet()
        }
        .sheet(isPresented: $appState.showDuplicateSheet) {
            DuplicateSheet()
        }
        .alert("Resume Previous Scan?", isPresented: $appState.showRecoveryAlert) {
            Button("Resume") {
                Task {
                    await appState.resumeFromRecovery()
                }
            }
            Button("Discard", role: .destructive) {
                appState.dismissRecovery()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let info = appState.recoveryInfo {
                Text("A previous scan was interrupted.\n\n\(info.summary)\n\nFolder: \(info.folderPath)")
            }
        }
        .alert("Clear All Data?", isPresented: $appState.showClearDataAlert) {
            Button("Clear", role: .destructive) {
                Task {
                    await appState.cancelScan()
                    await appState.deleteAllData()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all scanned video data and stop any running scan. This action cannot be undone.")
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if appState.scanState == .scanning || appState.scanState == .paused {
                    ScanStatusToolbarItem()
                }

                Button {
                    appState.showFolderPicker = true
                } label: {
                    Label("New Scan", systemImage: "folder.badge.plus")
                }
                .disabled(appState.scanState == .scanning)

                Menu {
                    Button("Export as CSV...") {
                        appState.showExportSheet = true
                    }
                    Button("Export as JSON...") {
                        appState.showExportSheet = true
                    }
                    Button("Export as PDF Report...") {
                        appState.showExportSheet = true
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(appState.videoFiles.isEmpty)
            }
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: VaultSpacing.xs) {
                HStack(spacing: VaultSpacing.sm) {
                    Image(systemName: "film.stack.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(VaultColors.projection)

                    Text("Video Analyzer")
                        .font(VaultTypography.headline)
                        .foregroundColor(VaultColors.celluloid)
                }

                Text("Media Library Manager")
                    .font(VaultTypography.caption)
                    .foregroundColor(VaultColors.celluloidFaint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, VaultSpacing.lg)
            .padding(.vertical, VaultSpacing.xl)

            VaultDivider()
                .padding(.horizontal, VaultSpacing.lg)

            // Navigation
            VStack(spacing: VaultSpacing.xs) {
                ForEach(AppTab.allCases) { tab in
                    SidebarNavItem(
                        tab: tab,
                        isSelected: appState.selectedTab == tab
                    ) {
                        appState.selectedTab = tab
                    }
                }
            }
            .padding(.horizontal, VaultSpacing.md)
            .padding(.vertical, VaultSpacing.lg)

            VaultDivider()
                .padding(.horizontal, VaultSpacing.lg)

            // Quick Stats
            VStack(alignment: .leading, spacing: VaultSpacing.lg) {
                Text("LIBRARY")
                    .font(VaultTypography.micro)
                    .foregroundColor(VaultColors.celluloidFaint)
                    .tracking(1.2)

                VStack(spacing: VaultSpacing.md) {
                    SidebarStatRow(
                        icon: "film",
                        label: "Files",
                        value: "\(appState.statistics.totalFiles)"
                    )
                    SidebarStatRow(
                        icon: "externaldrive",
                        label: "Size",
                        value: appState.statistics.formattedTotalSize
                    )
                    SidebarStatRow(
                        icon: "clock",
                        label: "Duration",
                        value: appState.statistics.formattedTotalDuration
                    )
                }

                if appState.statistics.atmosCount > 0 || appState.statistics.dtsxCount > 0 {
                    VaultDivider()

                    Text("IMMERSIVE")
                        .font(VaultTypography.micro)
                        .foregroundColor(VaultColors.celluloidFaint)
                        .tracking(1.2)

                    VStack(spacing: VaultSpacing.md) {
                        if appState.statistics.atmosCount > 0 {
                            SidebarStatRow(
                                icon: "hifispeaker.2.fill",
                                label: "Dolby Atmos",
                                value: "\(appState.statistics.atmosCount)",
                                valueColor: VaultColors.atmos,
                                glow: true
                            )
                        }
                        if appState.statistics.dtsxCount > 0 {
                            SidebarStatRow(
                                icon: "waveform.circle.fill",
                                label: "DTS:X",
                                value: "\(appState.statistics.dtsxCount)",
                                valueColor: VaultColors.dolby,
                                glow: true
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, VaultSpacing.lg)
            .padding(.vertical, VaultSpacing.lg)

            Spacer()

            // Version footer
            VaultDivider()
                .padding(.horizontal, VaultSpacing.lg)

            HStack {
                Text("v1.0")
                    .font(VaultTypography.micro)
                    .foregroundColor(VaultColors.celluloidFaint)
            }
            .padding(VaultSpacing.lg)
        }
        .background(VaultColors.screen)
    }
}

struct SidebarNavItem: View {
    let tab: AppTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: VaultSpacing.md) {
                Image(systemName: isSelected ? tab.iconFilled : tab.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? VaultColors.projection : VaultColors.celluloidMuted)
                    .frame(width: 20)

                Text(tab.rawValue)
                    .font(VaultTypography.bodyMedium)
                    .foregroundColor(isSelected ? VaultColors.celluloid : VaultColors.celluloidMuted)

                Spacer()
            }
            .padding(.horizontal, VaultSpacing.md)
            .padding(.vertical, VaultSpacing.sm)
            .background(
                isSelected ? VaultColors.projectionGlow : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: VaultRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VaultRadius.md, style: .continuous)
                    .stroke(isSelected ? VaultColors.projection.opacity(0.3) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SidebarStatRow: View {
    let icon: String
    let label: String
    let value: String
    var valueColor: Color = VaultColors.celluloid
    var glow: Bool = false

    var body: some View {
        HStack(spacing: VaultSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(VaultColors.celluloidFaint)
                .frame(width: 16)

            Text(label)
                .font(VaultTypography.caption)
                .foregroundColor(VaultColors.celluloidMuted)

            Spacer()

            Text(value)
                .font(VaultTypography.captionMedium)
                .foregroundColor(valueColor)
                .monospacedDigit()
                .shadow(color: glow ? valueColor.opacity(0.5) : .clear, radius: 4, x: 0, y: 0)
        }
    }
}

struct ScanStatusToolbarItem: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: VaultSpacing.sm) {
            if appState.scanState == .scanning {
                VaultProgressRing(
                    progress: appState.scanProgress.percentage / 100,
                    size: 18,
                    lineWidth: 2
                )
            } else if appState.scanState == .paused {
                Image(systemName: "pause.circle.fill")
                    .foregroundColor(VaultColors.warning)
            }

            Text("\(Int(appState.scanProgress.percentage))%")
                .font(VaultTypography.captionMedium)
                .foregroundColor(VaultColors.celluloid)
                .monospacedDigit()

            if appState.scanState == .scanning {
                Button {
                    Task {
                        await appState.pauseScan()
                    }
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 10))
                }
                .buttonStyle(VaultGhostButton())
            } else if appState.scanState == .paused {
                Button {
                    Task {
                        await appState.resumeScan()
                    }
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                }
                .buttonStyle(VaultGhostButton(color: VaultColors.projection))
            }

            Button {
                Task {
                    await appState.cancelScan()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
            }
            .buttonStyle(VaultGhostButton())
        }
        .padding(.horizontal, VaultSpacing.md)
        .padding(.vertical, VaultSpacing.xs)
        .background(VaultColors.screen)
        .clipShape(RoundedRectangle(cornerRadius: VaultRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VaultRadius.md, style: .continuous)
                .stroke(VaultColors.border, lineWidth: 1)
        )
    }
}

struct FolderPickerSheet: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedFolderPath: String = ""

    var body: some View {
        VStack(spacing: VaultSpacing.xl) {
            VStack(spacing: VaultSpacing.sm) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(VaultColors.projection)

                Text("Select Folder to Scan")
                    .font(VaultTypography.headline)
                    .foregroundColor(VaultColors.celluloid)
            }

            HStack(spacing: VaultSpacing.md) {
                TextField("Folder path", text: $selectedFolderPath)
                    .textFieldStyle(.plain)
                    .font(VaultTypography.body)
                    .padding(VaultSpacing.md)
                    .background(VaultColors.screen)
                    .clipShape(RoundedRectangle(cornerRadius: VaultRadius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: VaultRadius.md, style: .continuous)
                            .stroke(VaultColors.border, lineWidth: 1)
                    )

                Button("Browse...") {
                    selectFolder()
                }
                .buttonStyle(VaultSecondaryButton())
            }

            HStack {
                Button("Cancel") {
                    appState.showFolderPicker = false
                }
                .buttonStyle(VaultGhostButton())
                .keyboardShortcut(.escape)

                Spacer()

                Button("Start Scan") {
                    appState.showFolderPicker = false
                    Task {
                        await appState.startScan(folderPath: selectedFolderPath)
                    }
                }
                .buttonStyle(VaultPrimaryButton())
                .keyboardShortcut(.defaultAction)
                .disabled(selectedFolderPath.isEmpty)
            }
        }
        .padding(VaultSpacing.xxl)
        .frame(width: 520)
        .background(VaultColors.vault)
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.message = "Select a folder containing video files"

        if panel.runModal() == .OK, let url = panel.url {
            selectedFolderPath = url.path
        }
    }
}

struct ExportSheet: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedFormat: ExportFormat = .csv
    @State private var isExporting = false

    var body: some View {
        VStack(spacing: VaultSpacing.xl) {
            VStack(spacing: VaultSpacing.sm) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(VaultColors.projection)

                Text("Export Library")
                    .font(VaultTypography.headline)
                    .foregroundColor(VaultColors.celluloid)
            }

            HStack(spacing: VaultSpacing.sm) {
                ForEach(ExportFormat.allCases) { format in
                    ExportFormatOption(
                        format: format,
                        isSelected: selectedFormat == format
                    ) {
                        selectedFormat = format
                    }
                }
            }

            Text(formatDescription)
                .font(VaultTypography.caption)
                .foregroundColor(VaultColors.celluloidMuted)
                .multilineTextAlignment(.center)
                .frame(height: 40)

            HStack {
                Button("Cancel") {
                    appState.showExportSheet = false
                }
                .buttonStyle(VaultGhostButton())
                .keyboardShortcut(.escape)

                Spacer()

                Button {
                    exportFiles()
                } label: {
                    if isExporting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 60)
                    } else {
                        Text("Export...")
                    }
                }
                .buttonStyle(VaultPrimaryButton())
                .keyboardShortcut(.defaultAction)
                .disabled(isExporting)
            }
        }
        .padding(VaultSpacing.xxl)
        .frame(width: 440)
        .background(VaultColors.vault)
    }

    private var formatDescription: String {
        switch selectedFormat {
        case .csv:
            return "Export as comma-separated values, compatible with Excel and other spreadsheet applications."
        case .json:
            return "Export as JSON with full metadata and statistics, ideal for programmatic use."
        case .pdf:
            return "Generate a formatted PDF report with statistics charts and file listings."
        }
    }

    private func exportFiles() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: selectedFormat.fileExtension)!]
        panel.nameFieldStringValue = "video_library.\(selectedFormat.fileExtension)"

        if panel.runModal() == .OK, let url = panel.url {
            isExporting = true

            Task {
                let exportService = ExportService()

                do {
                    switch selectedFormat {
                    case .csv:
                        try await exportService.exportCSV(files: appState.videoFiles, to: url)
                    case .json:
                        try await exportService.exportJSON(
                            files: appState.videoFiles,
                            statistics: appState.statistics,
                            to: url
                        )
                    case .pdf:
                        let pdfData = try await exportService.exportPDF(
                            files: appState.videoFiles,
                            statistics: appState.statistics
                        )
                        try pdfData.write(to: url)
                    }

                    await MainActor.run {
                        isExporting = false
                        appState.showExportSheet = false
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                } catch {
                    await MainActor.run {
                        isExporting = false
                    }
                }
            }
        }
    }
}

struct ExportFormatOption: View {
    let format: ExportFormat
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: VaultSpacing.sm) {
                Image(systemName: format.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? VaultColors.projection : VaultColors.celluloidMuted)

                Text(format.rawValue)
                    .font(VaultTypography.captionMedium)
                    .foregroundColor(isSelected ? VaultColors.celluloid : VaultColors.celluloidMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, VaultSpacing.lg)
            .background(isSelected ? VaultColors.projectionGlow : VaultColors.screen)
            .clipShape(RoundedRectangle(cornerRadius: VaultRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VaultRadius.md, style: .continuous)
                    .stroke(isSelected ? VaultColors.projection.opacity(0.5) : VaultColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct IntegritySheet: View {
    @EnvironmentObject var appState: AppState
    @State private var isChecking = false
    @State private var progress: IntegrityProgress?
    @State private var results: [IntegrityResult] = []
    @State private var showOnlyCorrupted = true

    private let checker = IntegrityChecker()

    var body: some View {
        VStack(spacing: VaultSpacing.lg) {
            VStack(spacing: VaultSpacing.sm) {
                Image(systemName: isChecking ? "shield" : (results.isEmpty ? "shield.checkered" : "shield.fill"))
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(isChecking ? VaultColors.projection : (corruptedCount > 0 ? VaultColors.destructive : VaultColors.success))

                Text("Integrity Check")
                    .font(VaultTypography.headline)
                    .foregroundColor(VaultColors.celluloid)
            }

            if isChecking {
                VStack(spacing: VaultSpacing.md) {
                    ProgressView(value: (progress?.percentage ?? 0) / 100)
                        .tint(VaultColors.projection)

                    if let p = progress {
                        Text(p.currentFile)
                            .font(VaultTypography.caption)
                            .foregroundColor(VaultColors.celluloidMuted)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Text("\(p.processedFiles) / \(p.totalFiles)")
                            .font(VaultTypography.captionMedium)
                            .foregroundColor(VaultColors.celluloidFaint)
                    }
                }
            } else if !results.isEmpty {
                Toggle("Show only corrupted files", isOn: $showOnlyCorrupted)
                    .font(VaultTypography.body)
                    .foregroundColor(VaultColors.celluloid)
                    .toggleStyle(.switch)
                    .tint(VaultColors.projection)

                let filtered = showOnlyCorrupted ? results.filter { $0.isCorrupted } : results

                if filtered.isEmpty {
                    VStack(spacing: VaultSpacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(VaultColors.success)
                        Text("No corrupted files found!")
                            .font(VaultTypography.body)
                            .foregroundColor(VaultColors.success)
                    }
                    .padding(.vertical, VaultSpacing.xl)
                } else {
                    ScrollView {
                        LazyVStack(spacing: VaultSpacing.sm) {
                            ForEach(filtered) { result in
                                IntegrityResultRow(result: result)
                            }
                        }
                        .padding(VaultSpacing.sm)
                    }
                    .frame(height: 280)
                    .background(VaultColors.screen)
                    .clipShape(RoundedRectangle(cornerRadius: VaultRadius.md, style: .continuous))
                }
            } else {
                Text("This will perform a full decode test on all video files to detect corruption.")
                    .font(VaultTypography.body)
                    .foregroundColor(VaultColors.celluloidMuted)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, VaultSpacing.lg)
            }

            HStack {
                Button("Close") {
                    appState.showIntegritySheet = false
                }
                .buttonStyle(VaultGhostButton())
                .keyboardShortcut(.escape)

                Spacer()

                if !isChecking && results.isEmpty {
                    Button("Start Check") {
                        startCheck()
                    }
                    .buttonStyle(VaultPrimaryButton())
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(VaultSpacing.xxl)
        .frame(width: 520, height: isChecking || !results.isEmpty ? 480 : 260)
        .background(VaultColors.vault)
    }

    private var corruptedCount: Int {
        results.filter { $0.isCorrupted }.count
    }

    private func startCheck() {
        isChecking = true
        results = []

        Task {
            for await p in checker.progressPublisher.values {
                await MainActor.run {
                    progress = p
                }
            }
        }

        Task {
            let checkResults = await checker.checkIntegrity(of: appState.videoFiles)
            await MainActor.run {
                results = checkResults
                isChecking = false
            }
        }
    }
}

struct IntegrityResultRow: View {
    let result: IntegrityResult

    var body: some View {
        HStack(spacing: VaultSpacing.md) {
            Image(systemName: result.isCorrupted ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundColor(result.isCorrupted ? VaultColors.destructive : VaultColors.success)
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: VaultSpacing.xxs) {
                Text(result.fileName)
                    .font(VaultTypography.bodyMedium)
                    .foregroundColor(VaultColors.celluloid)
                    .lineLimit(1)

                if result.isCorrupted {
                    Text(result.errorSummary)
                        .font(VaultTypography.caption)
                        .foregroundColor(VaultColors.celluloidMuted)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(VaultSpacing.md)
        .background(result.isCorrupted ? VaultColors.destructive.opacity(0.1) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: VaultRadius.sm, style: .continuous))
    }
}

struct DuplicateSheet: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedMethod: DuplicateMethod = .fuzzy
    @State private var isDetecting = false
    @State private var progress: DuplicateProgress?
    @State private var groups: [DuplicateGroup] = []

    private let detector = DuplicateDetector()

    var body: some View {
        VStack(spacing: VaultSpacing.lg) {
            VStack(spacing: VaultSpacing.sm) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(VaultColors.projection)

                Text("Duplicate Detection")
                    .font(VaultTypography.headline)
                    .foregroundColor(VaultColors.celluloid)
            }

            if isDetecting {
                VStack(spacing: VaultSpacing.md) {
                    ProgressView(value: (progress?.percentage ?? 0) / 100)
                        .tint(VaultColors.projection)

                    if let p = progress {
                        Text("\(p.phase.rawValue): \(p.currentFile)")
                            .font(VaultTypography.caption)
                            .foregroundColor(VaultColors.celluloidMuted)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            } else if !groups.isEmpty {
                let totalSavings = groups.reduce(0) { $0 + $1.potentialSavings }

                HStack {
                    VaultBadge(text: "\(groups.count) groups", color: VaultColors.projection)

                    Spacer()

                    HStack(spacing: VaultSpacing.xs) {
                        Text("Potential savings:")
                            .font(VaultTypography.caption)
                            .foregroundColor(VaultColors.celluloidMuted)
                        Text(ByteCountFormatter.string(fromByteCount: totalSavings, countStyle: .file))
                            .font(VaultTypography.captionMedium)
                            .foregroundColor(VaultColors.projection)
                    }
                }

                ScrollView {
                    LazyVStack(spacing: VaultSpacing.md) {
                        ForEach(groups) { group in
                            DuplicateGroupCard(group: group)
                        }
                    }
                    .padding(VaultSpacing.sm)
                }
                .frame(height: 320)
                .background(VaultColors.screen)
                .clipShape(RoundedRectangle(cornerRadius: VaultRadius.md, style: .continuous))
            } else {
                VStack(spacing: VaultSpacing.lg) {
                    HStack(spacing: VaultSpacing.sm) {
                        ForEach(DuplicateMethod.allCases) { method in
                            DuplicateMethodOption(
                                method: method,
                                isSelected: selectedMethod == method
                            ) {
                                selectedMethod = method
                            }
                        }
                    }

                    Text(selectedMethod.description)
                        .font(VaultTypography.caption)
                        .foregroundColor(VaultColors.celluloidMuted)
                        .multilineTextAlignment(.center)
                        .frame(height: 40)
                }
            }

            HStack {
                Button("Close") {
                    appState.showDuplicateSheet = false
                }
                .buttonStyle(VaultGhostButton())
                .keyboardShortcut(.escape)

                Spacer()

                if !isDetecting && groups.isEmpty {
                    Button("Find Duplicates") {
                        startDetection()
                    }
                    .buttonStyle(VaultPrimaryButton())
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(VaultSpacing.xxl)
        .frame(width: 640, height: isDetecting || !groups.isEmpty ? 540 : 300)
        .background(VaultColors.vault)
    }

    private func startDetection() {
        isDetecting = true
        groups = []

        Task {
            for await p in detector.progressPublisher.values {
                await MainActor.run {
                    progress = p
                }
            }
        }

        Task {
            let detectedGroups = await detector.detectDuplicates(
                files: appState.videoFiles,
                method: selectedMethod
            )
            await MainActor.run {
                groups = detectedGroups
                isDetecting = false
            }
        }
    }
}

struct DuplicateMethodOption: View {
    let method: DuplicateMethod
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: VaultSpacing.sm) {
                Image(systemName: method.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isSelected ? VaultColors.projection : VaultColors.celluloidMuted)

                Text(method.rawValue)
                    .font(VaultTypography.captionMedium)
                    .foregroundColor(isSelected ? VaultColors.celluloid : VaultColors.celluloidMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, VaultSpacing.md)
            .background(isSelected ? VaultColors.projectionGlow : VaultColors.screen)
            .clipShape(RoundedRectangle(cornerRadius: VaultRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VaultRadius.md, style: .continuous)
                    .stroke(isSelected ? VaultColors.projection.opacity(0.5) : VaultColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct DuplicateGroupCard: View {
    let group: DuplicateGroup

    var body: some View {
        VStack(alignment: .leading, spacing: VaultSpacing.sm) {
            HStack {
                Text("\(group.fileCount) files")
                    .font(VaultTypography.bodyMedium)
                    .foregroundColor(VaultColors.celluloid)

                VaultBadge(text: group.confidenceDescription, color: VaultColors.celluloidMuted, size: .small)

                Spacer()

                Text(group.formattedPotentialSavings)
                    .font(VaultTypography.captionMedium)
                    .foregroundColor(VaultColors.projection)
            }

            VStack(spacing: VaultSpacing.xs) {
                ForEach(group.files, id: \.id) { file in
                    HStack {
                        Text(file.fileName)
                            .font(VaultTypography.caption)
                            .foregroundColor(VaultColors.celluloidMuted)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        Text(file.formattedFileSize)
                            .font(VaultTypography.monoSmall)
                            .foregroundColor(VaultColors.celluloidFaint)
                    }
                }
            }
            .padding(.leading, VaultSpacing.md)
        }
        .padding(VaultSpacing.md)
        .background(VaultColors.screenElevated)
        .clipShape(RoundedRectangle(cornerRadius: VaultRadius.sm, style: .continuous))
    }
}

// MARK: - Extensions for AppTab

extension AppTab {
    var iconFilled: String {
        switch self {
        case .dashboard: return "chart.pie.fill"
        case .files: return "folder.fill"
        case .scanner: return "magnifyingglass.circle.fill"
        }
    }
}

// MARK: - Extensions for ExportFormat

extension ExportFormat {
    var icon: String {
        switch self {
        case .csv: return "tablecells"
        case .json: return "curlybraces"
        case .pdf: return "doc.richtext"
        }
    }
}

// MARK: - Extensions for DuplicateMethod

extension DuplicateMethod {
    var icon: String {
        switch self {
        case .fuzzy: return "wand.and.stars"
        case .partialHash: return "number"
        case .fullHash: return "checkmark.seal"
        }
    }
}
