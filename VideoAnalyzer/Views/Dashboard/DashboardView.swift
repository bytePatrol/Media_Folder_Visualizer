import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: VaultSpacing.xl) {
                // Hero metrics row
                HeroMetricsView(statistics: appState.statistics)

                // Charts grid
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: VaultSpacing.lg),
                        GridItem(.flexible(), spacing: VaultSpacing.lg)
                    ],
                    spacing: VaultSpacing.lg
                ) {
                    VaultChartCard(title: "Resolution", subtitle: "Distribution by quality") {
                        ResolutionChart(data: appState.statistics.resolutionDistribution)
                    }

                    VaultChartCard(title: "Video Codecs", subtitle: "Encoding formats") {
                        CodecChart(data: appState.statistics.codecDistribution)
                    }

                    VaultChartCard(title: "HDR Formats", subtitle: "High dynamic range content") {
                        HDRChart(data: appState.statistics.hdrDistribution)
                    }

                    VaultChartCard(title: "Audio Codecs", subtitle: "Audio encoding") {
                        AudioChart(data: appState.statistics.audioDistribution)
                    }

                    VaultChartCard(title: "Containers", subtitle: "File formats") {
                        ContainerChart(data: appState.statistics.containerDistribution)
                    }

                    VaultChartCard(title: "File Sizes", subtitle: "Size distribution") {
                        FileSizeChart(files: appState.videoFiles)
                    }
                }
            }
            .padding(VaultSpacing.xl)
        }
        .background(VaultColors.vault)
        .navigationTitle("Dashboard")
    }
}

struct HeroMetricsView: View {
    let statistics: VideoStatistics
    @EnvironmentObject var appState: AppState

    private var hdrCount: Int {
        statistics.hdrDistribution
            .filter { $0.key != .sdr }
            .values
            .reduce(0, +)
    }

    private var immersiveCount: Int {
        statistics.atmosCount + statistics.dtsxCount
    }

    var body: some View {
        HStack(spacing: VaultSpacing.lg) {
            // Primary metric - Total Files (clickable to show all files)
            Button {
                appState.clearFilters()
                appState.selectedTab = .files
                Task { await appState.refreshData() }
            } label: {
                VaultCard {
                    VStack(alignment: .leading, spacing: VaultSpacing.sm) {
                        HStack {
                            Image(systemName: "film.stack.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(VaultColors.projection)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(VaultColors.celluloidFaint)
                        }

                        Text("\(statistics.totalFiles)")
                            .font(VaultTypography.displayLarge)
                            .foregroundColor(VaultColors.celluloid)
                            .monospacedDigit()

                        Text("Total Files")
                            .font(VaultTypography.caption)
                            .foregroundColor(VaultColors.celluloidMuted)
                    }
                }
            }
            .buttonStyle(MetricCardButtonStyle())
            .frame(maxWidth: .infinity)

            // Secondary metrics
            VStack(spacing: VaultSpacing.lg) {
                HStack(spacing: VaultSpacing.lg) {
                    MetricCard(
                        icon: "externaldrive.fill",
                        value: statistics.formattedTotalSize,
                        label: "Total Size",
                        color: VaultColors.celluloidMuted
                    )

                    MetricCard(
                        icon: "clock.fill",
                        value: statistics.formattedTotalDuration,
                        label: "Duration",
                        color: VaultColors.celluloidMuted
                    )
                }

                HStack(spacing: VaultSpacing.lg) {
                    // HDR Content - Clickable
                    Button {
                        appState.navigateToHDRContent()
                    } label: {
                        MetricCardContent(
                            icon: "sparkles",
                            value: "\(hdrCount)",
                            label: "HDR Content",
                            color: VaultColors.hdr,
                            glow: hdrCount > 0,
                            showChevron: hdrCount > 0
                        )
                    }
                    .buttonStyle(MetricCardButtonStyle())
                    .disabled(hdrCount == 0)

                    // Immersive Audio - Clickable
                    Button {
                        appState.navigateToImmersiveAudio()
                    } label: {
                        MetricCardContent(
                            icon: "hifispeaker.2.fill",
                            value: "\(immersiveCount)",
                            label: "Immersive Audio",
                            color: VaultColors.atmos,
                            glow: immersiveCount > 0,
                            showChevron: immersiveCount > 0
                        )
                    }
                    .buttonStyle(MetricCardButtonStyle())
                    .disabled(immersiveCount == 0)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct MetricCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct MetricCardContent: View {
    let icon: String
    let value: String
    let label: String
    var color: Color = VaultColors.celluloidMuted
    var glow: Bool = false
    var showChevron: Bool = false

    var body: some View {
        VaultCard(padding: VaultSpacing.md) {
            HStack(spacing: VaultSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: VaultSpacing.xxs) {
                    Text(value)
                        .font(VaultTypography.headline)
                        .foregroundColor(VaultColors.celluloid)
                        .monospacedDigit()
                        .shadow(color: glow ? color.opacity(0.5) : .clear, radius: 6, x: 0, y: 0)

                    Text(label)
                        .font(VaultTypography.caption)
                        .foregroundColor(VaultColors.celluloidMuted)
                }

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(VaultColors.celluloidFaint)
                }
            }
        }
        .background(
            glow ?
                RoundedRectangle(cornerRadius: VaultRadius.lg, style: .continuous)
                    .fill(color.opacity(0.08))
                : nil
        )
    }
}

struct MetricCard: View {
    let icon: String
    let value: String
    let label: String
    var color: Color = VaultColors.celluloidMuted
    var glow: Bool = false

    var body: some View {
        VaultCard(padding: VaultSpacing.md) {
            HStack(spacing: VaultSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: VaultSpacing.xxs) {
                    Text(value)
                        .font(VaultTypography.headline)
                        .foregroundColor(VaultColors.celluloid)
                        .monospacedDigit()
                        .shadow(color: glow ? color.opacity(0.5) : .clear, radius: 6, x: 0, y: 0)

                    Text(label)
                        .font(VaultTypography.caption)
                        .foregroundColor(VaultColors.celluloidMuted)
                }

                Spacer()
            }
        }
        .background(
            glow ?
                RoundedRectangle(cornerRadius: VaultRadius.lg, style: .continuous)
                    .fill(color.opacity(0.08))
                : nil
        )
    }
}

struct VaultChartCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VaultCard {
            VStack(alignment: .leading, spacing: VaultSpacing.md) {
                VStack(alignment: .leading, spacing: VaultSpacing.xxs) {
                    Text(title)
                        .font(VaultTypography.title)
                        .foregroundColor(VaultColors.celluloid)

                    Text(subtitle)
                        .font(VaultTypography.caption)
                        .foregroundColor(VaultColors.celluloidFaint)
                }

                content()
                    .frame(height: 200)
            }
        }
    }
}
