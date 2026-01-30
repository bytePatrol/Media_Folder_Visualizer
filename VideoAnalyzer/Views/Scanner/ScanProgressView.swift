import SwiftUI

struct DetailedProgressView: View {
    let progress: ScanProgress
    let statistics: VideoStatistics

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                ProgressStatCard(
                    title: "Processed",
                    value: "\(progress.processedFiles)",
                    subtitle: "of \(progress.totalFiles) files"
                )

                ProgressStatCard(
                    title: "Progress",
                    value: String(format: "%.1f%%", progress.percentage),
                    subtitle: ""
                )

                if statistics.totalFiles > 0 {
                    ProgressStatCard(
                        title: "Total Size",
                        value: statistics.formattedTotalSize,
                        subtitle: "analyzed"
                    )
                }
            }

            if progress.state == .scanning {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)

                    if let file = progress.currentFile {
                        Text(file)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
        }
    }
}

struct ProgressStatCard: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .monospacedDigit()

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 100)
    }
}

struct CircularProgressView: View {
    let progress: Double
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.accentColor.opacity(0.2), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
    }
}

struct AnimatedScanIcon: View {
    @State private var isAnimating = false

    var body: some View {
        Image(systemName: "magnifyingglass")
            .font(.system(size: 24))
            .foregroundColor(.accentColor)
            .scaleEffect(isAnimating ? 1.1 : 1.0)
            .animation(
                .easeInOut(duration: 0.6)
                .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

struct ScanControlButtons: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 12) {
            switch appState.scanState {
            case .scanning:
                Button {
                    Task {
                        await appState.pauseScan()
                    }
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                        .frame(minWidth: 80)
                }

                Button(role: .destructive) {
                    Task {
                        await appState.cancelScan()
                    }
                } label: {
                    Label("Cancel", systemImage: "xmark")
                        .frame(minWidth: 80)
                }

            case .paused:
                Button {
                    Task {
                        await appState.resumeScan()
                    }
                } label: {
                    Label("Resume", systemImage: "play.fill")
                        .frame(minWidth: 80)
                }
                .buttonStyle(.borderedProminent)

                Button(role: .destructive) {
                    Task {
                        await appState.cancelScan()
                    }
                } label: {
                    Label("Cancel", systemImage: "xmark")
                        .frame(minWidth: 80)
                }

            case .idle, .completed, .cancelled:
                Button {
                    appState.showFolderPicker = true
                } label: {
                    Label("New Scan", systemImage: "folder.badge.plus")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

struct EstimatedTimeView: View {
    let progress: ScanProgress
    let startTime: Date

    var body: some View {
        if progress.processedFiles > 0 && progress.state == .scanning {
            let elapsed = Date().timeIntervalSince(startTime)
            let rate = Double(progress.processedFiles) / elapsed
            let remaining = Double(progress.totalFiles - progress.processedFiles) / rate

            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)

                Text("Estimated time remaining: \(formatTime(remaining))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        if seconds < 60 {
            return "< 1 minute"
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        } else {
            let hours = Int(seconds / 3600)
            let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }
}
