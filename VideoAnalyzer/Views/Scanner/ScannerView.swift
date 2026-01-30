import SwiftUI

struct ScannerView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            ScanProgressView()

            VaultDivider()

            LogView()
        }
        .background(VaultColors.vault)
        .navigationTitle("Scanner")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if appState.scanState == .scanning {
                    Button {
                        Task {
                            await appState.pauseScan()
                        }
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                    }
                } else if appState.scanState == .paused {
                    Button {
                        Task {
                            await appState.resumeScan()
                        }
                    } label: {
                        Label("Resume", systemImage: "play.fill")
                    }
                }

                if appState.scanState == .scanning || appState.scanState == .paused {
                    Button {
                        Task {
                            await appState.cancelScan()
                        }
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                    }
                }
            }
        }
    }
}

struct ScanProgressView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: VaultSpacing.xl) {
            Spacer()

            statusIcon

            VStack(spacing: VaultSpacing.sm) {
                Text(statusTitle)
                    .font(VaultTypography.headline)
                    .foregroundColor(VaultColors.celluloid)

                Text(statusSubtitle)
                    .font(VaultTypography.caption)
                    .foregroundColor(VaultColors.celluloidMuted)
            }

            if appState.scanState == .scanning || appState.scanState == .paused {
                VStack(spacing: VaultSpacing.lg) {
                    // Progress bar
                    VStack(spacing: VaultSpacing.sm) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Track
                                RoundedRectangle(cornerRadius: VaultRadius.sm, style: .continuous)
                                    .fill(VaultColors.screen)
                                    .frame(height: 6)

                                // Progress
                                RoundedRectangle(cornerRadius: VaultRadius.sm, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [VaultColors.projection, VaultColors.hdr],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * (appState.scanProgress.percentage / 100), height: 6)
                                    .shadow(color: VaultColors.projection.opacity(0.5), radius: 4, x: 0, y: 0)
                            }
                        }
                        .frame(height: 6)

                        HStack {
                            Text("\(appState.scanProgress.processedFiles) / \(appState.scanProgress.totalFiles) files")
                                .font(VaultTypography.caption)
                                .foregroundColor(VaultColors.celluloidMuted)

                            Spacer()

                            Text(String(format: "%.1f%%", appState.scanProgress.percentage))
                                .font(VaultTypography.captionMedium)
                                .foregroundColor(VaultColors.projection)
                                .monospacedDigit()
                        }
                    }
                    .frame(maxWidth: 400)

                    if let currentFile = appState.scanProgress.currentFile {
                        HStack(spacing: VaultSpacing.sm) {
                            Image(systemName: "film")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(VaultColors.celluloidFaint)

                            Text(currentFile)
                                .font(VaultTypography.caption)
                                .foregroundColor(VaultColors.celluloidMuted)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .frame(maxWidth: 400)
                    }
                }
            } else if appState.scanState == .idle {
                VStack(spacing: VaultSpacing.lg) {
                    Text("Select a folder to scan for video files")
                        .font(VaultTypography.body)
                        .foregroundColor(VaultColors.celluloidMuted)

                    Button("Select Folder...") {
                        appState.showFolderPicker = true
                    }
                    .buttonStyle(VaultPrimaryButton())
                }
            } else if appState.scanState == .completed {
                VStack(spacing: VaultSpacing.lg) {
                    Text("\(appState.statistics.totalFiles) files analyzed")
                        .font(VaultTypography.body)
                        .foregroundColor(VaultColors.celluloidMuted)

                    HStack(spacing: VaultSpacing.md) {
                        Button("View Dashboard") {
                            appState.selectedTab = .dashboard
                        }
                        .buttonStyle(VaultSecondaryButton())

                        Button("View Files") {
                            appState.selectedTab = .files
                        }
                        .buttonStyle(VaultPrimaryButton())
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(VaultSpacing.xxl)
        .background(VaultColors.vault)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch appState.scanState {
        case .idle:
            ZStack {
                Circle()
                    .fill(VaultColors.screen)
                    .frame(width: 80, height: 80)

                Image(systemName: "folder.badge.questionmark")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(VaultColors.celluloidMuted)
            }

        case .scanning:
            ZStack {
                // Outer glow
                Circle()
                    .fill(VaultColors.projection.opacity(0.1))
                    .frame(width: 96, height: 96)
                    .blur(radius: 10)

                // Progress ring
                VaultProgressRing(
                    progress: appState.scanProgress.percentage / 100,
                    size: 80,
                    lineWidth: 4,
                    color: VaultColors.projection
                )

                // Animated scan icon
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(VaultColors.projection)
            }

        case .paused:
            ZStack {
                Circle()
                    .fill(VaultColors.warning.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(VaultColors.warning)
            }

        case .completed:
            ZStack {
                Circle()
                    .fill(VaultColors.success.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(VaultColors.success)
            }
            .shadow(color: VaultColors.success.opacity(0.3), radius: 12, x: 0, y: 0)

        case .cancelled:
            ZStack {
                Circle()
                    .fill(VaultColors.destructive.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(VaultColors.destructive)
            }
        }
    }

    private var statusTitle: String {
        switch appState.scanState {
        case .idle:
            return "Ready to Scan"
        case .scanning:
            return "Scanning Library"
        case .paused:
            return "Scan Paused"
        case .completed:
            return "Scan Complete"
        case .cancelled:
            return "Scan Cancelled"
        }
    }

    private var statusSubtitle: String {
        switch appState.scanState {
        case .idle:
            return "No active scan"
        case .scanning:
            return "Analyzing video metadata..."
        case .paused:
            return "Click resume to continue"
        case .completed:
            return "All files have been processed"
        case .cancelled:
            return "Scan was stopped"
        }
    }
}
