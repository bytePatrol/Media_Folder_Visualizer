import AppKit
import SwiftUI

class FileTableViewController: NSViewController {
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var files: [VideoFile] = []
    private var sortDescriptors: [NSSortDescriptor] = []

    var onSelectionChanged: (([VideoFile]) -> Void)?
    var onDoubleClick: ((VideoFile) -> Void)?

    override func loadView() {
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true

        tableView = NSTableView()
        tableView.style = .inset
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = true
        tableView.allowsColumnReordering = true
        tableView.allowsColumnResizing = true
        tableView.allowsColumnSelection = false
        tableView.rowHeight = 44
        tableView.intercellSpacing = NSSize(width: 8, height: 4)

        setupColumns()

        tableView.dataSource = self
        tableView.delegate = self
        tableView.doubleAction = #selector(tableViewDoubleClick)
        tableView.target = self

        scrollView.documentView = tableView
        self.view = scrollView
    }

    private func setupColumns() {
        let columns: [(String, String, CGFloat, CGFloat?)] = [
            ("name", "Name", 250, nil),
            ("size", "Size", 80, 80),
            ("duration", "Duration", 80, 80),
            ("resolution", "Resolution", 100, 100),
            ("videoCodec", "Video", 100, 100),
            ("audio", "Audio", 150, nil),
            ("bitrate", "Bitrate", 80, 80),
            ("container", "Container", 80, 80)
        ]

        for (identifier, title, width, maxWidth) in columns {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
            column.title = title
            column.width = width
            if let max = maxWidth {
                column.maxWidth = max
            }
            column.sortDescriptorPrototype = NSSortDescriptor(key: identifier, ascending: true)
            tableView.addTableColumn(column)
        }
    }

    func updateFiles(_ newFiles: [VideoFile]) {
        files = newFiles
        tableView.reloadData()
    }

    func updateSort(_ descriptors: [NSSortDescriptor]) {
        sortDescriptors = descriptors
        tableView.sortDescriptors = descriptors
    }

    @objc private func tableViewDoubleClick() {
        let row = tableView.clickedRow
        guard row >= 0 && row < files.count else { return }
        onDoubleClick?(files[row])
    }
}

extension FileTableViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        files.count
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        sortDescriptors = tableView.sortDescriptors

        files.sort { file1, file2 in
            for descriptor in sortDescriptors {
                let comparison: ComparisonResult
                switch descriptor.key {
                case "name":
                    comparison = file1.fileName.localizedCompare(file2.fileName)
                case "size":
                    comparison = compareOptional(file1.fileSize, file2.fileSize)
                case "duration":
                    comparison = compareOptional(file1.durationSeconds, file2.durationSeconds)
                case "resolution":
                    comparison = compareOptional(file1.height, file2.height)
                case "videoCodec":
                    comparison = file1.videoCodec.displayName.compare(file2.videoCodec.displayName)
                case "bitrate":
                    comparison = compareOptional(file1.bitRate, file2.bitRate)
                case "container":
                    comparison = file1.containerFormat.displayName.compare(file2.containerFormat.displayName)
                default:
                    comparison = .orderedSame
                }

                if comparison != .orderedSame {
                    return descriptor.ascending ? comparison == .orderedAscending : comparison == .orderedDescending
                }
            }
            return false
        }

        tableView.reloadData()
    }

    private func compareOptional<T: Comparable>(_ a: T?, _ b: T?) -> ComparisonResult {
        switch (a, b) {
        case (nil, nil): return .orderedSame
        case (nil, _): return .orderedAscending
        case (_, nil): return .orderedDescending
        case let (a?, b?):
            if a < b { return .orderedAscending }
            if a > b { return .orderedDescending }
            return .orderedSame
        }
    }
}

extension FileTableViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < files.count else { return nil }
        let file = files[row]

        let identifier = tableColumn?.identifier.rawValue ?? ""

        let cellView: NSTableCellView
        if let existingView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(identifier), owner: nil) as? NSTableCellView {
            cellView = existingView
        } else {
            cellView = NSTableCellView()
            cellView.identifier = NSUserInterfaceItemIdentifier(identifier)

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingTail
            cellView.addSubview(textField)
            cellView.textField = textField

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])
        }

        let text: String
        switch identifier {
        case "name":
            text = file.fileName
        case "size":
            text = file.formattedFileSize
        case "duration":
            text = file.formattedDuration
        case "resolution":
            text = file.resolutionCategory
        case "videoCodec":
            text = file.videoCodec.displayName
        case "audio":
            text = file.audioDescription
        case "bitrate":
            text = file.formattedBitRate
        case "container":
            text = file.containerFormat.displayName
        default:
            text = ""
        }

        cellView.textField?.stringValue = text
        return cellView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRows = tableView.selectedRowIndexes
        let selectedFiles = selectedRows.compactMap { row -> VideoFile? in
            guard row < files.count else { return nil }
            return files[row]
        }
        onSelectionChanged?(selectedFiles)
    }
}

struct FileTableViewRepresentable: NSViewControllerRepresentable {
    let files: [VideoFile]
    @Binding var selection: Set<VideoFile.ID>

    func makeNSViewController(context: Context) -> FileTableViewController {
        let controller = FileTableViewController()
        controller.onSelectionChanged = { selectedFiles in
            selection = Set(selectedFiles.compactMap { $0.id })
        }
        controller.onDoubleClick = { file in
            NSWorkspace.shared.open(URL(fileURLWithPath: file.filePath))
        }
        return controller
    }

    func updateNSViewController(_ nsViewController: FileTableViewController, context: Context) {
        nsViewController.updateFiles(files)
    }
}
