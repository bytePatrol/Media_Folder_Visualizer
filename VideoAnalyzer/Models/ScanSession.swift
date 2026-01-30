import Foundation
import GRDB

enum ScanStatus: String, Codable {
    case inProgress = "in_progress"
    case completed = "completed"
    case paused = "paused"
    case cancelled = "cancelled"
    case failed = "failed"
}

struct ScanSession: Identifiable, Equatable {
    var id: Int64?
    let folderPath: String
    let startedAt: Date
    var completedAt: Date?
    var totalFiles: Int
    var processedFiles: Int
    var status: ScanStatus
    var lastCheckpointAt: Date?
    var pendingFiles: [String]?

    var progress: Double {
        guard totalFiles > 0 else { return 0 }
        return Double(processedFiles) / Double(totalFiles)
    }

    var isActive: Bool {
        status == .inProgress || status == .paused
    }

    var formattedDuration: String {
        let endTime = completedAt ?? Date()
        let duration = endTime.timeIntervalSince(startedAt)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

extension ScanSession: FetchableRecord, PersistableRecord {
    static let databaseTableName = "scan_sessions"

    enum Columns: String, ColumnExpression {
        case id
        case folderPath = "folder_path"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case totalFiles = "total_files"
        case processedFiles = "processed_files"
        case status
        case lastCheckpointAt = "last_checkpoint_at"
        case pendingFiles = "pending_files"
    }

    init(row: Row) throws {
        id = row[Columns.id]
        folderPath = row[Columns.folderPath]
        startedAt = row[Columns.startedAt] ?? Date()
        completedAt = row[Columns.completedAt]
        totalFiles = row[Columns.totalFiles] ?? 0
        processedFiles = row[Columns.processedFiles] ?? 0
        status = ScanStatus(rawValue: row[Columns.status] ?? "in_progress") ?? .inProgress

        if let checkpointString: String = row[Columns.lastCheckpointAt] {
            lastCheckpointAt = ISO8601DateFormatter().date(from: checkpointString)
        } else {
            lastCheckpointAt = nil
        }

        if let pendingData: Data = row[Columns.pendingFiles] {
            pendingFiles = try? JSONDecoder().decode([String].self, from: pendingData)
        } else {
            pendingFiles = nil
        }
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
        container[Columns.folderPath] = folderPath
        container[Columns.startedAt] = startedAt
        container[Columns.completedAt] = completedAt
        container[Columns.totalFiles] = totalFiles
        container[Columns.processedFiles] = processedFiles
        container[Columns.status] = status.rawValue
        container[Columns.lastCheckpointAt] = lastCheckpointAt

        if let pending = pendingFiles {
            container[Columns.pendingFiles] = try? JSONEncoder().encode(pending)
        } else {
            container[Columns.pendingFiles] = nil
        }
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

struct ScanCheckpoint: Codable {
    let sessionId: Int64
    let folderPath: String
    let totalFiles: Int
    let processedFiles: Int
    let pendingFilePaths: [String]
    let savedAt: Date

    static let checkpointFileName = "scan_checkpoint.json"

    static var checkpointURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let appDir = appSupport.appendingPathComponent("VideoAnalyzer", isDirectory: true)
        return appDir.appendingPathComponent(checkpointFileName)
    }

    func save() throws {
        let url = Self.checkpointURL
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(self)
        try data.write(to: url)
    }

    static func load() throws -> ScanCheckpoint? {
        let url = checkpointURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ScanCheckpoint.self, from: data)
    }

    static func delete() {
        try? FileManager.default.removeItem(at: checkpointURL)
    }
}
