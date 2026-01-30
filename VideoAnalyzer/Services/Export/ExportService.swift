import Foundation
import AppKit

actor ExportService {

    func exportCSV(files: [VideoFile], to url: URL) async throws {
        var csv = "File Name,File Path,File Size,Duration,Video Codec,Resolution,Frame Rate,Bit Rate,Bit Depth,HDR Format,Audio Codec,Audio Channels,Atmos,DTS:X,Container\n"

        for file in files {
            let row = [
                escapeCSV(file.fileName),
                escapeCSV(file.filePath),
                String(file.fileSize),
                file.durationSeconds.map { String(format: "%.2f", $0) } ?? "",
                file.videoCodec.displayName,
                file.resolution,
                file.frameRate.map { String(format: "%.2f", $0) } ?? "",
                file.bitRate.map { String($0) } ?? "",
                file.bitDepth.map { String($0) } ?? "",
                file.hdrFormat.displayName,
                file.audioCodec.displayName,
                file.audioChannels.map { String($0) } ?? "",
                file.isAtmos ? "Yes" : "No",
                file.isDTSX ? "Yes" : "No",
                file.containerFormat.displayName
            ].joined(separator: ",")

            csv += row + "\n"
        }

        try csv.write(to: url, atomically: true, encoding: .utf8)
    }

    func exportJSON(files: [VideoFile], statistics: VideoStatistics?, to url: URL) async throws {
        var exportData: [String: Any] = [:]

        exportData["exportedAt"] = ISO8601DateFormatter().string(from: Date())
        exportData["totalFiles"] = files.count

        if let stats = statistics {
            exportData["statistics"] = [
                "totalSize": stats.totalSize,
                "totalDuration": stats.totalDuration,
                "codecDistribution": stats.codecDistribution.mapKeys { $0.displayName },
                "hdrDistribution": stats.hdrDistribution.mapKeys { $0.displayName },
                "audioDistribution": stats.audioDistribution.mapKeys { $0.displayName },
                "containerDistribution": stats.containerDistribution.mapKeys { $0.displayName },
                "resolutionDistribution": stats.resolutionDistribution,
                "atmosCount": stats.atmosCount,
                "dtsxCount": stats.dtsxCount
            ]
        }

        let filesData = files.map { file -> [String: Any] in
            var dict: [String: Any] = [
                "fileName": file.fileName,
                "filePath": file.filePath,
                "fileSize": file.fileSize,
                "videoCodec": file.videoCodec.rawValue,
                "resolution": file.resolution,
                "hdrFormat": file.hdrFormat.rawValue,
                "audioCodec": file.audioCodec.rawValue,
                "isAtmos": file.isAtmos,
                "isDTSX": file.isDTSX,
                "containerFormat": file.containerFormat.rawValue
            ]

            if let duration = file.durationSeconds {
                dict["durationSeconds"] = duration
            }
            if let frameRate = file.frameRate {
                dict["frameRate"] = frameRate
            }
            if let bitRate = file.bitRate {
                dict["bitRate"] = bitRate
            }
            if let bitDepth = file.bitDepth {
                dict["bitDepth"] = bitDepth
            }
            if let channels = file.audioChannels {
                dict["audioChannels"] = channels
            }

            return dict
        }

        exportData["files"] = filesData

        let jsonData = try JSONSerialization.data(
            withJSONObject: exportData,
            options: [.prettyPrinted, .sortedKeys]
        )
        try jsonData.write(to: url)
    }

    func exportPDF(
        files: [VideoFile],
        statistics: VideoStatistics,
        title: String = "Video Library Report"
    ) async throws -> Data {
        let pdfData = NSMutableData()

        var pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let pdfContext = CGContext(consumer: consumer, mediaBox: &pageRect, nil) else {
            throw ExportError.pdfCreationFailed
        }

        drawTitlePage(context: pdfContext, rect: pageRect, title: title, statistics: statistics)

        drawStatisticsPage(context: pdfContext, rect: pageRect, statistics: statistics)

        drawFileListPages(context: pdfContext, rect: pageRect, files: files)

        pdfContext.closePDF()

        return pdfData as Data
    }

    private func drawTitlePage(
        context: CGContext,
        rect: CGRect,
        title: String,
        statistics: VideoStatistics
    ) {
        context.beginPDFPage(nil)

        let titleFont = NSFont.boldSystemFont(ofSize: 28)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor.black
        ]

        let titleString = NSAttributedString(string: title, attributes: titleAttributes)
        let titleSize = titleString.size()
        let titleRect = CGRect(
            x: (rect.width - titleSize.width) / 2,
            y: rect.height - 100,
            width: titleSize.width,
            height: titleSize.height
        )

        let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.current = graphicsContext
        titleString.draw(in: titleRect)

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        let dateString = "Generated: \(dateFormatter.string(from: Date()))"

        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.gray
        ]
        let dateAttrString = NSAttributedString(string: dateString, attributes: dateAttributes)
        let dateSize = dateAttrString.size()
        let dateRect = CGRect(
            x: (rect.width - dateSize.width) / 2,
            y: rect.height - 140,
            width: dateSize.width,
            height: dateSize.height
        )
        dateAttrString.draw(in: dateRect)

        let summaryFont = NSFont.systemFont(ofSize: 14)
        let summaryAttributes: [NSAttributedString.Key: Any] = [
            .font: summaryFont,
            .foregroundColor: NSColor.black
        ]

        let summaryLines = [
            "Total Files: \(statistics.totalFiles)",
            "Total Size: \(statistics.formattedTotalSize)",
            "Total Duration: \(statistics.formattedTotalDuration)",
            "Dolby Atmos Tracks: \(statistics.atmosCount)",
            "DTS:X Tracks: \(statistics.dtsxCount)"
        ]

        var yPosition = rect.height - 220
        for line in summaryLines {
            let attrString = NSAttributedString(string: line, attributes: summaryAttributes)
            let lineRect = CGRect(x: 72, y: yPosition, width: rect.width - 144, height: 20)
            attrString.draw(in: lineRect)
            yPosition -= 25
        }

        context.endPDFPage()
    }

    private func drawStatisticsPage(
        context: CGContext,
        rect: CGRect,
        statistics: VideoStatistics
    ) {
        context.beginPDFPage(nil)

        let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.current = graphicsContext

        let headerFont = NSFont.boldSystemFont(ofSize: 18)
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: NSColor.black
        ]

        let header = NSAttributedString(string: "Statistics Overview", attributes: headerAttributes)
        header.draw(at: CGPoint(x: 72, y: rect.height - 60))

        let sectionFont = NSFont.boldSystemFont(ofSize: 14)
        let itemFont = NSFont.systemFont(ofSize: 11)

        var yPosition = rect.height - 100

        let sections: [(String, [(String, Int)])] = [
            ("Video Codecs", statistics.codecDistribution.map { ($0.key.displayName, $0.value) }.sorted { $0.1 > $1.1 }),
            ("Resolution", statistics.resolutionDistribution.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }),
            ("HDR Formats", statistics.hdrDistribution.map { ($0.key.displayName, $0.value) }.sorted { $0.1 > $1.1 }),
            ("Audio Codecs", statistics.audioDistribution.map { ($0.key.displayName, $0.value) }.sorted { $0.1 > $1.1 }),
            ("Containers", statistics.containerDistribution.map { ($0.key.displayName, $0.value) }.sorted { $0.1 > $1.1 })
        ]

        for (sectionTitle, items) in sections {
            if yPosition < 100 {
                context.endPDFPage()
                context.beginPDFPage(nil)
                NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
                yPosition = rect.height - 60
            }

            let sectionAttr = NSAttributedString(
                string: sectionTitle,
                attributes: [.font: sectionFont, .foregroundColor: NSColor.black]
            )
            sectionAttr.draw(at: CGPoint(x: 72, y: yPosition))
            yPosition -= 20

            for (name, count) in items.prefix(5) {
                let percentage = Double(count) / Double(max(statistics.totalFiles, 1)) * 100
                let itemText = String(format: "  %@: %d (%.1f%%)", name, count, percentage)
                let itemAttr = NSAttributedString(
                    string: itemText,
                    attributes: [.font: itemFont, .foregroundColor: NSColor.darkGray]
                )
                itemAttr.draw(at: CGPoint(x: 72, y: yPosition))
                yPosition -= 16
            }

            yPosition -= 15
        }

        context.endPDFPage()
    }

    private func drawFileListPages(context: CGContext, rect: CGRect, files: [VideoFile]) {
        let headerFont = NSFont.boldSystemFont(ofSize: 10)
        let itemFont = NSFont.systemFont(ofSize: 9)
        let rowHeight: CGFloat = 14
        let startY = rect.height - 60
        let filesPerPage = Int((startY - 60) / rowHeight)

        let chunks = stride(from: 0, to: files.count, by: filesPerPage).map {
            Array(files[$0..<min($0 + filesPerPage, files.count)])
        }

        for (pageIndex, chunk) in chunks.enumerated() {
            context.beginPDFPage(nil)
            let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.current = graphicsContext

            let pageTitle = NSAttributedString(
                string: "File List (Page \(pageIndex + 1) of \(chunks.count))",
                attributes: [.font: NSFont.boldSystemFont(ofSize: 14), .foregroundColor: NSColor.black]
            )
            pageTitle.draw(at: CGPoint(x: 72, y: rect.height - 40))

            let columns: [(String, CGFloat)] = [
                ("Name", 200),
                ("Size", 60),
                ("Duration", 60),
                ("Codec", 50),
                ("Resolution", 60),
                ("HDR", 50)
            ]

            var xPosition: CGFloat = 72
            for (title, width) in columns {
                let headerAttr = NSAttributedString(
                    string: title,
                    attributes: [.font: headerFont, .foregroundColor: NSColor.black]
                )
                headerAttr.draw(at: CGPoint(x: xPosition, y: startY))
                xPosition += width
            }

            var yPosition = startY - rowHeight - 5

            for file in chunk {
                xPosition = 72

                let values: [(String, CGFloat)] = [
                    (String(file.fileName.prefix(30)), 200),
                    (file.formattedFileSize, 60),
                    (file.formattedDuration, 60),
                    (file.videoCodec.displayName, 50),
                    (file.resolutionCategory, 60),
                    (file.hdrFormat.displayName, 50)
                ]

                for (value, width) in values {
                    let valueAttr = NSAttributedString(
                        string: value,
                        attributes: [.font: itemFont, .foregroundColor: NSColor.darkGray]
                    )
                    valueAttr.draw(at: CGPoint(x: xPosition, y: yPosition))
                    xPosition += width
                }

                yPosition -= rowHeight
            }

            context.endPDFPage()
        }
    }

    private func escapeCSV(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            return "\"\(string.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return string
    }
}

enum ExportError: Error, LocalizedError {
    case pdfCreationFailed
    case writeError(Error)

    var errorDescription: String? {
        switch self {
        case .pdfCreationFailed:
            return "Failed to create PDF document"
        case .writeError(let error):
            return "Failed to write file: \(error.localizedDescription)"
        }
    }
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case csv = "CSV"
    case json = "JSON"
    case pdf = "PDF Report"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .json: return "json"
        case .pdf: return "pdf"
        }
    }

    var utType: String {
        switch self {
        case .csv: return "public.comma-separated-values-text"
        case .json: return "public.json"
        case .pdf: return "com.adobe.pdf"
        }
    }
}

extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        Dictionary<T, Value>(uniqueKeysWithValues: map { (transform($0.key), $0.value) })
    }
}
