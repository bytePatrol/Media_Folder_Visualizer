import Foundation

/// HDR format detected from video stream metadata.
///
/// Detection is based on ffprobe output:
/// - `color_transfer`: Transfer function (PQ, HLG, etc.)
/// - `color_primaries`: Color space (BT.2020, etc.)
/// - `side_data_list`: Contains Dolby Vision and HDR10+ metadata
///
/// Priority order (highest first):
/// 1. Dolby Vision (with or without HDR10 fallback layer)
/// 2. HDR10+ (Samsung dynamic metadata)
/// 3. HLG (broadcast HDR)
/// 4. HDR10 (static metadata, PQ + BT.2020)
/// 5. SDR (default)
enum HDRFormat: String, Codable, CaseIterable, Identifiable {
    case sdr = "sdr"
    case hdr10 = "hdr10"
    case hdr10Plus = "hdr10plus"
    case dolbyVision = "dolby_vision"
    case hlg = "hlg"
    /// Dolby Vision with HDR10 compatibility layer (common in streaming)
    case dolbyVisionHDR10 = "dolby_vision_hdr10"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sdr: return "SDR"
        case .hdr10: return "HDR10"
        case .hdr10Plus: return "HDR10+"
        case .dolbyVision: return "Dolby Vision"
        case .hlg: return "HLG"
        case .dolbyVisionHDR10: return "Dolby Vision + HDR10"
        }
    }

    var isHDR: Bool {
        self != .sdr
    }

    /// Detects HDR format from ffprobe stream metadata.
    ///
    /// Algorithm:
    /// 1. Check side_data_list for Dolby Vision RPU (enhancement layer)
    /// 2. Check side_data_list for HDR10+ dynamic metadata
    /// 3. Check color_transfer for HLG (ARIB-STD-B67)
    /// 4. Check color_transfer for PQ (SMPTE 2084) + BT.2020 primaries
    /// 5. Fall back to SDR
    ///
    /// Special case: Dolby Vision + HDR10
    /// Many streaming files have DV with an HDR10 fallback layer.
    /// We detect this when DV side data exists AND color_transfer is PQ.
    ///
    /// - Note: Bit depth alone is not sufficient for HDR detection.
    ///   10-bit SDR exists (e.g., ProRes 4444).
    static func detect(
        colorTransfer: String?,
        colorPrimaries: String?,
        sideDataList: [[String: Any]]?,
        bitDepth: Int?
    ) -> HDRFormat {
        let transfer = colorTransfer?.lowercased() ?? ""
        let primaries = colorPrimaries?.lowercased() ?? ""

        var hasDolbyVision = false
        var hasHDR10Plus = false

        // Check side_data_list for enhancement layer metadata
        // This is the most reliable indicator for DV and HDR10+
        if let sideData = sideDataList {
            for data in sideData {
                if let type = data["side_data_type"] as? String {
                    // Dolby Vision uses RPU (reference processing unit) data
                    if type.lowercased().contains("dolby vision") ||
                       type.lowercased().contains("dovi") {
                        hasDolbyVision = true
                    }
                    // HDR10+ uses Samsung's dynamic metadata format
                    if type.lowercased().contains("hdr10+") ||
                       type.lowercased().contains("hdr dynamic metadata") {
                        hasHDR10Plus = true
                    }
                }
            }
        }

        // Priority 1: Dolby Vision (may have HDR10 fallback)
        if hasDolbyVision {
            // Profile 8.4 (common in streaming) includes HDR10 compatibility
            let hasHDR10Base = transfer.contains("smpte2084") || transfer.contains("pq")
            return hasHDR10Base ? .dolbyVisionHDR10 : .dolbyVision
        }

        // Priority 2: HDR10+ (Samsung dynamic metadata)
        if hasHDR10Plus {
            return .hdr10Plus
        }

        // Priority 3: HLG (Hybrid Log-Gamma, used in broadcast)
        // Uses ARIB STD-B67 transfer function
        if transfer.contains("arib-std-b67") || transfer.contains("hlg") {
            return .hlg
        }

        // Priority 4: HDR10 (static metadata)
        // Requires PQ transfer + BT.2020 color primaries
        if transfer.contains("smpte2084") || transfer.contains("pq") {
            if primaries.contains("bt2020") || primaries.contains("2020") {
                return .hdr10
            }
        }

        // Additional HDR10 check with bit depth
        // Some files may have incomplete metadata
        if let depth = bitDepth, depth >= 10 {
            if primaries.contains("bt2020") || primaries.contains("2020") {
                if transfer.contains("smpte2084") || transfer.contains("pq") {
                    return .hdr10
                }
            }
        }

        return .sdr
    }
}
