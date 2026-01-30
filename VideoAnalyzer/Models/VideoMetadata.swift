import Foundation

struct VideoMetadata {
    let filePath: String
    let fileSize: Int64
    let duration: Double?
    let videoCodec: VideoCodec
    let width: Int?
    let height: Int?
    let frameRate: Double?
    let bitRate: Int?
    let bitDepth: Int?
    let hdrFormat: HDRFormat
    let audioTracks: [AudioTrackInfo]
    let containerFormat: ContainerFormat

    var primaryAudioTrack: AudioTrackInfo? {
        audioTracks.first
    }

    func toVideoFile(sessionId: Int64?) -> VideoFile {
        let primaryAudio = primaryAudioTrack

        return VideoFile(
            id: nil,
            filePath: filePath,
            fileName: (filePath as NSString).lastPathComponent,
            fileSize: fileSize,
            durationSeconds: duration,
            videoCodec: videoCodec,
            width: width,
            height: height,
            frameRate: frameRate,
            bitRate: bitRate,
            bitDepth: bitDepth,
            hdrFormat: hdrFormat,
            audioCodec: primaryAudio?.codec ?? .unknown,
            audioChannels: primaryAudio?.channels,
            isAtmos: primaryAudio?.isAtmos ?? false,
            isDTSX: primaryAudio?.isDTSX ?? false,
            containerFormat: containerFormat,
            scanSessionId: sessionId,
            scannedAt: Date()
        )
    }
}

struct FFProbeOutput: Codable {
    let format: FFProbeFormat?
    let streams: [FFProbeStream]?

    struct FFProbeFormat: Codable {
        let filename: String?
        let formatName: String?
        let formatLongName: String?
        let duration: String?
        let size: String?
        let bitRate: String?
        let tags: [String: String]?

        enum CodingKeys: String, CodingKey {
            case filename
            case formatName = "format_name"
            case formatLongName = "format_long_name"
            case duration
            case size
            case bitRate = "bit_rate"
            case tags
        }
    }

    struct FFProbeStream: Codable {
        let index: Int?
        let codecType: String?
        let codecName: String?
        let codecLongName: String?
        let profile: String?
        let width: Int?
        let height: Int?
        let codedWidth: Int?
        let codedHeight: Int?
        let pixFmt: String?
        let colorRange: String?
        let colorSpace: String?
        let colorTransfer: String?
        let colorPrimaries: String?
        let bitsPerRawSample: String?
        let rFrameRate: String?
        let avgFrameRate: String?
        let bitRate: String?
        let channels: Int?
        let channelLayout: String?
        let sampleRate: String?
        let sideDataList: [SideData]?
        let tags: [String: String]?
        let disposition: [String: Int]?

        enum CodingKeys: String, CodingKey {
            case index
            case codecType = "codec_type"
            case codecName = "codec_name"
            case codecLongName = "codec_long_name"
            case profile
            case width, height
            case codedWidth = "coded_width"
            case codedHeight = "coded_height"
            case pixFmt = "pix_fmt"
            case colorRange = "color_range"
            case colorSpace = "color_space"
            case colorTransfer = "color_transfer"
            case colorPrimaries = "color_primaries"
            case bitsPerRawSample = "bits_per_raw_sample"
            case rFrameRate = "r_frame_rate"
            case avgFrameRate = "avg_frame_rate"
            case bitRate = "bit_rate"
            case channels
            case channelLayout = "channel_layout"
            case sampleRate = "sample_rate"
            case sideDataList = "side_data_list"
            case tags
            case disposition
        }

        var isVideo: Bool {
            codecType?.lowercased() == "video"
        }

        var isAudio: Bool {
            codecType?.lowercased() == "audio"
        }

        var parsedFrameRate: Double? {
            guard let rateStr = avgFrameRate ?? rFrameRate else { return nil }
            let parts = rateStr.split(separator: "/")
            guard parts.count == 2,
                  let num = Double(parts[0]),
                  let den = Double(parts[1]),
                  den > 0 else {
                return Double(rateStr)
            }
            return num / den
        }

        var parsedBitDepth: Int? {
            if let bits = bitsPerRawSample, let value = Int(bits) {
                return value
            }

            if let pix = pixFmt?.lowercased() {
                if pix.contains("10le") || pix.contains("10be") || pix.contains("p010") {
                    return 10
                }
                if pix.contains("12le") || pix.contains("12be") {
                    return 12
                }
            }

            return nil
        }
    }

    struct SideData: Codable {
        let sideDataType: String?

        enum CodingKeys: String, CodingKey {
            case sideDataType = "side_data_type"
        }
    }
}
