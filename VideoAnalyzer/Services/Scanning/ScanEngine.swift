import Foundation
import Combine

/// Concurrent video file scanner using Swift Actors for thread safety.
///
/// Architecture:
/// - Uses `withTaskGroup` to process files with bounded concurrency
/// - Batches database inserts for performance (default: 50 files)
/// - Saves checkpoints periodically for crash recovery
/// - Exposes Combine publishers for progress/log/completion events
///
/// Performance considerations:
/// - `maxConcurrency`: Limits parallel ffprobe processes (default: 12)
/// - `batchSize`: Files accumulated before database write (default: 50)
/// - `checkpointInterval`: Seconds between checkpoint saves (default: 10)
/// - Progress updates throttled to every 100ms to reduce UI overhead
actor ScanEngine {
    private let ffprobe: FFProbeRunner
    private let parser: MetadataParser
    private let repository: VideoFileRepository
    private let maxConcurrency: Int
    private let checkpointInterval: TimeInterval
    private let batchSize: Int

    private var currentSession: ScanSession?
    private var pendingFiles: [String] = []
    private var processedCount: Int = 0
    private var isPaused: Bool = false
    private var isCancelled: Bool = false
    private var lastCheckpointTime: Date = Date()
    private var lastProgressTime: Date = Date()
    private var scanTask: Task<Void, Never>?

    // Batch insert buffer
    private var pendingInserts: [VideoFile] = []
    private let insertLock = NSLock()

    private let progressSubject = PassthroughSubject<ScanProgress, Never>()
    private let logSubject = PassthroughSubject<LogEntry, Never>()
    private let completionSubject = PassthroughSubject<ScanResult, Never>()

    nonisolated var progressPublisher: AnyPublisher<ScanProgress, Never> {
        progressSubject.eraseToAnyPublisher()
    }

    nonisolated var logPublisher: AnyPublisher<LogEntry, Never> {
        logSubject.eraseToAnyPublisher()
    }

    nonisolated var completionPublisher: AnyPublisher<ScanResult, Never> {
        completionSubject.eraseToAnyPublisher()
    }

    init(
        ffprobe: FFProbeRunner = FFProbeRunner(timeout: 15),
        repository: VideoFileRepository = VideoFileRepository(),
        maxConcurrency: Int = 12,
        checkpointInterval: TimeInterval = 10.0,
        batchSize: Int = 50
    ) {
        self.ffprobe = ffprobe
        self.parser = MetadataParser()
        self.repository = repository
        self.maxConcurrency = maxConcurrency
        self.checkpointInterval = checkpointInterval
        self.batchSize = batchSize
    }

    func startScan(folderPath: String) async throws {
        guard !isPaused else {
            await resume()
            return
        }

        isCancelled = false
        isPaused = false
        processedCount = 0
        pendingInserts = []

        log(.info, "Starting scan of folder: \(folderPath)")
        log(.info, "Using \(maxConcurrency) concurrent processes")

        let videoFiles = try await discoverVideoFiles(in: folderPath)
        pendingFiles = videoFiles

        log(.info, "Found \(videoFiles.count) video files")

        var session = ScanSession(
            id: nil,
            folderPath: folderPath,
            startedAt: Date(),
            completedAt: nil,
            totalFiles: videoFiles.count,
            processedFiles: 0,
            status: .inProgress,
            lastCheckpointAt: nil,
            pendingFiles: videoFiles
        )

        session = try await saveSession(session)
        currentSession = session

        emitProgress()

        scanTask = Task {
            await processPendingFiles()
        }
    }

    func resumeFromCheckpoint(_ checkpoint: ScanCheckpoint) async throws {
        isCancelled = false
        isPaused = false
        processedCount = checkpoint.processedFiles
        pendingInserts = []

        log(.info, "Resuming scan from checkpoint")
        log(.info, "Progress: \(checkpoint.processedFiles)/\(checkpoint.totalFiles) files")

        pendingFiles = checkpoint.pendingFilePaths

        if var session = try await fetchSession(id: checkpoint.sessionId) {
            session.status = .inProgress
            currentSession = try await updateSession(session)
        }

        emitProgress()

        scanTask = Task {
            await processPendingFiles()
        }
    }

    func pause() async {
        guard !isPaused, !isCancelled else { return }

        isPaused = true
        log(.info, "Scan paused at \(processedCount)/\(currentSession?.totalFiles ?? 0) files")

        // Flush pending inserts
        await flushPendingInserts()

        if var session = currentSession {
            session.status = .paused
            session.processedFiles = processedCount
            session.pendingFiles = pendingFiles
            currentSession = try? await updateSession(session)
        }

        await saveCheckpoint()

        let progress = ScanProgress(
            totalFiles: currentSession?.totalFiles ?? 0,
            processedFiles: processedCount,
            currentFile: nil,
            state: .paused
        )
        progressSubject.send(progress)
    }

    func resume() async {
        guard isPaused else { return }

        isPaused = false
        log(.info, "Scan resumed")

        if var session = currentSession {
            session.status = .inProgress
            currentSession = try? await updateSession(session)
        }

        emitProgress()

        scanTask = Task {
            await processPendingFiles()
        }
    }

    func cancel() async {
        isCancelled = true
        isPaused = false
        scanTask?.cancel()
        scanTask = nil

        log(.warning, "Scan cancelled")

        // Flush any pending inserts before cancelling
        await flushPendingInserts()

        if var session = currentSession {
            session.status = .cancelled
            session.completedAt = Date()
            currentSession = try? await updateSession(session)
        }

        ScanCheckpoint.delete()

        let progress = ScanProgress(
            totalFiles: currentSession?.totalFiles ?? 0,
            processedFiles: processedCount,
            currentFile: nil,
            state: .cancelled
        )
        progressSubject.send(progress)
    }

    var isScanning: Bool {
        currentSession?.status == .inProgress
    }

    private func processPendingFiles() async {
        await withTaskGroup(of: VideoFile?.self) { group in
            var activeCount = 0

            while !pendingFiles.isEmpty && !isCancelled && !isPaused {
                while activeCount < maxConcurrency && !pendingFiles.isEmpty {
                    let filePath = pendingFiles.removeFirst()
                    activeCount += 1

                    group.addTask { [self] in
                        await self.processFile(filePath)
                    }
                }

                if let result = await group.next() {
                    activeCount -= 1

                    // Add to batch insert buffer
                    if let videoFile = result {
                        pendingInserts.append(videoFile)

                        // Flush batch when full
                        if pendingInserts.count >= batchSize {
                            await flushPendingInserts()
                        }
                    }

                    processedCount += 1

                    // Throttle progress updates to every 100ms
                    if Date().timeIntervalSince(lastProgressTime) >= 0.1 {
                        emitProgress()
                        lastProgressTime = Date()
                    }
                }

                if shouldCheckpoint() {
                    await flushPendingInserts()
                    await saveCheckpoint()
                }
            }

            // Drain remaining tasks
            for await result in group {
                if let videoFile = result {
                    pendingInserts.append(videoFile)
                }
                processedCount += 1
            }
        }

        // Flush remaining inserts
        await flushPendingInserts()

        if !isCancelled && !isPaused {
            await completeScan()
        }
    }

    /// Processes a single file with retry logic.
    ///
    /// Retry strategy:
    /// - Max 3 retries for transient failures (network, busy file handles)
    /// - Exponential backoff: 500ms → 1s → 2s between attempts
    /// - Returns nil (not throws) to allow scan to continue on failure
    ///
    /// - Note: This is essential for network volumes where files may be
    ///   temporarily unavailable or slow to respond.
    private func processFile(_ filePath: String, retryCount: Int = 0) async -> VideoFile? {
        let maxRetries = 3
        let fileName = (filePath as NSString).lastPathComponent

        do {
            let fileSize = try getFileSize(filePath)
            let ffprobeOutput = try await ffprobe.probe(filePath: filePath)
            let metadata = parser.parse(output: ffprobeOutput, filePath: filePath, fileSize: fileSize)
            return metadata.toVideoFile(sessionId: currentSession?.id)
        } catch {
            if retryCount < maxRetries {
                // Exponential backoff: 500ms, 1s, 2s
                // Bit shift calculates: 500 * 2^retryCount
                let delayMs = 500 * (1 << retryCount)
                try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
                return await processFile(filePath, retryCount: retryCount + 1)
            } else {
                logWithFile(.error, "Failed after \(maxRetries) retries: \(fileName) - \(error.localizedDescription)", filePath: filePath)
                return nil
            }
        }
    }

    private func flushPendingInserts() async {
        guard !pendingInserts.isEmpty else { return }

        let toInsert = pendingInserts
        pendingInserts = []

        do {
            try await repository.insertBatch(toInsert)
        } catch {
            log(.error, "Batch insert failed: \(error.localizedDescription)")
        }
    }

    private func completeScan() async {
        if var session = currentSession {
            session.status = .completed
            session.completedAt = Date()
            session.processedFiles = processedCount
            currentSession = try? await updateSession(session)
        }

        ScanCheckpoint.delete()

        log(.success, "Scan completed: \(processedCount) files processed")

        let progress = ScanProgress(
            totalFiles: currentSession?.totalFiles ?? 0,
            processedFiles: processedCount,
            currentFile: nil,
            state: .completed
        )
        progressSubject.send(progress)

        let result = ScanResult(
            totalFiles: currentSession?.totalFiles ?? 0,
            processedFiles: processedCount,
            duration: currentSession?.formattedDuration ?? "Unknown",
            folderPath: currentSession?.folderPath ?? ""
        )
        completionSubject.send(result)
    }

    private func discoverVideoFiles(in folderPath: String) async throws -> [String] {
        var videoFiles: [String] = []
        let fileManager = FileManager.default
        let extensions = ContainerFormat.supportedExtensions

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: folderPath),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw ScanError.folderAccessDenied(folderPath)
        }

        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if extensions.contains(ext) {
                videoFiles.append(fileURL.path)
            }
        }

        return videoFiles
    }

    private func getFileSize(_ path: String) throws -> Int64 {
        let attrs = try FileManager.default.attributesOfItem(atPath: path)
        return attrs[.size] as? Int64 ?? 0
    }

    private func shouldCheckpoint() -> Bool {
        Date().timeIntervalSince(lastCheckpointTime) >= checkpointInterval
    }

    private func saveCheckpoint() async {
        guard let session = currentSession, let sessionId = session.id else { return }

        let checkpoint = ScanCheckpoint(
            sessionId: sessionId,
            folderPath: session.folderPath,
            totalFiles: session.totalFiles,
            processedFiles: processedCount,
            pendingFilePaths: pendingFiles,
            savedAt: Date()
        )

        do {
            try checkpoint.save()
            lastCheckpointTime = Date()
        } catch {
            log(.warning, "Failed to save checkpoint: \(error.localizedDescription)")
        }
    }

    private func emitProgress() {
        let progress = ScanProgress(
            totalFiles: currentSession?.totalFiles ?? 0,
            processedFiles: processedCount,
            currentFile: nil,
            state: isPaused ? .paused : .scanning
        )
        progressSubject.send(progress)
    }

    private func log(_ level: LogLevel, _ message: String) {
        let entry = LogEntry(timestamp: Date(), level: level, message: message)
        logSubject.send(entry)
    }

    private func logWithFile(_ level: LogLevel, _ message: String, filePath: String) {
        let entry = LogEntry(timestamp: Date(), level: level, message: message, filePath: filePath)
        logSubject.send(entry)
    }

    private func saveSession(_ session: ScanSession) async throws -> ScanSession {
        try await DatabaseManager.shared.write { db in
            var mutableSession = session
            try mutableSession.insert(db)
            return mutableSession
        }
    }

    private func updateSession(_ session: ScanSession) async throws -> ScanSession {
        try await DatabaseManager.shared.write { db in
            try session.update(db)
            return session
        }
    }

    private func fetchSession(id: Int64) async throws -> ScanSession? {
        try await DatabaseManager.shared.read { db in
            try ScanSession.fetchOne(db, key: id)
        }
    }
}

