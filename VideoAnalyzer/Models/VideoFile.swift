import Foundation
import GRDB

/// Core data model for scanned video files.
///
/// Stored in SQLite via GRDB. All codec/format enums are stored as
/// string raw values for database compatibility and human readability.
///
/// Display formatting:
/// - `resolution`: Simplified label ("1080p", "4K", not "1920x1080")
/// - `formattedDuration`: "H:MM:SS" format (no leading zero on hours)
/// - `formattedBitRate`: Human-readable with units (Kbps, Mbps, Gbps)
/// - `audioDescription`: Combined codec + channels + Atmos/DTS:X
struct VideoFile: Identifiable, Equatable, Hashable {
    var id: Int64?
    let filePath: String
    let fileName: String
    let fileSize: Int64
    let durationSeconds: Double?
    let videoCodec: VideoCodec
    let width: Int?
    let height: Int?
    let frameRate: Double?
    let bitRate: Int?
    let bitDepth: Int?
    let hdrFormat: HDRFormat
    let audioCodec: AudioCodec
    let audioChannels: Int?
    let isAtmos: Bool
    let isDTSX: Bool
    let containerFormat: ContainerFormat
    let scanSessionId: Int64?
    let scannedAt: Date

    /// User-friendly resolution label based on vertical height.
    ///
    /// Thresholds match industry standards:
    /// - 8K: 4320p and above (7680x4320)
    /// - 4K: 2160p and above (3840x2160, 4096x2160)
    /// - 1440p: 1440p and above (2560x1440)
    /// - 1080p: 1080p and above (1920x1080)
    /// - 720p: 720p and above (1280x720)
    /// - 480p: 480p and above (720x480, 854x480)
    /// - 360p: 360p and above (640x360)
    /// - SD: Below 360p
    ///
    /// Uses height only since width varies (16:9, 21:9, 4:3, etc.)
    var resolution: String {
        guard let h = height else { return "Unknown" }

        if h >= 4320 {
            return "8K"
        } else if h >= 2160 {
            return "4K"
        } else if h >= 1440 {
            return "1440p"
        } else if h >= 1080 {
            return "1080p"
        } else if h >= 720 {
            return "720p"
        } else if h >= 480 {
            return "480p"
        } else if h >= 360 {
            return "360p"
        } else {
            return "SD"
        }
    }

    var fullResolution: String {
        guard let w = width, let h = height else { return "Unknown" }
        return "\(w)x\(h)"
    }

    var resolutionCategory: String {
        resolution
    }

    var formattedDuration: String {
        guard let duration = durationSeconds else { return "-:--:--" }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }

    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    /// Human-readable bitrate with automatic unit selection.
    ///
    /// Units (decimal, not binary):
    /// - Gbps: >= 1,000,000,000 bps (rare, very high bitrate)
    /// - Mbps: >= 1,000,000 bps (typical for video)
    /// - Kbps: < 1,000,000 bps (low bitrate or audio-only)
    ///
    /// - Note: ffprobe reports bitrate in bits per second (bps).
    var formattedBitRate: String {
        guard let br = bitRate else { return "N/A" }
        if br >= 1_000_000_000 {
            return String(format: "%.2f Gbps", Double(br) / 1_000_000_000)
        } else if br >= 1_000_000 {
            return String(format: "%.1f Mbps", Double(br) / 1_000_000)
        } else {
            return String(format: "%d Kbps", br / 1000)
        }
    }

    var formattedFrameRate: String {
        guard let fps = frameRate else { return "N/A" }
        if fps.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(fps)) fps"
        } else {
            return String(format: "%.2f fps", fps)
        }
    }

    var audioDescription: String {
        var parts = [audioCodec.displayName]
        if let channels = audioChannels {
            switch channels {
            case 1: parts.append("Mono")
            case 2: parts.append("Stereo")
            case 6: parts.append("5.1")
            case 8: parts.append("7.1")
            default: parts.append("\(channels)ch")
            }
        }
        if isAtmos { parts.append("Atmos") }
        if isDTSX { parts.append("DTS:X") }
        return parts.joined(separator: " ")
    }
}

extension VideoFile: FetchableRecord, PersistableRecord {
    static let databaseTableName = "video_files"

    enum Columns: String, ColumnExpression {
        case id, filePath = "file_path", fileName = "file_name", fileSize = "file_size"
        case durationSeconds = "duration_seconds", videoCodec = "video_codec"
        case width, height, frameRate = "frame_rate", bitRate = "bit_rate"
        case bitDepth = "bit_depth", hdrFormat = "hdr_format"
        case audioCodec = "audio_codec", audioChannels = "audio_channels"
        case isAtmos = "is_atmos", isDTSX = "is_dtsx"
        case containerFormat = "container_format"
        case scanSessionId = "scan_session_id", scannedAt = "scanned_at"
    }

    init(row: Row) throws {
        id = row[Columns.id]
        filePath = row[Columns.filePath]
        fileName = row[Columns.fileName]
        fileSize = row[Columns.fileSize]
        durationSeconds = row[Columns.durationSeconds]
        videoCodec = VideoCodec(rawValue: row[Columns.videoCodec] ?? "unknown") ?? .unknown
        width = row[Columns.width]
        height = row[Columns.height]
        frameRate = row[Columns.frameRate]
        bitRate = row[Columns.bitRate]
        bitDepth = row[Columns.bitDepth]
        hdrFormat = HDRFormat(rawValue: row[Columns.hdrFormat] ?? "sdr") ?? .sdr
        audioCodec = AudioCodec(rawValue: row[Columns.audioCodec] ?? "unknown") ?? .unknown
        audioChannels = row[Columns.audioChannels]
        isAtmos = row[Columns.isAtmos] ?? false
        isDTSX = row[Columns.isDTSX] ?? false
        containerFormat = ContainerFormat(rawValue: row[Columns.containerFormat] ?? "unknown") ?? .unknown
        scanSessionId = row[Columns.scanSessionId]
        scannedAt = row[Columns.scannedAt] ?? Date()
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
        container[Columns.filePath] = filePath
        container[Columns.fileName] = fileName
        container[Columns.fileSize] = fileSize
        container[Columns.durationSeconds] = durationSeconds
        container[Columns.videoCodec] = videoCodec.rawValue
        container[Columns.width] = width
        container[Columns.height] = height
        container[Columns.frameRate] = frameRate
        container[Columns.bitRate] = bitRate
        container[Columns.bitDepth] = bitDepth
        container[Columns.hdrFormat] = hdrFormat.rawValue
        container[Columns.audioCodec] = audioCodec.rawValue
        container[Columns.audioChannels] = audioChannels
        container[Columns.isAtmos] = isAtmos
        container[Columns.isDTSX] = isDTSX
        container[Columns.containerFormat] = containerFormat.rawValue
        container[Columns.scanSessionId] = scanSessionId
        container[Columns.scannedAt] = scannedAt
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
