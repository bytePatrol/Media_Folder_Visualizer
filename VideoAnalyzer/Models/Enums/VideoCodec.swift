import Foundation

enum VideoCodec: String, Codable, CaseIterable, Identifiable {
    case h264 = "h264"
    case h265 = "hevc"
    case vp9 = "vp9"
    case av1 = "av1"
    case prores = "prores"
    case dnxhd = "dnxhd"
    case mpeg2 = "mpeg2video"
    case mpeg4 = "mpeg4"
    case vp8 = "vp8"
    case wmv3 = "wmv3"
    case vc1 = "vc1"
    case mjpeg = "mjpeg"
    case unknown = "unknown"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .h264: return "H.264 / AVC"
        case .h265: return "H.265 / HEVC"
        case .vp9: return "VP9"
        case .av1: return "AV1"
        case .prores: return "ProRes"
        case .dnxhd: return "DNxHD"
        case .mpeg2: return "MPEG-2"
        case .mpeg4: return "MPEG-4"
        case .vp8: return "VP8"
        case .wmv3: return "WMV"
        case .vc1: return "VC-1"
        case .mjpeg: return "Motion JPEG"
        case .unknown: return "Unknown"
        }
    }

    static func from(_ codecName: String?) -> VideoCodec {
        guard let name = codecName?.lowercased() else { return .unknown }

        if name.contains("h264") || name.contains("avc") {
            return .h264
        } else if name.contains("hevc") || name.contains("h265") {
            return .h265
        } else if name.contains("vp9") {
            return .vp9
        } else if name.contains("av1") || name.contains("av01") {
            return .av1
        } else if name.contains("prores") {
            return .prores
        } else if name.contains("dnxh") {
            return .dnxhd
        } else if name.contains("mpeg2") {
            return .mpeg2
        } else if name.contains("mpeg4") || name == "mp4v" {
            return .mpeg4
        } else if name.contains("vp8") {
            return .vp8
        } else if name.contains("wmv") {
            return .wmv3
        } else if name.contains("vc1") || name.contains("vc-1") {
            return .vc1
        } else if name.contains("mjpeg") || name.contains("mjpg") {
            return .mjpeg
        }

        return allCases.first { $0.rawValue == name } ?? .unknown
    }
}
