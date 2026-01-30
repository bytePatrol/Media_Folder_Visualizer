import SwiftUI

struct FilterView: View {
    @EnvironmentObject var appState: AppState

    private let resolutionOptions = ["8K", "4K", "1440p", "1080p", "720p", "480p", "360p", "SD"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VaultSpacing.xl) {
                VStack(alignment: .leading, spacing: VaultSpacing.sm) {
                    Text("Filters")
                        .font(VaultTypography.headline)
                        .foregroundColor(VaultColors.celluloid)

                    Text("Refine your library view")
                        .font(VaultTypography.caption)
                        .foregroundColor(VaultColors.celluloidFaint)
                }

                FilterSection(title: "Resolution") {
                    FlowLayout(spacing: VaultSpacing.xs) {
                        ForEach(resolutionOptions, id: \.self) { resolution in
                            VaultFilterChip(
                                label: resolution,
                                isSelected: appState.filterResolutions.contains(resolution)
                            ) {
                                toggleResolutionFilter(resolution)
                            }
                        }
                    }
                }

                FilterSection(title: "Video Codec") {
                    FlowLayout(spacing: VaultSpacing.xs) {
                        ForEach(VideoCodec.allCases.filter { $0 != .unknown }) { codec in
                            VaultFilterChip(
                                label: codec.displayName,
                                isSelected: appState.filterVideoCodecs.contains(codec)
                            ) {
                                toggleFilter(codec, in: &appState.filterVideoCodecs)
                            }
                        }
                    }
                }

                FilterSection(title: "HDR Format") {
                    FlowLayout(spacing: VaultSpacing.xs) {
                        ForEach(HDRFormat.allCases) { format in
                            VaultFilterChip(
                                label: format.displayName,
                                isSelected: appState.filterHDRFormats.contains(format)
                            ) {
                                toggleFilter(format, in: &appState.filterHDRFormats)
                            }
                        }
                    }
                }

                FilterSection(title: "Audio Codec") {
                    FlowLayout(spacing: VaultSpacing.xs) {
                        ForEach(AudioCodec.allCases.filter { $0 != .unknown }) { codec in
                            VaultFilterChip(
                                label: codec.displayName,
                                isSelected: appState.filterAudioCodecs.contains(codec)
                            ) {
                                toggleFilter(codec, in: &appState.filterAudioCodecs)
                            }
                        }
                    }
                }

                FilterSection(title: "Container") {
                    FlowLayout(spacing: VaultSpacing.xs) {
                        ForEach(ContainerFormat.allCases.filter { $0 != .unknown }) { format in
                            VaultFilterChip(
                                label: format.displayName,
                                isSelected: appState.filterContainers.contains(format)
                            ) {
                                toggleFilter(format, in: &appState.filterContainers)
                            }
                        }
                    }
                }

                FilterSection(title: "Immersive Audio") {
                    HStack(spacing: VaultSpacing.md) {
                        ImmersiveAudioChip(
                            label: "Dolby Atmos",
                            isSelected: appState.filterHasAtmos == true,
                            color: VaultColors.atmos
                        ) {
                            appState.filterHasAtmos = appState.filterHasAtmos == true ? nil : true
                            applyFilters()
                        }

                        ImmersiveAudioChip(
                            label: "DTS:X",
                            isSelected: appState.filterHasDTSX == true,
                            color: VaultColors.dolby
                        ) {
                            appState.filterHasDTSX = appState.filterHasDTSX == true ? nil : true
                            applyFilters()
                        }
                    }
                }

                VaultDivider()

                HStack {
                    Button("Clear All") {
                        appState.clearFilters()
                    }
                    .buttonStyle(VaultGhostButton(color: VaultColors.destructive))
                    .disabled(!hasActiveFilters)

                    Spacer()

                    Button("Apply Filters") {
                        applyFilters()
                    }
                    .buttonStyle(VaultPrimaryButton())
                }
            }
            .padding(VaultSpacing.lg)
        }
        .background(VaultColors.vault)
    }

    private var hasActiveFilters: Bool {
        !appState.filterVideoCodecs.isEmpty ||
        !appState.filterHDRFormats.isEmpty ||
        !appState.filterAudioCodecs.isEmpty ||
        !appState.filterContainers.isEmpty ||
        !appState.filterResolutions.isEmpty ||
        appState.filterHasAtmos != nil ||
        appState.filterHasDTSX != nil
    }

    private func toggleResolutionFilter(_ resolution: String) {
        if appState.filterResolutions.contains(resolution) {
            appState.filterResolutions.remove(resolution)
        } else {
            appState.filterResolutions.insert(resolution)
        }
        applyFilters()
    }

    private func toggleFilter<T: Hashable>(_ item: T, in set: inout Set<T>) {
        if set.contains(item) {
            set.remove(item)
        } else {
            set.insert(item)
        }
        applyFilters()
    }

    private func applyFilters() {
        Task {
            await appState.refreshData()
        }
    }
}

struct FilterSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: VaultSpacing.md) {
            Text(title)
                .font(VaultTypography.captionMedium)
                .foregroundColor(VaultColors.celluloidMuted)
                .textCase(.uppercase)
                .tracking(0.5)

            content()
        }
    }
}

struct ImmersiveAudioChip: View {
    let label: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: VaultSpacing.sm) {
                Image(systemName: "hifispeaker.2.fill")
                    .font(.system(size: 12, weight: .medium))

                Text(label)
                    .font(VaultTypography.captionMedium)
            }
            .foregroundColor(isSelected ? VaultColors.vault : color)
            .padding(.horizontal, VaultSpacing.md)
            .padding(.vertical, VaultSpacing.sm)
            .background(isSelected ? color : color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: VaultRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VaultRadius.md, style: .continuous)
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: isSelected ? color.opacity(0.4) : .clear, radius: 6, x: 0, y: 0)
        }
        .buttonStyle(.plain)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )

        for (index, subview) in subviews.enumerated() {
            let point = result.points[index]
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var points: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                points.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing

                self.size.width = max(self.size.width, currentX)
            }

            self.size.height = currentY + lineHeight
        }
    }
}
