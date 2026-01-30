import Foundation

/// Parses ffprobe JSON output into structured VideoMetadata.
///
/// Key responsibilities:
/// - Extracts video/audio stream properties
/// - Detects HDR format from color metadata and side data
/// - Identifies Dolby Atmos and DTS:X immersive audio tracks
/// - Maps codec strings to typed enums
struct MetadataParser {

    /// Parses ffprobe output into VideoMetadata.
    ///
    /// - Note: Uses first video stream found (ignores cover art streams).
    ///   Collects all audio streams for Atmos/DTS:X detection.
    func parse(output: FFProbeOutput, filePath: String, fileSize: Int64) -> VideoMetadata {
        let videoStream = output.streams?.first { $0.isVideo }
        let audioStreams = output.streams?.filter { $0.isAudio } ?? []

        let videoCodec = VideoCodec.from(videoStream?.codecName)

        let width = videoStream?.width ?? videoStream?.codedWidth
        let height = videoStream?.height ?? videoStream?.codedHeight

        let frameRate = videoStream?.parsedFrameRate

        let bitRate: Int?
        if let streamBitRate = videoStream?.bitRate, let br = Int(streamBitRate) {
            bitRate = br
        } else if let formatBitRate = output.format?.bitRate, let br = Int(formatBitRate) {
            bitRate = br
        } else {
            bitRate = nil
        }

        let bitDepth = videoStream?.parsedBitDepth

        let sideDataList: [[String: Any]]? = videoStream?.sideDataList?.compactMap { sideData in
            var dict: [String: Any] = [:]
            if let type = sideData.sideDataType {
                dict["side_data_type"] = type
            }
            return dict.isEmpty ? nil : dict
        }

        let hdrFormat = HDRFormat.detect(
            colorTransfer: videoStream?.colorTransfer,
            colorPrimaries: videoStream?.colorPrimaries,
            sideDataList: sideDataList,
            bitDepth: bitDepth
        )

        let audioTracks = audioStreams.map { parseAudioTrack($0) }

        let containerFormat: ContainerFormat
        if let formatName = output.format?.formatName {
            containerFormat = ContainerFormat.from(formatName)
        } else {
            let ext = (filePath as NSString).pathExtension
            containerFormat = ContainerFormat.fromExtension(ext)
        }

        let duration: Double?
        if let durStr = output.format?.duration, let dur = Double(durStr) {
            duration = dur
        } else {
            duration = nil
        }

        return VideoMetadata(
            filePath: filePath,
            fileSize: fileSize,
            duration: duration,
            videoCodec: videoCodec,
            width: width,
            height: height,
            frameRate: frameRate,
            bitRate: bitRate,
            bitDepth: bitDepth,
            hdrFormat: hdrFormat,
            audioTracks: audioTracks,
            containerFormat: containerFormat
        )
    }

    private func parseAudioTrack(_ stream: FFProbeOutput.FFProbeStream) -> AudioTrackInfo {
        let codec = AudioCodec.from(stream.codecName)
        let channels = stream.channels ?? detectChannelsFromLayout(stream.channelLayout)

        let sampleRate: Int?
        if let sr = stream.sampleRate {
            sampleRate = Int(sr)
        } else {
            sampleRate = nil
        }

        let bitRate: Int?
        if let br = stream.bitRate {
            bitRate = Int(br)
        } else {
            bitRate = nil
        }

        let isAtmos = detectAtmos(stream: stream, codec: codec, channels: channels)
        let isDTSX = detectDTSX(stream: stream, codec: codec)

        let language = stream.tags?["language"]
        let title = stream.tags?["title"]

        return AudioTrackInfo(
            codec: codec,
            channels: channels,
            sampleRate: sampleRate,
            bitRate: bitRate,
            isAtmos: isAtmos,
            isDTSX: isDTSX,
            language: language,
            title: title
        )
    }

    private func detectChannelsFromLayout(_ layout: String?) -> Int {
        guard let layout = layout?.lowercased() else { return 2 }

        if layout.contains("7.1") || layout.contains("octagonal") {
            return 8
        } else if layout.contains("5.1") || layout.contains("hexagonal") {
            return 6
        } else if layout.contains("stereo") {
            return 2
        } else if layout.contains("mono") {
            return 1
        } else if layout.contains("quad") {
            return 4
        }

        return 2
    }

    /// Detects Dolby Atmos from audio stream metadata.
    ///
    /// Detection strategy (in order of reliability):
    /// 1. Profile string contains "atmos"
    /// 2. Codec long name contains "atmos"
    /// 3. Side data indicates Dolby/Atmos metadata
    /// 4. Track title contains "atmos"
    /// 5. **Heuristic**: TrueHD with 8+ channels is likely Atmos
    ///
    /// - Note: Atmos is only possible with TrueHD or E-AC3 codecs.
    ///   The 8-channel TrueHD heuristic catches files where ffprobe
    ///   doesn't report the Atmos flag directly.
    private func detectAtmos(
        stream: FFProbeOutput.FFProbeStream,
        codec: AudioCodec,
        channels: Int
    ) -> Bool {
        // Atmos only exists in TrueHD (Blu-ray) or E-AC3 (streaming)
        if codec == .truehd || codec == .eac3 {
            if let profile = stream.profile?.lowercased() {
                if profile.contains("atmos") {
                    return true
                }
            }

            if let codecLong = stream.codecLongName?.lowercased() {
                if codecLong.contains("atmos") {
                    return true
                }
            }

            if let sideData = stream.sideDataList {
                for data in sideData {
                    if let type = data.sideDataType?.lowercased() {
                        if type.contains("atmos") || type.contains("dolby") {
                            return true
                        }
                    }
                }
            }

            if let title = stream.tags?["title"]?.lowercased() {
                if title.contains("atmos") {
                    return true
                }
            }

            if codec == .truehd && channels >= 8 {
                return true
            }
        }

        return false
    }

    /// Detects DTS:X from audio stream metadata.
    ///
    /// Detection strategy:
    /// 1. Profile contains "dts:x", "dts-x", or "dtsx"
    /// 2. Codec long name contains DTS:X identifier
    /// 3. Track title contains DTS:X identifier
    ///
    /// - Note: Unlike Atmos, there's no reliable heuristic for DTS:X.
    ///   We must rely on explicit metadata from ffprobe.
    private func detectDTSX(stream: FFProbeOutput.FFProbeStream, codec: AudioCodec) -> Bool {
        // DTS:X only exists in DTS or DTS-HD streams
        guard codec == .dts || codec == .dtshd else { return false }

        if let profile = stream.profile?.lowercased() {
            if profile.contains("dts:x") || profile.contains("dts-x") || profile.contains("dtsx") {
                return true
            }
            if profile.contains("dts-hd ma") && profile.contains("x") {
                return true
            }
        }

        if let codecLong = stream.codecLongName?.lowercased() {
            if codecLong.contains("dts:x") || codecLong.contains("dts-x") {
                return true
            }
        }

        if let title = stream.tags?["title"]?.lowercased() {
            if title.contains("dts:x") || title.contains("dts-x") || title.contains("dtsx") {
                return true
            }
        }

        return false
    }
}
