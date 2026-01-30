import Foundation

/// Runs ffprobe as a subprocess to extract video metadata.
///
/// Key implementation details:
/// - Runs ffprobe on a background thread to avoid blocking the actor
/// - Implements reliable timeout with SIGTERM → SIGKILL escalation
/// - Uses `-probesize` and `-analyzeduration` limits for faster probing
///
/// Timeout handling:
/// Network volumes can cause ffprobe to hang indefinitely. We use a
/// DispatchSource timer that first sends SIGTERM, then SIGKILL after
/// 100ms if the process doesn't exit. This ensures we never block.
actor FFProbeRunner {
    private let ffprobePath: String
    private let timeout: TimeInterval

    init(timeout: TimeInterval = 15) {
        if let bundledPath = Bundle.main.path(forResource: "ffprobe", ofType: nil) {
            self.ffprobePath = bundledPath
        } else if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/ffprobe") {
            self.ffprobePath = "/opt/homebrew/bin/ffprobe"
        } else if FileManager.default.fileExists(atPath: "/usr/local/bin/ffprobe") {
            self.ffprobePath = "/usr/local/bin/ffprobe"
        } else {
            self.ffprobePath = "ffprobe"
        }
        self.timeout = timeout
    }

    func probe(filePath: String) async throws -> FFProbeOutput {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                self.runProbe(filePath: filePath, continuation: continuation)
            }
        }
    }

    /// Runs ffprobe synchronously on a background thread.
    ///
    /// Why nonisolated + background thread:
    /// - Process.waitUntilExit() is blocking; can't run on actor
    /// - Pipe reads must happen on same thread as process
    /// - Using CheckedContinuation bridges to async/await
    ///
    /// ffprobe arguments explained:
    /// - `-v quiet`: Suppress log output
    /// - `-print_format json`: Machine-readable output
    /// - `-show_format`: Include container format info
    /// - `-show_streams`: Include video/audio stream details
    /// - `-probesize 5000000`: Limit bytes read for format detection (5MB)
    /// - `-analyzeduration 5000000`: Limit analysis time (5 seconds max)
    ///
    /// The probesize/analyzeduration limits dramatically improve performance
    /// on large files where we don't need full analysis.
    private nonisolated func runProbe(
        filePath: String,
        continuation: CheckedContinuation<FFProbeOutput, Error>
    ) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffprobePath)
        process.arguments = [
            "-v", "quiet",
            "-print_format", "json",
            "-show_format",
            "-show_streams",
            "-probesize", "5000000",      // Limit to first 5MB for format detection
            "-analyzeduration", "5000000", // Max 5 seconds of stream analysis
            filePath
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Timeout mechanism using DispatchSource timer
        // This is more reliable than Process.terminationHandler for hung processes
        var didTimeout = false
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timer.schedule(deadline: .now() + timeout)
        timer.setEventHandler {
            didTimeout = true
            if process.isRunning {
                // First try graceful termination (SIGTERM)
                process.terminate()
                // If still running after 100ms, force kill (SIGKILL)
                // This handles cases where ffprobe ignores SIGTERM (e.g., stuck on I/O)
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                    if process.isRunning {
                        kill(process.processIdentifier, SIGKILL)
                    }
                }
            }
        }
        timer.resume()

        defer {
            timer.cancel()
        }

        do {
            try process.run()
        } catch {
            continuation.resume(throwing: FFProbeError.processStartFailed(error))
            return
        }

        // Wait for process to complete
        process.waitUntilExit()

        // Check if we timed out
        if didTimeout {
            continuation.resume(throwing: FFProbeError.timeout(filePath))
            return
        }

        // Read output
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            continuation.resume(throwing: FFProbeError.nonZeroExit(
                Int(process.terminationStatus),
                errorMessage
            ))
            return
        }

        do {
            let output = try JSONDecoder().decode(FFProbeOutput.self, from: outputData)
            continuation.resume(returning: output)
        } catch {
            continuation.resume(throwing: FFProbeError.parseError(error))
        }
    }

    func checkAvailability() async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffprobePath)
        process.arguments = ["-version"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    func getVersion() async -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffprobePath)
        process.arguments = ["-version"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: outputData, encoding: .utf8) else { return nil }

            let lines = output.components(separatedBy: "\n")
            guard let firstLine = lines.first else { return nil }

            if let range = firstLine.range(of: "ffprobe version ") {
                let versionStart = range.upperBound
                let versionString = firstLine[versionStart...]
                if let spaceIndex = versionString.firstIndex(of: " ") {
                    return String(versionString[..<spaceIndex])
                }
                return String(versionString)
            }

            return nil
        } catch {
            return nil
        }
    }
}

enum FFProbeError: Error, LocalizedError {
    case timeout(String)
    case processStartFailed(Error)
    case nonZeroExit(Int, String)
    case parseError(Error)
    case notFound

    var errorDescription: String? {
        switch self {
        case .timeout(let path):
            let fileName = (path as NSString).lastPathComponent
            return "Timeout: \(fileName)"
        case .processStartFailed(let error):
            return "Start failed: \(error.localizedDescription)"
        case .nonZeroExit(let code, let message):
            return "ffprobe error (\(code)): \(message.prefix(100))"
        case .parseError(let error):
            return "Parse error: \(error.localizedDescription)"
        case .notFound:
            return "ffprobe not found"
        }
    }
}
