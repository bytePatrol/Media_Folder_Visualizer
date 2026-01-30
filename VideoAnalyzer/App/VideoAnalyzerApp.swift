import SwiftUI

@main
struct VideoAnalyzerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appState)
                .frame(minWidth: 1200, minHeight: 800)
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Scan...") {
                    appState.showFolderPicker = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(after: .newItem) {
                Divider()

                Button("Export...") {
                    appState.showExportSheet = true
                }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(appState.videoFiles.isEmpty)

                Divider()

                Button("Clear All Data...") {
                    appState.showClearDataAlert = true
                }
                .disabled(appState.videoFiles.isEmpty && appState.scanState != .scanning)
            }

            CommandMenu("Scan") {
                Button(appState.scanState == .scanning ? "Pause Scan" : "Resume Scan") {
                    Task {
                        if appState.scanState == .scanning {
                            await appState.pauseScan()
                        } else if appState.scanState == .paused {
                            await appState.resumeScan()
                        }
                    }
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(appState.scanState != .scanning && appState.scanState != .paused)

                Button("Cancel Scan") {
                    Task {
                        await appState.cancelScan()
                    }
                }
                .keyboardShortcut(".", modifiers: .command)
                .disabled(appState.scanState == .idle || appState.scanState == .completed)

                Divider()

                Button("Check Integrity...") {
                    appState.showIntegritySheet = true
                }
                .disabled(appState.videoFiles.isEmpty || appState.scanState == .scanning)

                Button("Find Duplicates...") {
                    appState.showDuplicateSheet = true
                }
                .disabled(appState.videoFiles.isEmpty || appState.scanState == .scanning)
            }

            CommandGroup(replacing: .sidebar) {
                Button("Show Dashboard") {
                    appState.selectedTab = .dashboard
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Show File List") {
                    appState.selectedTab = .files
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Show Scanner") {
                    appState.selectedTab = .scanner
                }
                .keyboardShortcut("3", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case files = "Files"
    case scanner = "Scanner"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "chart.pie"
        case .files: return "folder"
        case .scanner: return "magnifyingglass"
        }
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var selectedTab: AppTab = .dashboard
    @Published var videoFiles: [VideoFile] = []
    @Published var statistics: VideoStatistics = .empty
    @Published var scanProgress: ScanProgress = ScanProgress(totalFiles: 0, processedFiles: 0, currentFile: nil, state: .idle)
    @Published var scanState: ScanState = .idle
    @Published var logEntries: [LogEntry] = []
    @Published var searchText: String = ""
    @Published var selectedFiles: Set<VideoFile.ID> = []

    @Published var showFolderPicker: Bool = false
    @Published var showExportSheet: Bool = false
    @Published var showIntegritySheet: Bool = false
    @Published var showDuplicateSheet: Bool = false
    @Published var showRecoveryAlert: Bool = false
    @Published var showClearDataAlert: Bool = false
    @Published var recoveryInfo: RecoveryInfo?

    @Published var filterVideoCodecs: Set<VideoCodec> = []
    @Published var filterHDRFormats: Set<HDRFormat> = []
    @Published var filterAudioCodecs: Set<AudioCodec> = []
    @Published var filterContainers: Set<ContainerFormat> = []
    @Published var filterResolutions: Set<String> = []
    @Published var filterHasAtmos: Bool? = nil
    @Published var filterHasDTSX: Bool? = nil
    @Published var filterImmersiveAudio: Bool? = nil

    @Published var sortColumn: SortColumn = .fileName
    @Published var sortAscending: Bool = true

    private let scanEngine = ScanEngine()
    private let repository = VideoFileRepository()
    private let recoveryService = StateRecoveryService()
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupSubscriptions()
        Task {
            await initializeApp()
        }
    }

    private func setupSubscriptions() {
        // Update progress immediately
        scanEngine.progressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.scanProgress = progress
                self?.scanState = progress.state
            }
            .store(in: &cancellables)

        // Throttle data refresh to once per second during scanning
        scanEngine.progressPublisher
            .filter { $0.state == .scanning }
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                Task {
                    await self?.refreshData()
                }
            }
            .store(in: &cancellables)

        scanEngine.logPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entry in
                self?.logEntries.append(entry)
                if self?.logEntries.count ?? 0 > 1000 {
                    self?.logEntries.removeFirst(100)
                }
            }
            .store(in: &cancellables)

        scanEngine.completionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.refreshData()
                }
            }
            .store(in: &cancellables)
    }

    private func initializeApp() async {
        do {
            try await DatabaseManager.shared.initialize()
            await refreshData()
            await checkForRecovery()
        } catch {
            logEntries.append(LogEntry(
                timestamp: Date(),
                level: .error,
                message: "Failed to initialize: \(error.localizedDescription)"
            ))
        }
    }

    private func checkForRecovery() async {
        if let info = await recoveryService.checkForRecoverableScan() {
            self.recoveryInfo = info
            self.showRecoveryAlert = true
        }
    }

    func startScan(folderPath: String) async {
        logEntries.removeAll()
        selectedTab = .scanner

        do {
            try await scanEngine.startScan(folderPath: folderPath)
        } catch {
            logEntries.append(LogEntry(
                timestamp: Date(),
                level: .error,
                message: "Scan failed: \(error.localizedDescription)"
            ))
        }
    }

    func resumeFromRecovery() async {
        guard let info = recoveryInfo else { return }

        logEntries.removeAll()
        selectedTab = .scanner

        do {
            try await scanEngine.resumeFromCheckpoint(info.checkpoint)
        } catch {
            logEntries.append(LogEntry(
                timestamp: Date(),
                level: .error,
                message: "Recovery failed: \(error.localizedDescription)"
            ))
        }

        recoveryInfo = nil
    }

    func dismissRecovery() {
        recoveryService.deleteCheckpoint()
        recoveryInfo = nil
    }

    func pauseScan() async {
        await scanEngine.pause()
    }

    func resumeScan() async {
        await scanEngine.resume()
    }

    func cancelScan() async {
        await scanEngine.cancel()
    }

    func refreshData() async {
        do {
            // Handle immersive audio filter (Atmos OR DTS:X)
            var atmosFilter = filterHasAtmos
            var dtsxFilter = filterHasDTSX

            // If filterImmersiveAudio is set, we need to handle it differently
            // The repository doesn't support OR logic, so we'll filter in memory for this case
            let useImmersiveFilter = filterImmersiveAudio == true

            if useImmersiveFilter {
                // Don't pass Atmos/DTS:X filters to DB, we'll filter after
                atmosFilter = nil
                dtsxFilter = nil
            }

            var files = try await repository.fetchFiltered(
                searchText: searchText.isEmpty ? nil : searchText,
                videoCodecs: filterVideoCodecs.isEmpty ? nil : filterVideoCodecs,
                hdrFormats: filterHDRFormats.isEmpty ? nil : filterHDRFormats,
                audioCodecs: filterAudioCodecs.isEmpty ? nil : filterAudioCodecs,
                containers: filterContainers.isEmpty ? nil : filterContainers,
                resolutionCategories: filterResolutions.isEmpty ? nil : filterResolutions,
                hasAtmos: atmosFilter,
                hasDTSX: dtsxFilter,
                sortColumn: sortColumn,
                sortAscending: sortAscending
            )

            // Apply immersive audio filter in memory (Atmos OR DTS:X)
            if useImmersiveFilter {
                files = files.filter { $0.isAtmos || $0.isDTSX }
            }

            videoFiles = files
            statistics = try await repository.fetchStatistics()
        } catch {
            logEntries.append(LogEntry(
                timestamp: Date(),
                level: .error,
                message: "Failed to load data: \(error.localizedDescription)"
            ))
        }
    }

    func clearFilters() {
        filterVideoCodecs.removeAll()
        filterHDRFormats.removeAll()
        filterAudioCodecs.removeAll()
        filterContainers.removeAll()
        filterResolutions.removeAll()
        filterHasAtmos = nil
        filterHasDTSX = nil
        filterImmersiveAudio = nil
        searchText = ""

        Task {
            await refreshData()
        }
    }

    // MARK: - Navigation Helpers

    /// Navigate to Files tab with HDR content filter applied
    func navigateToHDRContent() {
        clearFilters()
        // Set HDR formats filter to all non-SDR formats
        filterHDRFormats = Set(HDRFormat.allCases.filter { $0 != .sdr })
        selectedTab = .files
        Task {
            await refreshData()
        }
    }

    /// Navigate to Files tab with Dolby Vision filter
    func navigateToDolbyVision() {
        clearFilters()
        filterHDRFormats = [.dolbyVision, .dolbyVisionHDR10]
        selectedTab = .files
        Task {
            await refreshData()
        }
    }

    /// Navigate to Files tab with immersive audio filter (Atmos or DTS:X)
    func navigateToImmersiveAudio() {
        clearFilters()
        filterImmersiveAudio = true
        selectedTab = .files
        Task {
            await refreshData()
        }
    }

    /// Navigate to Files tab with Atmos filter
    func navigateToAtmos() {
        clearFilters()
        filterHasAtmos = true
        selectedTab = .files
        Task {
            await refreshData()
        }
    }

    /// Navigate to Files tab with DTS:X filter
    func navigateToDTSX() {
        clearFilters()
        filterHasDTSX = true
        selectedTab = .files
        Task {
            await refreshData()
        }
    }

    /// Navigate to Files tab with specific resolution filter
    func navigateToResolution(_ resolution: String) {
        clearFilters()
        filterResolutions = [resolution]
        selectedTab = .files
        Task {
            await refreshData()
        }
    }

    /// Navigate to Files tab with specific video codec filter
    func navigateToCodec(_ codec: VideoCodec) {
        clearFilters()
        filterVideoCodecs = [codec]
        selectedTab = .files
        Task {
            await refreshData()
        }
    }

    /// Navigate to Files tab with specific HDR format filter
    func navigateToHDRFormat(_ format: HDRFormat) {
        clearFilters()
        filterHDRFormats = [format]
        selectedTab = .files
        Task {
            await refreshData()
        }
    }

    /// Navigate to Files tab with specific audio codec filter
    func navigateToAudioCodec(_ codec: AudioCodec) {
        clearFilters()
        filterAudioCodecs = [codec]
        selectedTab = .files
        Task {
            await refreshData()
        }
    }

    /// Navigate to Files tab with specific container format filter
    func navigateToContainer(_ container: ContainerFormat) {
        clearFilters()
        filterContainers = [container]
        selectedTab = .files
        Task {
            await refreshData()
        }
    }

    func deleteAllData() async {
        do {
            try await repository.deleteAll()
            await refreshData()
        } catch {
            logEntries.append(LogEntry(
                timestamp: Date(),
                level: .error,
                message: "Failed to delete data: \(error.localizedDescription)"
            ))
        }
    }
}

import Combine
