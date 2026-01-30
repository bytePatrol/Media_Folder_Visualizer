import Foundation
import GRDB

actor DatabaseManager {
    static let shared = DatabaseManager()

    private var dbQueue: DatabaseQueue?

    private init() {}

    func initialize() async throws {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let appDir = appSupport.appendingPathComponent("VideoAnalyzer", isDirectory: true)

        try fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)

        let dbPath = appDir.appendingPathComponent("video_analyzer.sqlite").path

        var config = Configuration()
        config.prepareDatabase { db in
            db.trace { print("SQL: \($0)") }
        }

        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            try db.execute(sql: "PRAGMA synchronous = NORMAL")
            try db.execute(sql: "PRAGMA cache_size = -64000")
            try db.execute(sql: "PRAGMA temp_store = MEMORY")
        }

        dbQueue = try DatabaseQueue(path: dbPath, configuration: config)

        try await migrate()
    }

    private func migrate() async throws {
        guard let db = dbQueue else { throw DatabaseError.notInitialized }

        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_initial") { db in
            try db.create(table: "scan_sessions") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("folder_path", .text).notNull()
                t.column("started_at", .datetime).notNull()
                t.column("completed_at", .datetime)
                t.column("total_files", .integer).notNull().defaults(to: 0)
                t.column("processed_files", .integer).notNull().defaults(to: 0)
                t.column("status", .text).notNull().defaults(to: "in_progress")
                t.column("last_checkpoint_at", .datetime)
                t.column("pending_files", .blob)
            }

            try db.create(table: "video_files") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("file_path", .text).notNull().unique()
                t.column("file_name", .text).notNull()
                t.column("file_size", .integer).notNull()
                t.column("duration_seconds", .double)
                t.column("video_codec", .text)
                t.column("width", .integer)
                t.column("height", .integer)
                t.column("frame_rate", .double)
                t.column("bit_rate", .integer)
                t.column("bit_depth", .integer)
                t.column("hdr_format", .text)
                t.column("audio_codec", .text)
                t.column("audio_channels", .integer)
                t.column("is_atmos", .boolean).notNull().defaults(to: false)
                t.column("is_dtsx", .boolean).notNull().defaults(to: false)
                t.column("container_format", .text)
                t.column("scan_session_id", .integer)
                    .references("scan_sessions", onDelete: .setNull)
                t.column("scanned_at", .datetime).notNull()
            }

            try db.create(index: "idx_video_codec", on: "video_files", columns: ["video_codec"])
            try db.create(index: "idx_resolution", on: "video_files", columns: ["width", "height"])
            try db.create(index: "idx_hdr", on: "video_files", columns: ["hdr_format"])
            try db.create(index: "idx_audio_codec", on: "video_files", columns: ["audio_codec"])
            try db.create(index: "idx_container", on: "video_files", columns: ["container_format"])
            try db.create(index: "idx_session", on: "video_files", columns: ["scan_session_id"])
            try db.create(index: "idx_file_size", on: "video_files", columns: ["file_size"])
            try db.create(index: "idx_duration", on: "video_files", columns: ["duration_seconds"])
        }

        migrator.registerMigration("v2_file_hash") { db in
            try db.alter(table: "video_files") { t in
                t.add(column: "file_hash", .text)
                t.add(column: "is_corrupted", .boolean)
                t.add(column: "corruption_details", .text)
            }

            try db.create(
                index: "idx_file_hash",
                on: "video_files",
                columns: ["file_hash"],
                ifNotExists: true
            )
        }

        try migrator.migrate(db)
    }

    func read<T: Sendable>(_ block: @Sendable @escaping (Database) throws -> T) async throws -> T {
        guard let db = dbQueue else { throw DatabaseError.notInitialized }
        return try await db.read(block)
    }

    func write<T: Sendable>(_ block: @Sendable @escaping (Database) throws -> T) async throws -> T {
        guard let db = dbQueue else { throw DatabaseError.notInitialized }
        return try await db.write(block)
    }

    func writeWithoutTransaction<T: Sendable>(_ block: @Sendable @escaping (Database) throws -> T) async throws -> T {
        guard let db = dbQueue else { throw DatabaseError.notInitialized }
        return try await db.writeWithoutTransaction(block)
    }

}

enum DatabaseError: Error, LocalizedError {
    case notInitialized
    case migrationFailed(String)

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Database has not been initialized"
        case .migrationFailed(let reason):
            return "Database migration failed: \(reason)"
        }
    }
}
