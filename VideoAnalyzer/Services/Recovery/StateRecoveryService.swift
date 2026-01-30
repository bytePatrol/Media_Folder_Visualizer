import Foundation

actor StateRecoveryService {
    private let database: DatabaseManager

    init(database: DatabaseManager = .shared) {
        self.database = database
    }

    func checkForRecoverableScan() async -> RecoveryInfo? {
        guard let checkpoint = try? ScanCheckpoint.load() else {
            return nil
        }

        let folderExists = FileManager.default.fileExists(atPath: checkpoint.folderPath)
        let remainingFiles = checkpoint.pendingFilePaths.filter {
            FileManager.default.fileExists(atPath: $0)
        }

        guard folderExists, !remainingFiles.isEmpty else {
            ScanCheckpoint.delete()
            return nil
        }

        return RecoveryInfo(
            checkpoint: checkpoint,
            remainingFileCount: remainingFiles.count,
            folderPath: checkpoint.folderPath,
            progressPercentage: Double(checkpoint.processedFiles) / Double(checkpoint.totalFiles) * 100
        )
    }

    func getInterruptedSessions() async throws -> [ScanSession] {
        try await database.read { db in
            try ScanSession
                .filter(sql: "status = ? OR status = ?", arguments: [ScanStatus.inProgress.rawValue, ScanStatus.paused.rawValue])
                .order(sql: "started_at DESC")
                .fetchAll(db)
        }
    }

    func markSessionAsFailed(_ sessionId: Int64) async throws {
        try await database.write { db in
            if var session = try ScanSession.fetchOne(db, key: sessionId) {
                session.status = .failed
                session.completedAt = Date()
                try session.update(db)
            }
        }
    }

    func cleanupStaleCheckpoints(olderThan: TimeInterval = 86400) async {
        guard let checkpoint = try? ScanCheckpoint.load() else { return }

        if Date().timeIntervalSince(checkpoint.savedAt) > olderThan {
            ScanCheckpoint.delete()

            if let sessionId = checkpoint.sessionId as Int64? {
                try? await markSessionAsFailed(sessionId)
            }
        }
    }

    nonisolated func deleteCheckpoint() {
        ScanCheckpoint.delete()
    }

    func createManualCheckpoint(
        sessionId: Int64,
        folderPath: String,
        totalFiles: Int,
        processedFiles: Int,
        pendingFiles: [String]
    ) throws {
        let checkpoint = ScanCheckpoint(
            sessionId: sessionId,
            folderPath: folderPath,
            totalFiles: totalFiles,
            processedFiles: processedFiles,
            pendingFilePaths: pendingFiles,
            savedAt: Date()
        )
        try checkpoint.save()
    }
}

struct RecoveryInfo: Equatable {
    let checkpoint: ScanCheckpoint
    let remainingFileCount: Int
    let folderPath: String
    let progressPercentage: Double

    var formattedProgress: String {
        String(format: "%.1f%%", progressPercentage)
    }

    var summary: String {
        "\(checkpoint.processedFiles) of \(checkpoint.totalFiles) files processed (\(formattedProgress))"
    }
}

extension ScanCheckpoint: Equatable {
    static func == (lhs: ScanCheckpoint, rhs: ScanCheckpoint) -> Bool {
        lhs.sessionId == rhs.sessionId &&
        lhs.folderPath == rhs.folderPath &&
        lhs.totalFiles == rhs.totalFiles &&
        lhs.processedFiles == rhs.processedFiles
    }
}
