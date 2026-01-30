import Foundation
import Combine

actor IntegrityChecker {
    private let ffmpegPath: String
    private let maxConcurrency: Int

    private let progressSubject = PassthroughSubject<IntegrityProgress, Never>()
    private let resultSubject = PassthroughSubject<IntegrityResult, Never>()

    nonisolated var progressPublisher: AnyPublisher<IntegrityProgress, Never> {
        progressSubject.eraseToAnyPublisher()
    }

    nonisolated var resultPublisher: AnyPublisher<IntegrityResult, Never> {
        resultSubject.eraseToAnyPublisher()
    }

    init(maxConcurrency: Int = 4) {
        if let bundledPath = Bundle.main.path(forResource: "ffmpeg", ofType: nil) {
            self.ffmpegPath = bundledPath
        } else if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/ffmpeg") {
            self.ffmpegPath = "/opt/homebrew/bin/ffmpeg"
        } else if FileManager.default.fileExists(atPath: "/usr/local/bin/ffmpeg") {
            self.ffmpegPath = "/usr/local/bin/ffmpeg"
        } else {
            self.ffmpegPath = "ffmpeg"
        }
        self.maxConcurrency = maxConcurrency
    }

    func checkIntegrity(of files: [VideoFile]) async -> [IntegrityResult] {
        var results: [IntegrityResult] = []
        var processedCount = 0
        let totalCount = files.count

        await withTaskGroup(of: IntegrityResult.self) { group in
            var activeCount = 0
            var fileIndex = 0

            while fileIndex < files.count || activeCount > 0 {
                while activeCount < maxConcurrency && fileIndex < files.count {
                    let file = files[fileIndex]
                    fileIndex += 1
                    activeCount += 1

                    group.addTask { [self] in
                        await self.checkFile(file)
                    }
                }

                if let result = await group.next() {
                    activeCount -= 1
                    processedCount += 1
                    results.append(result)
                    resultSubject.send(result)

                    let progress = IntegrityProgress(
                        totalFiles: totalCount,
                        processedFiles: processedCount,
                        currentFile: result.fileName
                    )
                    progressSubject.send(progress)
                }
            }
        }

        return results
    }

    func checkFile(_ file: VideoFile) async -> IntegrityResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = [
            "-v", "error",
            "-i", file.filePath,
            "-f", "null",
            "-"
        ]

        let errorPipe = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

            let errors = parseErrors(errorOutput)
            let isCorrupted = !errors.isEmpty

            return IntegrityResult(
                fileId: file.id ?? 0,
                filePath: file.filePath,
                fileName: file.fileName,
                isCorrupted: isCorrupted,
                errors: errors,
                checkedAt: Date()
            )
        } catch {
            return IntegrityResult(
                fileId: file.id ?? 0,
                filePath: file.filePath,
                fileName: file.fileName,
                isCorrupted: true,
                errors: [CorruptionError(
                    type: .processError,
                    message: error.localizedDescription,
                    timestamp: nil
                )],
                checkedAt: Date()
            )
        }
    }

    private func parseErrors(_ output: String) -> [CorruptionError] {
        guard !output.isEmpty else { return [] }

        var errors: [CorruptionError] = []
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }

        for line in lines {
            let error = categorizeError(line)
            errors.append(error)
        }

        return errors
    }

    private func categorizeError(_ line: String) -> CorruptionError {
        let lowercased = line.lowercased()

        let type: CorruptionType
        if lowercased.contains("invalid") || lowercased.contains("corrupt") {
            type = .invalidData
        } else if lowercased.contains("missing") || lowercased.contains("not found") {
            type = .missingData
        } else if lowercased.contains("truncated") || lowercased.contains("end of file") {
            type = .truncated
        } else if lowercased.contains("sync") || lowercased.contains("timestamp") {
            type = .syncError
        } else if lowercased.contains("decode") || lowercased.contains("decoding") {
            type = .decodeError
        } else if lowercased.contains("header") {
            type = .headerError
        } else {
            type = .unknown
        }

        let timestamp = extractTimestamp(line)

        return CorruptionError(type: type, message: line, timestamp: timestamp)
    }

    private func extractTimestamp(_ line: String) -> Double? {
        let patterns = [
            #"(\d+\.?\d*)\s*(?:s|sec)"#,
            #"pts\s*[:=]\s*(\d+)"#,
            #"timestamp\s*[:=]\s*(\d+\.?\d*)"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(
                   in: line,
                   range: NSRange(line.startIndex..., in: line)
               ) {
                if let range = Range(match.range(at: 1), in: line) {
                    return Double(line[range])
                }
            }
        }

        return nil
    }

    func checkAvailability() async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = ["-version"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}

struct IntegrityProgress: Equatable {
    let totalFiles: Int
    let processedFiles: Int
    let currentFile: String

    var percentage: Double {
        guard totalFiles > 0 else { return 0 }
        return Double(processedFiles) / Double(totalFiles) * 100
    }
}

struct IntegrityResult: Identifiable, Equatable {
    let id = UUID()
    let fileId: Int64
    let filePath: String
    let fileName: String
    let isCorrupted: Bool
    let errors: [CorruptionError]
    let checkedAt: Date

    var errorSummary: String {
        if errors.isEmpty {
            return "No errors found"
        }

        let uniqueTypes = Set(errors.map { $0.type })
        let typeDescriptions = uniqueTypes.map { $0.description }
        return typeDescriptions.joined(separator: ", ")
    }
}

struct CorruptionError: Equatable, Identifiable {
    let id = UUID()
    let type: CorruptionType
    let message: String
    let timestamp: Double?

    var formattedTimestamp: String? {
        guard let ts = timestamp else { return nil }
        let minutes = Int(ts) / 60
        let seconds = Int(ts) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

enum CorruptionType: String, CaseIterable {
    case invalidData = "invalid_data"
    case missingData = "missing_data"
    case truncated = "truncated"
    case syncError = "sync_error"
    case decodeError = "decode_error"
    case headerError = "header_error"
    case processError = "process_error"
    case unknown = "unknown"

    var description: String {
        switch self {
        case .invalidData: return "Invalid Data"
        case .missingData: return "Missing Data"
        case .truncated: return "Truncated File"
        case .syncError: return "Sync Error"
        case .decodeError: return "Decode Error"
        case .headerError: return "Header Error"
        case .processError: return "Process Error"
        case .unknown: return "Unknown Error"
        }
    }
}
