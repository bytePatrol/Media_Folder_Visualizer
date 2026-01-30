import Foundation

struct StatisticsCalculator {

    static func calculatePercentage(_ count: Int, of total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total) * 100
    }

    static func formatPercentage(_ percentage: Double) -> String {
        String(format: "%.1f%%", percentage)
    }

    static func calculateAverageBitrate(files: [VideoFile]) -> Int? {
        let bitrates = files.compactMap { $0.bitRate }
        guard !bitrates.isEmpty else { return nil }
        return bitrates.reduce(0, +) / bitrates.count
    }

    static func calculateAverageDuration(files: [VideoFile]) -> Double? {
        let durations = files.compactMap { $0.durationSeconds }
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +) / Double(durations.count)
    }

    static func calculateAverageFileSize(files: [VideoFile]) -> Int64? {
        guard !files.isEmpty else { return nil }
        let total = files.reduce(Int64(0)) { $0 + $1.fileSize }
        return total / Int64(files.count)
    }

    static func calculateMedianFileSize(files: [VideoFile]) -> Int64? {
        guard !files.isEmpty else { return nil }
        let sorted = files.map { $0.fileSize }.sorted()
        let middle = sorted.count / 2

        if sorted.count % 2 == 0 {
            return (sorted[middle - 1] + sorted[middle]) / 2
        } else {
            return sorted[middle]
        }
    }

    static func groupByResolution(files: [VideoFile]) -> [String: [VideoFile]] {
        Dictionary(grouping: files) { $0.resolutionCategory }
    }

    static func groupByCodec(files: [VideoFile]) -> [VideoCodec: [VideoFile]] {
        Dictionary(grouping: files) { $0.videoCodec }
    }

    static func groupByHDR(files: [VideoFile]) -> [HDRFormat: [VideoFile]] {
        Dictionary(grouping: files) { $0.hdrFormat }
    }

    static func topCodecs(from statistics: VideoStatistics, count: Int = 5) -> [(VideoCodec, Int)] {
        statistics.codecDistribution
            .sorted { $0.value > $1.value }
            .prefix(count)
            .map { ($0.key, $0.value) }
    }

    static func hdrPercentage(from statistics: VideoStatistics) -> Double {
        let hdrCount = statistics.hdrDistribution
            .filter { $0.key != .sdr }
            .values
            .reduce(0, +)
        return calculatePercentage(hdrCount, of: statistics.totalFiles)
    }

    static func immersiveAudioPercentage(from statistics: VideoStatistics) -> Double {
        let count = statistics.atmosCount + statistics.dtsxCount
        return calculatePercentage(count, of: statistics.totalFiles)
    }

    static func format4KPercentage(from statistics: VideoStatistics) -> Double {
        let count4K = (statistics.resolutionDistribution["4K"] ?? 0) + (statistics.resolutionDistribution["8K"] ?? 0)
        return calculatePercentage(count4K, of: statistics.totalFiles)
    }

    static func calculateStorageByCodec(files: [VideoFile]) -> [VideoCodec: Int64] {
        var result: [VideoCodec: Int64] = [:]
        for file in files {
            result[file.videoCodec, default: 0] += file.fileSize
        }
        return result
    }

    static func calculateStorageByResolution(files: [VideoFile]) -> [String: Int64] {
        var result: [String: Int64] = [:]
        for file in files {
            result[file.resolutionCategory, default: 0] += file.fileSize
        }
        return result
    }

    static func calculateDurationByCodec(files: [VideoFile]) -> [VideoCodec: Double] {
        var result: [VideoCodec: Double] = [:]
        for file in files {
            if let duration = file.durationSeconds {
                result[file.videoCodec, default: 0] += duration
            }
        }
        return result
    }
}
