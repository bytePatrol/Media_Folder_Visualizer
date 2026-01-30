import Foundation

enum ContainerFormat: String, Codable, CaseIterable, Identifiable {
    case mkv = "mkv"
    case mp4 = "mp4"
    case mov = "mov"
    case avi = "avi"
    case wmv = "wmv"
    case webm = "webm"
    case flv = "flv"
    case m4v = "m4v"
    case ts = "ts"
    case mts = "mts"
    case m2ts = "m2ts"
    case vob = "vob"
    case mpg = "mpg"
    case unknown = "unknown"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mkv: return "Matroska (MKV)"
        case .mp4: return "MP4"
        case .mov: return "QuickTime (MOV)"
        case .avi: return "AVI"
        case .wmv: return "WMV"
        case .webm: return "WebM"
        case .flv: return "Flash Video"
        case .m4v: return "M4V"
        case .ts: return "MPEG-TS"
        case .mts: return "MTS"
        case .m2ts: return "M2TS (Blu-ray)"
        case .vob: return "VOB (DVD)"
        case .mpg: return "MPEG"
        case .unknown: return "Unknown"
        }
    }

    static let supportedExtensions: Set<String> = [
        "mkv", "mp4", "mov", "avi", "wmv", "webm", "flv", "m4v",
        "ts", "mts", "m2ts", "vob", "mpg", "mpeg", "m2v", "3gp",
        "ogv", "divx", "rm", "rmvb", "asf"
    ]

    static func from(_ formatName: String?) -> ContainerFormat {
        guard let name = formatName?.lowercased() else { return .unknown }

        if name.contains("matroska") || name.contains("mkv") {
            return .mkv
        } else if name.contains("mp4") || name.contains("m4a") {
            return .mp4
        } else if name.contains("quicktime") || name.contains("mov") {
            return .mov
        } else if name.contains("avi") {
            return .avi
        } else if name.contains("wmv") || name.contains("asf") {
            return .wmv
        } else if name.contains("webm") {
            return .webm
        } else if name.contains("flv") {
            return .flv
        } else if name.contains("m4v") {
            return .m4v
        } else if name.contains("mpegts") || name == "ts" {
            return .ts
        } else if name.contains("m2ts") || name.contains("bdav") {
            return .m2ts
        } else if name.contains("mts") {
            return .mts
        } else if name.contains("vob") || name.contains("dvd") {
            return .vob
        } else if name.contains("mpeg") || name.contains("mpg") {
            return .mpg
        }

        return allCases.first { $0.rawValue == name } ?? .unknown
    }

    static func fromExtension(_ ext: String) -> ContainerFormat {
        switch ext.lowercased() {
        case "mkv": return .mkv
        case "mp4": return .mp4
        case "mov": return .mov
        case "avi": return .avi
        case "wmv": return .wmv
        case "webm": return .webm
        case "flv": return .flv
        case "m4v": return .m4v
        case "ts": return .ts
        case "mts": return .mts
        case "m2ts": return .m2ts
        case "vob": return .vob
        case "mpg", "mpeg", "m2v": return .mpg
        default: return .unknown
        }
    }
}
