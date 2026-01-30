import SwiftUI
import Charts

// MARK: - Chart Color Palette
private enum ChartPalette {
    static let resolution: [Color] = [
        VaultColors.chartPurple,
        VaultColors.chartBlue,
        VaultColors.chartCyan,
        VaultColors.chartGreen,
        VaultColors.chartAmber,
        VaultColors.chartOrange,
        VaultColors.chartPink,
        VaultColors.chartGray
    ]

    static let hdr: [HDRFormat: Color] = [
        .sdr: VaultColors.chartGray,
        .hdr10: VaultColors.hdr,
        .hdr10Plus: VaultColors.chartAmber,
        .dolbyVision: VaultColors.dolby,
        .hlg: VaultColors.chartGreen,
        .dolbyVisionHDR10: VaultColors.chartPink
    ]
}

struct ResolutionChart: View {
    let data: [String: Int]
    @EnvironmentObject var appState: AppState

    private var chartData: [(category: String, count: Int, color: Color)] {
        let sortOrder = ["8K", "4K", "1440p", "1080p", "720p", "480p", "360p", "SD"]

        return sortOrder.enumerated().compactMap { index, category in
            guard let count = data[category], count > 0 else { return nil }
            return (category: category, count: count, color: ChartPalette.resolution[index % ChartPalette.resolution.count])
        }
    }