struct ScanProgress: Equatable {
    let totalFiles: Int
    let processedFiles: Int
    let currentFile: String?
    let state: ScanState

    var percentage: Double {
        guard totalFiles > 0 else { return 0 }
        return Double(processedFiles) / Double(totalFiles) * 100
    }
}

enum ScanState: Equatable {
    case idle
    case scanning
    case paused
    case completed
    case cancelled
}

struct ScanResult {
    let totalFiles: Int
    let processedFiles: Int
    let duration: String
    let folderPath: String
}

struct LogEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String
    let filePath: String?

    init(timestamp: Date, level: LogLevel, message: String, filePath: String? = nil) {
        self.timestamp = timestamp
        self.level = level
        self.message = message
        self.filePath = filePath
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }

    /// Returns true if this is a clickable error entry (has a file path)
    var isClickable: Bool {
        filePath != nil && level == .error
    }
}

enum LogLevel: String {
    case info = "INFO"
    case success = "SUCCESS"
    case warning = "WARNING"
    case error = "ERROR"
}

enum ScanError: Error, LocalizedError {
    case folderAccessDenied(String)
    case noVideoFilesFound
    case scanAlreadyInProgress

    var errorDescription: String? {
        switch self {
        case .folderAccessDenied(let path):
            return "Cannot access folder: \(path)"
        case .noVideoFilesFound:
            return "No video files found in the selected folder"
        case .scanAlreadyInProgress:
            return "A scan is already in progress"
        }
    }
}
