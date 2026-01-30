import Foundation

enum AudioCodec: String, Codable, CaseIterable, Identifiable {
    case aac = "aac"
    case ac3 = "ac3"
    case eac3 = "eac3"
    case truehd = "truehd"
    case dts = "dts"
    case dtshd = "dts-hd"
    case flac = "flac"
    case opus = "opus"
    case vorbis = "vorbis"
    case mp3 = "mp3"
    case pcm = "pcm"
    case alac = "alac"
    case wma = "wma"
    case unknown = "unknown"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .aac: return "AAC"
        case .ac3: return "Dolby Digital (AC-3)"
        case .eac3: return "Dolby Digital Plus (E-AC-3)"
        case .truehd: return "Dolby TrueHD"
        case .dts: return "DTS"
        case .dtshd: return "DTS-HD"
        case .flac: return "FLAC"
        case .opus: return "Opus"
        case .vorbis: return "Vorbis"
        case .mp3: return "MP3"
        case .pcm: return "PCM"
        case .alac: return "ALAC"
        case .wma: return "WMA"
        case .unknown: return "Unknown"
        }
    }

    static func from(_ codecName: String?) -> AudioCodec {
        guard let name = codecName?.lowercased() else { return .unknown }

        if name.contains("aac") {
            return .aac
        } else if name.contains("eac3") || name.contains("e-ac-3") || name.contains("ec-3") {
            return .eac3
        } else if name.contains("ac3") || name.contains("ac-3") {
            return .ac3
        } else if name.contains("truehd") || name.contains("mlp") {
            return .truehd
        } else if name.contains("dts-hd") || name.contains("dtshd") {
            return .dtshd
        } else if name.contains("dts") {
            return .dts
        } else if name.contains("flac") {
            return .flac
        } else if name.contains("opus") {
            return .opus
        } else if name.contains("vorbis") {
            return .vorbis
        } else if name.contains("mp3") || name.contains("mp2") {
            return .mp3
        } else if name.contains("pcm") || name.contains("s16") || name.contains("s24") || name.contains("s32") {
            return .pcm
        } else if name.contains("alac") {
            return .alac
        } else if name.contains("wma") {
            return .wma
        }

        return .unknown
    }
}

struct AudioTrackInfo: Codable, Equatable {
    let codec: AudioCodec
    let channels: Int
    let sampleRate: Int?
    let bitRate: Int?
    let isAtmos: Bool
    let isDTSX: Bool
    let language: String?
    let title: String?

    var channelDescription: String {
        switch channels {
        case 1: return "Mono"
        case 2: return "Stereo"
        case 6: return "5.1"
        case 8: return "7.1"
        default: return "\(channels) channels"
        }
    }

    var fullDescription: String {
        var parts: [String] = [codec.displayName]
        parts.append(channelDescription)

        if isAtmos {
            parts.append("Atmos")
        }
        if isDTSX {
            parts.append("DTS:X")
        }

        return parts.joined(separator: " ")
    }
}