    private var totalCount: Int {
        chartData.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        if chartData.isEmpty {
            EmptyChartView()
        } else {
            HStack(spacing: VaultSpacing.lg) {
                // Donut chart
                Chart(chartData, id: \.category) { item in
                    SectorMark(
                        angle: .value("Count", item.count),
                        innerRadius: .ratio(0.6),
                        angularInset: 2
                    )
                    .foregroundStyle(item.color)
                    .cornerRadius(3)
                }
                .chartLegend(.hidden)
                .frame(maxWidth: 160)

                // Custom legend - clickable to filter
                VStack(alignment: .leading, spacing: VaultSpacing.xs) {
                    ForEach(chartData, id: \.category) { item in
                        ChartLegendItem(
                            color: item.color,
                            label: item.category,
                            value: item.count,
                            percentage: Double(item.count) / Double(totalCount) * 100,
                            action: {
                                appState.navigateToResolution(item.category)
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct CodecChart: View {
    let data: [VideoCodec: Int]
    @EnvironmentObject var appState: AppState

    private var chartData: [(codec: VideoCodec, displayName: String, count: Int)] {
        let mapped = data.map { (codec: $0.key, displayName: $0.key.displayName, count: $0.value) }
        let sorted = mapped.sorted(by: { $0.count > $1.count })
        return Array(sorted.prefix(6))
    }

    var body: some View {
        if chartData.isEmpty {
            EmptyChartView()
        } else {
            Chart(chartData, id: \.displayName) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Codec", item.displayName)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [VaultColors.chartBlue, VaultColors.chartCyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(VaultRadius.sm)
                .annotation(position: .trailing, alignment: .leading) {
                    Button {
                        appState.navigateToCodec(item.codec)
                    } label: {
                        HStack(spacing: VaultSpacing.xs) {
                            Text("\(item.count)")
                                .font(VaultTypography.monoSmall)
                                .foregroundColor(VaultColors.celluloidMuted)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(VaultColors.celluloidFaint)
                        }
                        .padding(.leading, VaultSpacing.xs)
                    }
                    .buttonStyle(.plain)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(VaultTypography.caption)
                        .foregroundStyle(VaultColors.celluloidMuted)
                }
            }
        }
    }
}

struct HDRChart: View {
    let data: [HDRFormat: Int]
    @EnvironmentObject var appState: AppState

    private var chartData: [(format: HDRFormat, displayName: String, count: Int, color: Color)] {
        let mapped = data.map { (
            format: $0.key,
            displayName: $0.key.displayName,
            count: $0.value,
            color: ChartPalette.hdr[$0.key] ?? VaultColors.chartGray
        ) }
        return mapped.sorted(by: { $0.count > $1.count })
    }

    private var totalCount: Int {
        chartData.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        if chartData.isEmpty {
            EmptyChartView()
        } else {
            HStack(spacing: VaultSpacing.lg) {
                // Donut chart with HDR glow effect
                ZStack {
                    Chart(chartData, id: \.displayName) { item in
                        SectorMark(
                            angle: .value("Count", item.count),
                            innerRadius: .ratio(0.6),
                            angularInset: 2
                        )
                        .foregroundStyle(item.color)
                        .cornerRadius(3)
                    }
                    .chartLegend(.hidden)

                    // Center glow for premium content
                    if chartData.contains(where: { $0.displayName.contains("Dolby") }) {
                        Circle()
                            .fill(VaultColors.dolby.opacity(0.1))
                            .frame(width: 60, height: 60)
                            .blur(radius: 10)
                    }
                }
                .frame(maxWidth: 160)

                // Custom legend with glow for premium formats - clickable
                VStack(alignment: .leading, spacing: VaultSpacing.xs) {
                    ForEach(chartData, id: \.displayName) { item in
                        ChartLegendItem(
                            color: item.color,
                            label: item.displayName,
                            value: item.count,
                            percentage: Double(item.count) / Double(totalCount) * 100,
                            glow: item.displayName.contains("Dolby") || item.displayName.contains("HDR10"),
                            action: {
                                appState.navigateToHDRFormat(item.format)
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct AudioChart: View {
    let data: [AudioCodec: Int]
    @EnvironmentObject var appState: AppState

    private var chartData: [(codec: AudioCodec, displayName: String, count: Int)] {
        let mapped = data.map { (codec: $0.key, displayName: $0.key.displayName, count: $0.value) }
        let sorted = mapped.sorted(by: { $0.count > $1.count })
        return Array(sorted.prefix(6))
    }

    var body: some View {
        if chartData.isEmpty {
            EmptyChartView()
        } else {
            Chart(chartData, id: \.displayName) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Codec", item.displayName)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [VaultColors.chartGreen, VaultColors.atmos],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(VaultRadius.sm)
                .annotation(position: .trailing, alignment: .leading) {
                    Button {
                        appState.navigateToAudioCodec(item.codec)
                    } label: {
                        HStack(spacing: VaultSpacing.xs) {
                            Text("\(item.count)")
                                .font(VaultTypography.monoSmall)
                                .foregroundColor(VaultColors.celluloidMuted)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(VaultColors.celluloidFaint)
                        }
                        .padding(.leading, VaultSpacing.xs)
                    }
                    .buttonStyle(.plain)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(VaultTypography.caption)
                        .foregroundStyle(VaultColors.celluloidMuted)
                }
            }
        }
    }
}

struct ContainerChart: View {
    let data: [ContainerFormat: Int]
    @EnvironmentObject var appState: AppState

    private var chartData: [(format: ContainerFormat, displayName: String, count: Int)] {
        let mapped = data.map { (format: $0.key, displayName: $0.key.displayName, count: $0.value) }
        let sorted = mapped.sorted(by: { $0.count > $1.count })
        return Array(sorted.prefix(6))
    }

    var body: some View {
        if chartData.isEmpty {
            EmptyChartView()
        } else {
            Chart(chartData, id: \.displayName) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Format", item.displayName)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [VaultColors.chartPurple, VaultColors.chartPink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(VaultRadius.sm)
                .annotation(position: .trailing, alignment: .leading) {
                    Button {
                        appState.navigateToContainer(item.format)
                    } label: {
                        HStack(spacing: VaultSpacing.xs) {
                            Text("\(item.count)")
                                .font(VaultTypography.monoSmall)
                                .foregroundColor(VaultColors.celluloidMuted)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(VaultColors.celluloidFaint)
                        }
                        .padding(.leading, VaultSpacing.xs)
                    }
                    .buttonStyle(.plain)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(VaultTypography.caption)
                        .foregroundStyle(VaultColors.celluloidMuted)
                }
            }
        }
    }
}

struct FileSizeChart: View {
    let files: [VideoFile]

    private var chartData: [(range: String, count: Int)] {
        var buckets: [String: Int] = [
            "< 1 GB": 0,
            "1-5 GB": 0,
            "5-10 GB": 0,
            "10-20 GB": 0,
            "20-50 GB": 0,
            "> 50 GB": 0
        ]

        for file in files {
            let sizeGB = Double(file.fileSize) / (1024 * 1024 * 1024)

            if sizeGB < 1 {
                buckets["< 1 GB", default: 0] += 1
            } else if sizeGB < 5 {
                buckets["1-5 GB", default: 0] += 1
            } else if sizeGB < 10 {
                buckets["5-10 GB", default: 0] += 1
            } else if sizeGB < 20 {
                buckets["10-20 GB", default: 0] += 1
            } else if sizeGB < 50 {
                buckets["20-50 GB", default: 0] += 1
            } else {
                buckets["> 50 GB", default: 0] += 1
            }
        }

        let order = ["< 1 GB", "1-5 GB", "5-10 GB", "10-20 GB", "20-50 GB", "> 50 GB"]
        return order.map { (range: $0, count: buckets[$0] ?? 0) }
    }

    var body: some View {
        if files.isEmpty {
            EmptyChartView()
        } else {
            Chart(chartData, id: \.range) { item in
                BarMark(
                    x: .value("Range", item.range),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [VaultColors.chartAmber, VaultColors.chartOrange],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(VaultRadius.sm)
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let range = value.as(String.self) {
                            Text(range)
                                .font(VaultTypography.micro)
                                .foregroundStyle(VaultColors.celluloidMuted)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                        .foregroundStyle(VaultColors.border)
                    AxisValueLabel()
                        .font(VaultTypography.monoSmall)
                        .foregroundStyle(VaultColors.celluloidFaint)
                }
            }
        }
    }
}

struct FrameRateChart: View {
    let files: [VideoFile]

    private var chartData: [(fps: String, count: Int)] {
        var buckets: [String: Int] = [:]

        for file in files {
            guard let fps = file.frameRate else { continue }

            let bucket: String
            if fps <= 24 {
                bucket = "24 fps"
            } else if fps <= 25 {
                bucket = "25 fps"
            } else if fps <= 30 {
                bucket = "30 fps"
            } else if fps <= 50 {
                bucket = "50 fps"
            } else if fps <= 60 {
                bucket = "60 fps"
            } else {
                bucket = "> 60 fps"
            }

            buckets[bucket, default: 0] += 1
        }

        let order = ["24 fps", "25 fps", "30 fps", "50 fps", "60 fps", "> 60 fps"]
        return order.compactMap { fps in
            guard let count = buckets[fps], count > 0 else { return nil }
            return (fps: fps, count: count)
        }
    }

    var body: some View {
        if chartData.isEmpty {
            EmptyChartView()
        } else {
            Chart(chartData, id: \.fps) { item in
                BarMark(
                    x: .value("FPS", item.fps),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [VaultColors.chartCyan, VaultColors.chartBlue],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(VaultRadius.sm)
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let fps = value.as(String.self) {
                            Text(fps)
                                .font(VaultTypography.micro)
                                .foregroundStyle(VaultColors.celluloidMuted)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                        .foregroundStyle(VaultColors.border)
                    AxisValueLabel()
                        .font(VaultTypography.monoSmall)
                        .foregroundStyle(VaultColors.celluloidFaint)
                }
            }
        }
    }
}

struct BitrateChart: View {
    let files: [VideoFile]

    private var chartData: [(range: String, count: Int)] {
        var buckets: [String: Int] = [
            "< 5 Mbps": 0,
            "5-10 Mbps": 0,
            "10-20 Mbps": 0,
            "20-40 Mbps": 0,
            "40-80 Mbps": 0,
            "> 80 Mbps": 0
        ]

        for file in files {
            guard let bitRate = file.bitRate else { continue }
            let mbps = Double(bitRate) / 1_000_000

            if mbps < 5 {
                buckets["< 5 Mbps", default: 0] += 1
            } else if mbps < 10 {
                buckets["5-10 Mbps", default: 0] += 1
            } else if mbps < 20 {
                buckets["10-20 Mbps", default: 0] += 1
            } else if mbps < 40 {
                buckets["20-40 Mbps", default: 0] += 1
            } else if mbps < 80 {
                buckets["40-80 Mbps", default: 0] += 1
            } else {
                buckets["> 80 Mbps", default: 0] += 1
            }
        }

        let order = ["< 5 Mbps", "5-10 Mbps", "10-20 Mbps", "20-40 Mbps", "40-80 Mbps", "> 80 Mbps"]
        return order.map { (range: $0, count: buckets[$0] ?? 0) }
    }

    var body: some View {
        if files.isEmpty {
            EmptyChartView()
        } else {
            Chart(chartData, id: \.range) { item in
                BarMark(
                    x: .value("Range", item.range),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [VaultColors.chartPink, VaultColors.chartPurple],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(VaultRadius.sm)
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let range = value.as(String.self) {
                            Text(range)
                                .font(VaultTypography.micro)
                                .foregroundStyle(VaultColors.celluloidMuted)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                        .foregroundStyle(VaultColors.border)
                    AxisValueLabel()
                        .font(VaultTypography.monoSmall)
                        .foregroundStyle(VaultColors.celluloidFaint)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct ChartLegendItem: View {
    let color: Color
    let label: String
    let value: Int
    let percentage: Double
    var glow: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        let content = HStack(spacing: VaultSpacing.sm) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .shadow(color: glow ? color.opacity(0.6) : .clear, radius: 4, x: 0, y: 0)

            Text(label)
                .font(VaultTypography.caption)
                .foregroundColor(VaultColors.celluloidMuted)
                .lineLimit(1)

            Spacer()

            Text("\(value)")
                .font(VaultTypography.monoSmall)
                .foregroundColor(VaultColors.celluloid)
                .monospacedDigit()

            Text(String(format: "%.0f%%", percentage))
                .font(VaultTypography.micro)
                .foregroundColor(VaultColors.celluloidFaint)
                .frame(width: 32, alignment: .trailing)

            if action != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(VaultColors.celluloidFaint)
            }
        }
        .padding(.vertical, VaultSpacing.xxs)

        if let action = action {
            Button(action: action) {
                content
            }
            .buttonStyle(LegendItemButtonStyle())
        } else {
            content
        }
    }
}

struct LegendItemButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: VaultRadius.sm, style: .continuous)
                    .fill(configuration.isPressed ? VaultColors.screenHover : Color.clear)
            )
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}

struct EmptyChartView: View {
    var body: some View {
        VStack(spacing: VaultSpacing.md) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(VaultColors.celluloidFaint)

            Text("No data available")
                .font(VaultTypography.caption)
                .foregroundColor(VaultColors.celluloidMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
