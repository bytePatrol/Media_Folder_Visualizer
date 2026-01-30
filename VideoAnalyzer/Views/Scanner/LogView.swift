import SwiftUI

struct LogView: View {
    @EnvironmentObject var appState: AppState
    @State private var autoScroll = true
    @State private var filterLevel: LogLevel? = nil
    @State private var searchText = ""

    private var filteredLogs: [LogEntry] {
        var logs = appState.logEntries

        if let level = filterLevel {
            logs = logs.filter { $0.level == level }
        }

        if !searchText.isEmpty {
            logs = logs.filter { $0.message.localizedCaseInsensitiveContains(searchText) }
        }

        return logs
    }

    var body: some View {
        VStack(spacing: 0) {
            LogToolbar(
                autoScroll: $autoScroll,
                filterLevel: $filterLevel,
                searchText: $searchText,
                logCount: appState.logEntries.count,
                errorCount: appState.logEntries.filter { $0.level == .error }.count
            )

            VaultDivider()

            if filteredLogs.isEmpty {
                EmptyLogView()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredLogs) { entry in
                                LogEntryRow(entry: entry)
                                    .id(entry.id)
                            }
                        }
                        .padding(.vertical, VaultSpacing.sm)
                    }
                    .onChange(of: appState.logEntries.count) { _, _ in
                        if autoScroll, let lastEntry = filteredLogs.last {
                            withAnimation(.easeOut(duration: 0.15)) {
                                proxy.scrollTo(lastEntry.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .background(VaultColors.screen)
    }
}

struct LogToolbar: View {
    @Binding var autoScroll: Bool
    @Binding var filterLevel: LogLevel?
    @Binding var searchText: String
    let logCount: Int
    let errorCount: Int

    var body: some View {
        HStack(spacing: VaultSpacing.lg) {
            HStack(spacing: VaultSpacing.md) {
                Text("Scan Log")
                    .font(VaultTypography.title)
                    .foregroundColor(VaultColors.celluloid)

                VaultBadge(text: "\(logCount)", color: VaultColors.celluloidMuted, size: .small)

                if errorCount > 0 {
                    HStack(spacing: VaultSpacing.xxs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                        Text("\(errorCount)")
                            .font(VaultTypography.captionMedium)
                    }
                    .foregroundColor(VaultColors.destructive)
                }
            }

            Spacer()

            VaultSearchField(
                text: $searchText,
                placeholder: "Search logs..."
            )
            .frame(width: 180)

            Menu {
                Button {
                    filterLevel = nil
                } label: {
                    HStack {
                        Text("All Levels")
                        if filterLevel == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Divider()

                ForEach([LogLevel.info, .success, .warning, .error], id: \.self) { level in
                    Button {
                        filterLevel = level
                    } label: {
                        HStack {
                            levelIcon(level)
                            Text(level.rawValue.capitalized)
                            if filterLevel == level {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: VaultSpacing.xs) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 12, weight: .medium))
                    Text(filterLevel?.rawValue.capitalized ?? "All")
                        .font(VaultTypography.captionMedium)
                }
                .foregroundColor(filterLevel != nil ? VaultColors.projection : VaultColors.celluloidMuted)
            }
            .buttonStyle(VaultSecondaryButton())

            Button {
                autoScroll.toggle()
            } label: {
                Image(systemName: autoScroll ? "arrow.down.to.line.circle.fill" : "arrow.down.to.line.circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(autoScroll ? VaultColors.projection : VaultColors.celluloidMuted)
            }
            .buttonStyle(VaultGhostButton())
            .help("Auto-scroll to latest")
        }
        .padding(.horizontal, VaultSpacing.lg)
        .padding(.vertical, VaultSpacing.md)
        .background(VaultColors.screen)
    }

    @ViewBuilder
    private func levelIcon(_ level: LogLevel) -> some View {
        switch level {
        case .info:
            Image(systemName: "info.circle.fill")
                .foregroundColor(VaultColors.chartBlue)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(VaultColors.success)
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(VaultColors.warning)
        case .error:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(VaultColors.destructive)
        }
    }
}

struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        let content = HStack(alignment: .top, spacing: VaultSpacing.md) {
            Text(entry.formattedTime)
                .font(VaultTypography.monoSmall)
                .foregroundColor(VaultColors.celluloidFaint)
                .frame(width: 70, alignment: .leading)

            levelBadge

            Text(entry.message)
                .font(VaultTypography.caption)
                .foregroundColor(textColor)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Show reveal button for clickable error entries
            if entry.isClickable {
                Image(systemName: "folder")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(VaultColors.celluloidMuted)
            }
        }
        .padding(.horizontal, VaultSpacing.lg)
        .padding(.vertical, VaultSpacing.xs)
        .background(backgroundColor)

        if entry.isClickable {
            Button {
                revealInFinder()
            } label: {
                content
            }
            .buttonStyle(LogEntryButtonStyle())
            .help("Click to reveal file in Finder")
        } else {
            content
        }
    }

    @ViewBuilder
    private var levelBadge: some View {
        switch entry.level {
        case .info:
            Image(systemName: "info.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(VaultColors.chartBlue)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(VaultColors.success)
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(VaultColors.warning)
        case .error:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(VaultColors.destructive)
        }
    }

    private var textColor: Color {
        switch entry.level {
        case .info: return VaultColors.celluloidMuted
        case .success: return VaultColors.success
        case .warning: return VaultColors.warning
        case .error: return VaultColors.destructive
        }
    }

    private var backgroundColor: Color {
        switch entry.level {
        case .error: return VaultColors.destructive.opacity(0.08)
        case .warning: return VaultColors.warning.opacity(0.05)
        default: return .clear
        }
    }

    private func revealInFinder() {
        guard let filePath = entry.filePath else { return }
        // Get the parent directory of the file
        let url = URL(fileURLWithPath: filePath)
        let folderURL = url.deletingLastPathComponent()
        // Select the file in Finder
        NSWorkspace.shared.selectFile(filePath, inFileViewerRootedAtPath: folderURL.path)
    }
}

struct LogEntryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? VaultColors.screenHover : Color.clear
            )
    }
}

struct EmptyLogView: View {
    var body: some View {
        VStack(spacing: VaultSpacing.md) {
            Image(systemName: "doc.text")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(VaultColors.celluloidFaint)

            VStack(spacing: VaultSpacing.xs) {
                Text("No log entries")
                    .font(VaultTypography.bodyMedium)
                    .foregroundColor(VaultColors.celluloidMuted)

                Text("Start a scan to see activity")
                    .font(VaultTypography.caption)
                    .foregroundColor(VaultColors.celluloidFaint)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VaultColors.screen)
    }
}
