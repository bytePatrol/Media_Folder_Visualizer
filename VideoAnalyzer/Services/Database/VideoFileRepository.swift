import Foundation
import GRDB

actor VideoFileRepository {
    private let database: DatabaseManager

    init(database: DatabaseManager = .shared) {
        self.database = database
    }

    func insert(_ file: VideoFile) async throws -> VideoFile {
        var mutableFile = file
        try await database.write { db in
            try mutableFile.insert(db)
        }
        return mutableFile
    }

    func insertBatch(_ files: [VideoFile]) async throws {
        try await database.write { db in
            for var file in files {
                try file.insert(db, onConflict: .replace)
            }
        }
    }

    func update(_ file: VideoFile) async throws {
        try await database.write { db in
            try file.update(db)
        }
    }

    func delete(_ file: VideoFile) async throws {
        _ = try await database.write { db in
            try file.delete(db)
        }
    }

    func deleteAll() async throws {
        _ = try await database.write { db in
            try VideoFile.deleteAll(db)
        }
    }

    func deleteBySessionId(_ sessionId: Int64) async throws {
        _ = try await database.write { db in
            try VideoFile
                .filter(VideoFile.Columns.scanSessionId == sessionId)
                .deleteAll(db)
        }
    }

    func fetchAll() async throws -> [VideoFile] {
        try await database.read { db in
            try VideoFile
                .order(VideoFile.Columns.fileName)
                .fetchAll(db)
        }
    }

    func fetchBySessionId(_ sessionId: Int64) async throws -> [VideoFile] {
        try await database.read { db in
            try VideoFile
                .filter(VideoFile.Columns.scanSessionId == sessionId)
                .order(VideoFile.Columns.fileName)
                .fetchAll(db)
        }
    }

    func fetchByPath(_ path: String) async throws -> VideoFile? {
        try await database.read { db in
            try VideoFile
                .filter(VideoFile.Columns.filePath == path)
                .fetchOne(db)
        }
    }

    func exists(path: String) async throws -> Bool {
        try await database.read { db in
            try VideoFile
                .filter(VideoFile.Columns.filePath == path)
                .fetchCount(db) > 0
        }
    }

    func count() async throws -> Int {
        try await database.read { db in
            try VideoFile.fetchCount(db)
        }
    }

    func fetchFiltered(
        searchText: String? = nil,
        videoCodecs: Set<VideoCodec>? = nil,
        hdrFormats: Set<HDRFormat>? = nil,
        audioCodecs: Set<AudioCodec>? = nil,
        containers: Set<ContainerFormat>? = nil,
        resolutionCategories: Set<String>? = nil,
        hasAtmos: Bool? = nil,
        hasDTSX: Bool? = nil,
        minDuration: Double? = nil,
        maxDuration: Double? = nil,
        minSize: Int64? = nil,
        maxSize: Int64? = nil,
        sortColumn: SortColumn = .fileName,
        sortAscending: Bool = true,
        limit: Int? = nil,
        offset: Int? = nil
    ) async throws -> [VideoFile] {
        try await database.read { db in
            var query = VideoFile.all()

            if let search = searchText, !search.isEmpty {
                query = query.filter(VideoFile.Columns.fileName.like("%\(search)%"))
            }

            if let codecs = videoCodecs, !codecs.isEmpty {
                let codecStrings = codecs.map { $0.rawValue }
                query = query.filter(codecStrings.contains(VideoFile.Columns.videoCodec))
            }

            if let hdrs = hdrFormats, !hdrs.isEmpty {
                let hdrStrings = hdrs.map { $0.rawValue }
                query = query.filter(hdrStrings.contains(VideoFile.Columns.hdrFormat))
            }

            if let audios = audioCodecs, !audios.isEmpty {
                let audioStrings = audios.map { $0.rawValue }
                query = query.filter(audioStrings.contains(VideoFile.Columns.audioCodec))
            }

            if let conts = containers, !conts.isEmpty {
                let contStrings = conts.map { $0.rawValue }
                query = query.filter(contStrings.contains(VideoFile.Columns.containerFormat))
            }

            if let atmos = hasAtmos {
                query = query.filter(VideoFile.Columns.isAtmos == atmos)
            }

            if let dtsx = hasDTSX {
                query = query.filter(VideoFile.Columns.isDTSX == dtsx)
            }

            // Resolution category filtering using height ranges
            if let resolutions = resolutionCategories, !resolutions.isEmpty {
                // Build a SQL expression for OR conditions
                let heightCol = VideoFile.Columns.height
                var sqlParts: [String] = []
                var arguments: [Int] = []

                for res in resolutions {
                    switch res {
                    case "8K":
                        sqlParts.append("height >= ?")
                        arguments.append(4320)
                    case "4K":
                        sqlParts.append("(height >= ? AND height < ?)")
                        arguments.append(contentsOf: [2160, 4320])
                    case "1440p":
                        sqlParts.append("(height >= ? AND height < ?)")
                        arguments.append(contentsOf: [1440, 2160])
                    case "1080p":
                        sqlParts.append("(height >= ? AND height < ?)")
                        arguments.append(contentsOf: [1080, 1440])
                    case "720p":
                        sqlParts.append("(height >= ? AND height < ?)")
                        arguments.append(contentsOf: [720, 1080])
                    case "480p":
                        sqlParts.append("(height >= ? AND height < ?)")
                        arguments.append(contentsOf: [480, 720])
                    case "360p":
                        sqlParts.append("(height >= ? AND height < ?)")
                        arguments.append(contentsOf: [360, 480])
                    case "SD":
                        sqlParts.append("height < ?")
                        arguments.append(360)
                    default:
                        break
                    }
                }

                if !sqlParts.isEmpty {
                    let sqlString = "(" + sqlParts.joined(separator: " OR ") + ")"
                    query = query.filter(sql: sqlString, arguments: StatementArguments(arguments))
                }
            }

            if let minDur = minDuration {
                query = query.filter(VideoFile.Columns.durationSeconds >= minDur)
            }

            if let maxDur = maxDuration {
                query = query.filter(VideoFile.Columns.durationSeconds <= maxDur)
            }

            if let minS = minSize {
                query = query.filter(VideoFile.Columns.fileSize >= minS)
            }

            if let maxS = maxSize {
                query = query.filter(VideoFile.Columns.fileSize <= maxS)
            }

            switch sortColumn {
            case .fileName:
                query = sortAscending ? query.order(VideoFile.Columns.fileName) : query.order(VideoFile.Columns.fileName.desc)
            case .fileSize:
                query = sortAscending ? query.order(VideoFile.Columns.fileSize) : query.order(VideoFile.Columns.fileSize.desc)
            case .duration:
                query = sortAscending ? query.order(VideoFile.Columns.durationSeconds) : query.order(VideoFile.Columns.durationSeconds.desc)
            case .resolution:
                query = sortAscending ? query.order(VideoFile.Columns.height) : query.order(VideoFile.Columns.height.desc)
            case .videoCodec:
                query = sortAscending ? query.order(VideoFile.Columns.videoCodec) : query.order(VideoFile.Columns.videoCodec.desc)
            case .hdrFormat:
                query = sortAscending ? query.order(VideoFile.Columns.hdrFormat) : query.order(VideoFile.Columns.hdrFormat.desc)
            case .audioCodec:
                query = sortAscending ? query.order(VideoFile.Columns.audioCodec) : query.order(VideoFile.Columns.audioCodec.desc)
            case .bitRate:
                query = sortAscending ? query.order(VideoFile.Columns.bitRate) : query.order(VideoFile.Columns.bitRate.desc)
            case .container:
                query = sortAscending ? query.order(VideoFile.Columns.containerFormat) : query.order(VideoFile.Columns.containerFormat.desc)
            }

            if let lim = limit {
                query = query.limit(lim, offset: offset)
            }

            return try query.fetchAll(db)
        }
    }

    func fetchStatistics() async throws -> VideoStatistics {
        try await database.read { db in
            let totalCount = try VideoFile.fetchCount(db)
            let totalSize = try Int64.fetchOne(
                db,
                sql: "SELECT COALESCE(SUM(file_size), 0) FROM video_files"
            ) ?? 0
            let totalDuration = try Double.fetchOne(
                db,
                sql: "SELECT COALESCE(SUM(duration_seconds), 0) FROM video_files"
            ) ?? 0

            let codecCounts = try Row.fetchAll(
                db,
                sql: """
                    SELECT video_codec, COUNT(*) as count
                    FROM video_files
                    GROUP BY video_codec
                    ORDER BY count DESC
                """
            ).reduce(into: [VideoCodec: Int]()) { result, row in
                let codec = VideoCodec(rawValue: row["video_codec"] ?? "unknown") ?? .unknown
                result[codec] = row["count"]
            }

            let hdrCounts = try Row.fetchAll(
                db,
                sql: """
                    SELECT hdr_format, COUNT(*) as count
                    FROM video_files
                    GROUP BY hdr_format
                    ORDER BY count DESC
                """
            ).reduce(into: [HDRFormat: Int]()) { result, row in
                let hdr = HDRFormat(rawValue: row["hdr_format"] ?? "sdr") ?? .sdr
                result[hdr] = row["count"]
            }

            let audioCounts = try Row.fetchAll(
                db,
                sql: """
                    SELECT audio_codec, COUNT(*) as count
                    FROM video_files
                    GROUP BY audio_codec
                    ORDER BY count DESC
                """
            ).reduce(into: [AudioCodec: Int]()) { result, row in
                let codec = AudioCodec(rawValue: row["audio_codec"] ?? "unknown") ?? .unknown
                result[codec] = row["count"]
            }

            let containerCounts = try Row.fetchAll(
                db,
                sql: """
                    SELECT container_format, COUNT(*) as count
                    FROM video_files
                    GROUP BY container_format
                    ORDER BY count DESC
                """
            ).reduce(into: [ContainerFormat: Int]()) { result, row in
                let container = ContainerFormat(rawValue: row["container_format"] ?? "unknown") ?? .unknown
                result[container] = row["count"]
            }

            let resolutionCounts = try Row.fetchAll(
                db,
                sql: """
                    SELECT
                        CASE
                            WHEN height >= 4320 THEN '8K'
                            WHEN height >= 2160 THEN '4K'
                            WHEN height >= 1440 THEN '1440p'
                            WHEN height >= 1080 THEN '1080p'
                            WHEN height >= 720 THEN '720p'
                            WHEN height >= 480 THEN '480p'
                            WHEN height >= 360 THEN '360p'
                            ELSE 'SD'
                        END as resolution_category,
                        COUNT(*) as count
                    FROM video_files
                    WHERE height IS NOT NULL
                    GROUP BY resolution_category
                    ORDER BY
                        CASE resolution_category
                            WHEN '8K' THEN 1
                            WHEN '4K' THEN 2
                            WHEN '1440p' THEN 3
                            WHEN '1080p' THEN 4
                            WHEN '720p' THEN 5
                            WHEN '480p' THEN 6
                            WHEN '360p' THEN 7
                            ELSE 8
                        END
                """
            ).reduce(into: [String: Int]()) { result, row in
                if let category: String = row["resolution_category"] {
                    result[category] = row["count"]
                }
            }

            let atmosCount = try VideoFile
                .filter(VideoFile.Columns.isAtmos == true)
                .fetchCount(db)

            let dtsxCount = try VideoFile
                .filter(VideoFile.Columns.isDTSX == true)
                .fetchCount(db)

            return VideoStatistics(
                totalFiles: totalCount,
                totalSize: totalSize,
                totalDuration: totalDuration,
                codecDistribution: codecCounts,
                hdrDistribution: hdrCounts,
                audioDistribution: audioCounts,
                containerDistribution: containerCounts,
                resolutionDistribution: resolutionCounts,
                atmosCount: atmosCount,
                dtsxCount: dtsxCount
            )
        }
    }

    func fetchDuplicateCandidates() async throws -> [[VideoFile]] {
        try await database.read { db in
            let groups = try Row.fetchAll(
                db,
                sql: """
                    SELECT file_size, duration_seconds, width, height
                    FROM video_files
                    WHERE duration_seconds IS NOT NULL
                    GROUP BY file_size, ROUND(duration_seconds, 0), width, height
                    HAVING COUNT(*) > 1
                """
            )

            var duplicates: [[VideoFile]] = []

            for group in groups {
                guard let size: Int64 = group["file_size"],
                      let duration: Double = group["duration_seconds"],
                      let width: Int = group["width"],
                      let height: Int = group["height"] else { continue }

                let files = try VideoFile
                    .filter(VideoFile.Columns.fileSize == size)
                    .filter(VideoFile.Columns.width == width)
                    .filter(VideoFile.Columns.height == height)
                    .filter(
                        VideoFile.Columns.durationSeconds >= duration - 1 &&
                        VideoFile.Columns.durationSeconds <= duration + 1
                    )
                    .fetchAll(db)

                if files.count > 1 {
                    duplicates.append(files)
                }
            }

            return duplicates
        }
    }
}

enum SortColumn: String, CaseIterable {
    case fileName = "Name"
    case fileSize = "Size"
    case duration = "Duration"
    case resolution = "Resolution"
    case videoCodec = "Video Codec"
    case hdrFormat = "HDR"
    case audioCodec = "Audio"
    case bitRate = "Bitrate"
    case container = "Container"
}

struct VideoStatistics {
    let totalFiles: Int
    let totalSize: Int64
    let totalDuration: Double
    let codecDistribution: [VideoCodec: Int]
    let hdrDistribution: [HDRFormat: Int]
    let audioDistribution: [AudioCodec: Int]
    let containerDistribution: [ContainerFormat: Int]
    let resolutionDistribution: [String: Int]
    let atmosCount: Int
    let dtsxCount: Int

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    var formattedTotalDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    static let empty = VideoStatistics(
        totalFiles: 0,
        totalSize: 0,
        totalDuration: 0,
        codecDistribution: [:],
        hdrDistribution: [:],
        audioDistribution: [:],
        containerDistribution: [:],
        resolutionDistribution: [:],
        atmosCount: 0,
        dtsxCount: 0
    )
}
