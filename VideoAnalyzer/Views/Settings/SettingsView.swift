import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            ScanningSettingsView()
                .tabItem {
                    Label("Scanning", systemImage: "magnifyingglass")
                }

            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "wrench.and.screwdriver")
                }
        }
        .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("appearance") private var appearance: AppAppearance = .system
    @AppStorage("showFilePathInList") private var showFilePathInList = true
    @AppStorage("confirmDeletion") private var confirmDeletion = true

    var body: some View {
        Form {
            Section {
                Picker("Theme", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Appearance")
            }

            Section {
                Toggle("Show file paths in list", isOn: $showFilePathInList)
            } header: {
                Text("File List")
            }

            Section {
                Toggle("Confirm before deleting data", isOn: $confirmDeletion)
            } header: {
                Text("Safety")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(VaultColors.vault)
        .padding()
    }
}

struct ScanningSettingsView: View {
    @AppStorage("maxConcurrentScans") private var maxConcurrentScans = 8
    @AppStorage("checkpointInterval") private var checkpointInterval = 5
    @AppStorage("skipHiddenFiles") private var skipHiddenFiles = true
    @AppStorage("ffprobeTimeout") private var ffprobeTimeout = 30

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: VaultSpacing.sm) {
                    Stepper(
                        "Concurrent processes: \(maxConcurrentScans)",
                        value: $maxConcurrentScans,
                        in: 1...16
                    )

                    Text("Higher values scan faster but use more resources")
                        .font(VaultTypography.caption)
                        .foregroundColor(VaultColors.celluloidMuted)
                }
            } header: {
                Text("Performance")
            }

            Section {
                VStack(alignment: .leading, spacing: VaultSpacing.sm) {
                    Stepper(
                        "Checkpoint interval: \(checkpointInterval)s",
                        value: $checkpointInterval,
                        in: 1...30
                    )

                    Text("How often scan progress is saved for crash recovery")
                        .font(VaultTypography.caption)
                        .foregroundColor(VaultColors.celluloidMuted)
                }
            } header: {
                Text("Recovery")
            }

            Section {
                Toggle("Skip hidden files and folders", isOn: $skipHiddenFiles)
            } header: {
                Text("File Discovery")
            }

            Section {
                VStack(alignment: .leading, spacing: VaultSpacing.sm) {
                    Stepper(
                        "ffprobe timeout: \(ffprobeTimeout)s",
                        value: $ffprobeTimeout,
                        in: 10...120
                    )

                    Text("Maximum time to analyze a single file")
                        .font(VaultTypography.caption)
                        .foregroundColor(VaultColors.celluloidMuted)
                }
            } header: {
                Text("Timeouts")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(VaultColors.vault)
        .padding()
    }
}

struct AdvancedSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showClearConfirmation = false
    @State private var ffprobeVersion: String = "Checking..."

    var body: some View {
        Form {
            Section {
                LabeledContent("Location") {
                    Text(databasePath)
                        .font(VaultTypography.caption)
                        .foregroundColor(VaultColors.celluloidMuted)
                        .lineLimit(1)
                        .truncationMode(.head)
                }

                Button("Clear All Data", role: .destructive) {
                    showClearConfirmation = true
                }
                .confirmationDialog(
                    "Clear All Data?",
                    isPresented: $showClearConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Clear", role: .destructive) {
                        Task {
                            await appState.deleteAllData()
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will permanently delete all scanned video data. This action cannot be undone.")
                }
            } header: {
                Text("Database")
            }

            Section {
                LabeledContent("ffprobe version") {
                    Text(ffprobeVersion)
                        .font(VaultTypography.caption)
                        .foregroundColor(VaultColors.celluloidMuted)
                }
            } header: {
                Text("Dependencies")
            }

            Section {
                Button("Open Logs Folder") {
                    openLogsFolder()
                }

                Button("Export Diagnostic Report") {
                    exportDiagnostics()
                }
            } header: {
                Text("Debug")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(VaultColors.vault)
        .padding()
        .task {
            await checkFFProbeVersion()
        }
    }

    private var databasePath: String {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("VideoAnalyzer/video_analyzer.sqlite").path
    }

    private func checkFFProbeVersion() async {
        let runner = FFProbeRunner()
        if let version = await runner.getVersion() {
            ffprobeVersion = version
        } else if await runner.checkAvailability() {
            ffprobeVersion = "Unknown version"
        } else {
            ffprobeVersion = "Not found"
        }
    }

    private func openLogsFolder() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let logsDir = appSupport.appendingPathComponent("VideoAnalyzer")
        NSWorkspace.shared.open(logsDir)
    }

    private func exportDiagnostics() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "VideoAnalyzer_Diagnostics.txt"
        panel.allowedContentTypes = [.plainText]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        var report = "Video Analyzer Diagnostic Report\n"
        report += "Generated: \(Date())\n\n"
        report += "Statistics:\n"
        report += "  Total Files: \(appState.statistics.totalFiles)\n"
        report += "  Total Size: \(appState.statistics.formattedTotalSize)\n"
        report += "  Total Duration: \(appState.statistics.formattedTotalDuration)\n\n"
        report += "System Info:\n"
        report += "  macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
        report += "  ffprobe: \(ffprobeVersion)\n"

        try? report.write(to: url, atomically: true, encoding: .utf8)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }
}
