import Foundation
import Combine
import CryptoKit

actor DuplicateDetector {
    private let repository: VideoFileRepository
    private let hashBytesToRead: Int

    private let progressSubject = PassthroughSubject<DuplicateProgress, Never>()

    nonisolated var progressPublisher: AnyPublisher<DuplicateProgress, Never> {
        progressSubject.eraseToAnyPublisher()
    }

    init(repository: VideoFileRepository = VideoFileRepository(), hashBytesToRead: Int = 64 * 1024) {
        self.repository = repository
        self.hashBytesToRead = hashBytesToRead
    }

    func detectDuplicates(files: [VideoFile], method: DuplicateMethod) async -> [DuplicateGroup] {
        switch method {
        case .fuzzy:
            return await detectFuzzyDuplicates(files: files)
        case .partialHash:
            return await detectPartialHashDuplicates(files: files)
        case .fullHash:
            return await detectFullHashDuplicates(files: files)
        }
    }

    private func detectFuzzyDuplicates(files: [VideoFile]) async -> [DuplicateGroup] {
        var groups: [String: [VideoFile]] = [:]
        var processedCount = 0
        let totalCount = files.count

        for file in files {
            let key = fuzzyKey(for: file)
            groups[key, default: []].append(file)

            processedCount += 1
            let progress = DuplicateProgress(
                totalFiles: totalCount,
                processedFiles: processedCount,
                currentFile: file.fileName,
                phase: .analyzing
            )
            progressSubject.send(progress)
        }

        return groups.values
            .filter { $0.count > 1 }
            .map { files in
                DuplicateGroup(
                    id: UUID(),
                    files: files,
                    matchType: .fuzzy,
                    confidence: calculateFuzzyConfidence(files)
                )
            }
            .sorted { $0.totalSize > $1.totalSize }
    }

    private func fuzzyKey(for file: VideoFile) -> String {
        let durationBucket = file.durationSeconds.map { Int($0 / 5) * 5 } ?? 0
        let sizeBucket = Int(file.fileSize / (1024 * 1024))
        let resolution = "\(file.width ?? 0)x\(file.height ?? 0)"

        return "\(durationBucket)_\(sizeBucket)_\(resolution)"
    }

    private func calculateFuzzyConfidence(_ files: [VideoFile]) -> Double {
        guard files.count >= 2 else { return 0 }

        var score = 0.5

        let sizes = files.compactMap { $0.fileSize }
        if let maxSize = sizes.max(), let minSize = sizes.min(), maxSize > 0 {
            let sizeVariation = Double(maxSize - minSize) / Double(maxSize)
            if sizeVariation < 0.01 {
                score += 0.3
            } else if sizeVariation < 0.05 {
                score += 0.2
            } else if sizeVariation < 0.1 {
                score += 0.1
            }
        }

        let codecs = Set(files.map { $0.videoCodec })
        if codecs.count == 1 {
            score += 0.1
        }

        let containers = Set(files.map { $0.containerFormat })
        if containers.count == 1 {
            score += 0.1
        }

        return min(score, 1.0)
    }

    private func detectPartialHashDuplicates(files: [VideoFile]) async -> [DuplicateGroup] {
        var hashGroups: [String: [VideoFile]] = [:]
        var processedCount = 0
        let totalCount = files.count

        for file in files {
            if let hash = await computePartialHash(filePath: file.filePath) {
                hashGroups[hash, default: []].append(file)
            }

            processedCount += 1
            let progress = DuplicateProgress(
                totalFiles: totalCount,
                processedFiles: processedCount,
                currentFile: file.fileName,
                phase: .hashing
            )
            progressSubject.send(progress)
        }

        return hashGroups.values
            .filter { $0.count > 1 }
            .map { files in
                DuplicateGroup(
                    id: UUID(),
                    files: files,
                    matchType: .partialHash,
                    confidence: 0.95
                )
            }
            .sorted { $0.totalSize > $1.totalSize }
    }

    private func detectFullHashDuplicates(files: [VideoFile]) async -> [DuplicateGroup] {
        let sizeGroups = Dictionary(grouping: files) { $0.fileSize }
        let potentialDuplicates = sizeGroups.values.filter { $0.count > 1 }.flatMap { $0 }

        var hashGroups: [String: [VideoFile]] = [:]
        var processedCount = 0
        let totalCount = potentialDuplicates.count

        for file in potentialDuplicates {
            if let hash = await computeFullHash(filePath: file.filePath) {
                hashGroups[hash, default: []].append(file)
            }

            processedCount += 1
            let progress = DuplicateProgress(
                totalFiles: totalCount,
                processedFiles: processedCount,
                currentFile: file.fileName,
                phase: .hashing
            )
            progressSubject.send(progress)
        }

        return hashGroups.values
            .filter { $0.count > 1 }
            .map { files in
                DuplicateGroup(
                    id: UUID(),
                    files: files,
                    matchType: .exactHash,
                    confidence: 1.0
                )
            }
            .sorted { $0.totalSize > $1.totalSize }
    }

    private func computePartialHash(filePath: String) async -> String? {
        guard let handle = FileHandle(forReadingAtPath: filePath) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()

        if let startData = try? handle.read(upToCount: hashBytesToRead) {
            hasher.update(data: startData)
        }

        if let fileSize = try? FileManager.default.attributesOfItem(atPath: filePath)[.size] as? Int64,
           fileSize > Int64(hashBytesToRead * 2) {
            try? handle.seek(toOffset: UInt64(fileSize / 2))
            if let midData = try? handle.read(upToCount: hashBytesToRead) {
                hasher.update(data: midData)
            }

            try? handle.seek(toOffset: UInt64(fileSize) - UInt64(hashBytesToRead))
            if let endData = try? handle.read(upToCount: hashBytesToRead) {
                hasher.update(data: endData)
            }
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func computeFullHash(filePath: String) async -> String? {
        guard let handle = FileHandle(forReadingAtPath: filePath) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        let bufferSize = 1024 * 1024

        while let data = try? handle.read(upToCount: bufferSize), !data.isEmpty {
            hasher.update(data: data)
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

struct DuplicateProgress: Equatable {
    let totalFiles: Int
    let processedFiles: Int
    let currentFile: String
    let phase: DuplicatePhase

    var percentage: Double {
        guard totalFiles > 0 else { return 0 }
        return Double(processedFiles) / Double(totalFiles) * 100
    }
}

enum DuplicatePhase: String {
    case analyzing = "Analyzing"
    case hashing = "Computing hashes"
    case comparing = "Comparing"
}

struct DuplicateGroup: Identifiable, Equatable {
    let id: UUID
    let files: [VideoFile]
    let matchType: DuplicateMatchType
    let confidence: Double

    var fileCount: Int { files.count }

    var totalSize: Int64 {
        files.reduce(0) { $0 + $1.fileSize }
    }

    var potentialSavings: Int64 {
        guard files.count > 1 else { return 0 }
        let sorted = files.sorted { $0.fileSize > $1.fileSize }
        return sorted.dropFirst().reduce(0) { $0 + $1.fileSize }
    }

    var formattedPotentialSavings: String {
        ByteCountFormatter.string(fromByteCount: potentialSavings, countStyle: .file)
    }

    var confidenceDescription: String {
        switch confidence {
        case 1.0:
            return "Exact match"
        case 0.95...:
            return "Very likely"
        case 0.8...:
            return "Likely"
        case 0.6...:
            return "Possible"
        default:
            return "Uncertain"
        }
    }

    static func == (lhs: DuplicateGroup, rhs: DuplicateGroup) -> Bool {
        lhs.id == rhs.id
    }
}

enum DuplicateMatchType: String, CaseIterable {
    case exactHash = "Exact Hash"
    case partialHash = "Partial Hash"
    case fuzzy = "Fuzzy Match"

    var description: String { rawValue }
}

enum DuplicateMethod: String, CaseIterable, Identifiable {
    case fuzzy = "Fuzzy (Fast)"
    case partialHash = "Partial Hash"
    case fullHash = "Full Hash (Slow)"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .fuzzy:
            return "Compares duration, size, and resolution. Fastest but may have false positives."
        case .partialHash:
            return "Computes hash of file sections. Good balance of speed and accuracy."
        case .fullHash:
            return "Computes full file hash. Most accurate but slowest for large files."
        }
    }
}
