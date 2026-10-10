import Foundation
import AppKit
import Darwin

class DownloadManager {
    static let shared = DownloadManager()

    private init() {}

    struct DownloadFormat {
        let formatId: String
        let description: String
    }

    struct AudioInfo {
        let title: String
        let duration: String
        let formats: [DownloadFormat]
    }

    struct PlaylistInfo {
        let title: String
        let items: [PlaylistItem]
    }

    struct PlaylistItem {
        let title: String
        let url: String
        let duration: String
    }

    struct PlaylistDownloadProgress {
        let completedCount: Int
        let failedCount: Int
        let totalCount: Int
        let currentTitle: String
    }

    struct PlaylistDownloadResult {
        let completedCount: Int
        let failedCount: Int
    }

    enum DownloadError: LocalizedError {
        case formatFetchFailed
        case downloadFailed(String)
        case invalidURL
        case ytDlpNotFound
        case ffmpegNotFound
        case titleFetchFailed
        case playlistFetchFailed
        case playlistDownloadFailed(String)

        var errorDescription: String? {
            switch self {
            case .formatFetchFailed:
                return NSLocalizedString("Failed to get available formats", comment: "Error message when format fetching fails")
            case .downloadFailed(let message):
                return String(format: NSLocalizedString("Download failed: %@", comment: "Error message when download fails with reason"), message)
            case .invalidURL:
                return NSLocalizedString("Invalid URL", comment: "Error message for invalid URL")
            case .ytDlpNotFound:
                return NSLocalizedString("yt-dlp not found, please make sure it's installed (brew install yt-dlp)", comment: "Error message when yt-dlp is not found")
            case .ffmpegNotFound:
                return NSLocalizedString("ffmpeg not found, please make sure it's installed (brew install ffmpeg)", comment: "Error message when ffmpeg is not found")
            case .titleFetchFailed:
                return NSLocalizedString("Failed to get video title", comment: "Error message when title fetching fails")
            case .playlistFetchFailed:
                return NSLocalizedString("Failed to get playlist information", comment: "Error message when playlist fetching fails")
            case .playlistDownloadFailed(let message):
                return String(format: NSLocalizedString("Playlist download failed: %@", comment: "Error message when playlist download fails with reason"), message)
            }
        }
    }

    private struct ProcessResult {
        let terminationStatus: Int32
        let standardOutput: String
        let standardError: String
    }

    private final class CancellableProcessBox: @unchecked Sendable {
        private let lock = NSLock()
        private var process: Process?
        private var cancelled = false

        func setProcess(_ process: Process) {
            lock.lock()
            self.process = process
            let shouldTerminate = cancelled
            lock.unlock()

            if shouldTerminate {
                terminate()
            }
        }

        func cancel() {
            lock.lock()
            cancelled = true
            lock.unlock()
            terminate()
        }

        var isCancelled: Bool {
            lock.lock()
            defer { lock.unlock() }
            return cancelled
        }

        private func terminate() {
            lock.lock()
            let process = self.process
            lock.unlock()

            if process?.isRunning == true {
                guard let process else { return }
                let pid = process.processIdentifier
                if getpgid(pid) == pid {
                    kill(-pid, SIGTERM)
                } else {
                    process.terminate()
                }
            }
        }
    }

    private func runCancellableProcess(
        executablePath: String,
        arguments: [String]
    ) async throws -> ProcessResult {
        let processBox = CancellableProcessBox()

        return try await withTaskCancellationHandler {
            try Task.checkCancellation()

            let task = Process()
            task.executableURL = URL(fileURLWithPath: executablePath)
            task.arguments = arguments

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = outputPipe
            task.standardError = errorPipe

            processBox.setProcess(task)

            let outputReader = Task.detached(priority: .background) {
                outputPipe.fileHandleForReading.readDataToEndOfFile()
            }
            let errorReader = Task.detached(priority: .background) {
                errorPipe.fileHandleForReading.readDataToEndOfFile()
            }

            do {
                try Task.checkCancellation()
                try task.run()
            } catch {
                try? outputPipe.fileHandleForWriting.close()
                try? errorPipe.fileHandleForWriting.close()
                _ = await outputReader.value
                _ = await errorReader.value
                throw error
            }

            if processBox.isCancelled && task.isRunning {
                processBox.cancel()
            }

            task.waitUntilExit()

            let outputData = await outputReader.value
            let errorData = await errorReader.value

            if Task.isCancelled || processBox.isCancelled {
                throw CancellationError()
            }

            return ProcessResult(
                terminationStatus: task.terminationStatus,
                standardOutput: String(data: outputData, encoding: .utf8) ?? "",
                standardError: String(data: errorData, encoding: .utf8) ?? ""
            )
        } onCancel: {
            processBox.cancel()
        }
    }

    private func executablePath(_ name: String, notFound: DownloadError) throws -> String {
        let task = Process()
        task.launchPath = "/usr/bin/which"
        task.arguments = [name]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()

        if task.terminationStatus == 0,
           let path = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
            print(NSLocalizedString("Found \(name) path: %@", comment: ""), path)
            return path
        }

        if let path = ["/usr/local/bin/\(name)", "/opt/homebrew/bin/\(name)"].first(where: FileManager.default.fileExists(atPath:)) {
            print(NSLocalizedString("Found \(name) path: %@", comment: ""), path)
            return path
        }

        print(NSLocalizedString("Error checking \(name): %@", comment: ""), notFound)
        throw notFound
    }

    private func checkFFmpegAvailability() throws -> String {
        try executablePath("ffmpeg", notFound: .ffmpegNotFound)
    }

    private func checkYtDlpAvailability() throws -> String {
        try executablePath("yt-dlp", notFound: .ytDlpNotFound)
    }

    private func getVideoTitle(from url: String, ytDlpPath: String) async throws -> String {
        do {
            let result = try await runCancellableProcess(
                executablePath: ytDlpPath,
                arguments: [
                    "--get-title",
                    url
                ]
            )

            if result.terminationStatus == 0 {
                let title = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty {
                    return sanitizedFileTitle(title)
                }
            }

            throw DownloadError.titleFetchFailed
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            print(NSLocalizedString("Error getting video title: %@", comment: "Log message when getting video title fails"), error)
            throw DownloadError.titleFetchFailed
        }
    }

    private func sanitizedFileTitle(_ title: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "\\/:*?\"<>|")
        let sanitizedTitle = title.components(separatedBy: invalidChars).joined(separator: "_")
        let trimmedTitle = sanitizedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "Unknown Title" : trimmedTitle
    }

    func fetchAudioInfo(from url: String) async throws -> AudioInfo {
        guard URL(string: url) != nil else { throw DownloadError.invalidURL }
        let ytDlpPath = try checkYtDlpAvailability()
        let result = try await runCancellableProcess(
            executablePath: ytDlpPath,
            arguments: ["--no-playlist", "--skip-download", "--dump-single-json", url]
        )
        guard result.terminationStatus == 0,
              let data = result.standardOutput.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let title = json["title"] as? String,
              let rawFormats = json["formats"] as? [[String: Any]] else {
            throw DownloadError.formatFetchFailed
        }
        let audioFormats = rawFormats.compactMap { format -> DownloadFormat? in
            guard let id = format["format_id"] as? String,
                  format["acodec"] as? String != "none",
                  format["vcodec"] as? String == "none" else { return nil }
            var details = [format["ext"] as? String, format["acodec"] as? String].compactMap { $0 }
            if let bitrate = format["abr"] as? Double, bitrate.isFinite, bitrate > 0, bitrate < Double(Int.max) {
                details.append("\(Int(bitrate)) kbps")
            }
            if let sampleRate = format["asr"] as? Int, sampleRate > 0 {
                details.append("\(sampleRate) Hz")
            }
            return DownloadFormat(formatId: id, description: details.isEmpty ? id : details.joined(separator: " · "))
        }
        guard !audioFormats.isEmpty else { throw DownloadError.formatFetchFailed }
        return AudioInfo(
            title: title,
            duration: durationText(json),
            formats: [DownloadFormat(formatId: "bestaudio", description: NSLocalizedString("Auto Select Audio", comment: ""))] + audioFormats
        )
    }

    private func durationText(_ json: [String: Any]) -> String {
        if let text = json["duration_string"] as? String, !text.isEmpty { return text }
        guard let duration = json["duration"] as? Double, duration.isFinite, duration >= 0, duration < Double(Int.max) else { return "" }
        let seconds = Int(duration)
        if seconds >= 3600 {
            return String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
        }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    func downloadAudio(from url: String, formatId: String, destination: MusicLibrary, outputTitle: String? = nil) async throws {
        print(NSLocalizedString("Starting audio download, URL: %@, Format ID: %@", comment: "Log message when starting download"), url, formatId)

        guard URL(string: url) != nil else {
            throw DownloadError.invalidURL
        }

        try Task.checkCancellation()

        let ytDlpPath = try checkYtDlpAvailability()
        let ffmpegPath = try checkFFmpegAvailability()

        let videoTitle: String
        if let outputTitle = outputTitle {
            videoTitle = sanitizedFileTitle(outputTitle)
        } else {
            videoTitle = try await getVideoTitle(from: url, ytDlpPath: ytDlpPath)
        }
        try Task.checkCancellation()
        print(NSLocalizedString("Video title: %@", comment: "Log message showing video title"), videoTitle)

        let fileManager = FileManager.default
        let musicDirectory = URL(fileURLWithPath: destination.path, isDirectory: true)
        let finalFile = musicDirectory.appendingPathComponent(videoTitle + ".mp3")
        if fileManager.fileExists(atPath: finalFile.path) { return }
        let workDirectory = musicDirectory.appendingPathComponent(".macmusicplayer-download-" + UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: workDirectory, withIntermediateDirectories: false)
        defer { try? fileManager.removeItem(at: workDirectory) }
        let outputFile = workDirectory.path.replacingOccurrences(of: "%", with: "%%") + "/audio.%(ext)s"
        print(NSLocalizedString("Downloading to file: %@", comment: "Log message showing output file"), outputFile)

        do {
            print(NSLocalizedString("Executing download command...", comment: "Log message when executing download command"))

            let result = try await runCancellableProcess(
                executablePath: ytDlpPath,
                arguments: [
                    "--ffmpeg-location", ffmpegPath,
                    "-f", formatId,
                    "--no-playlist",
                    "--extract-audio",
                    "--audio-format", "mp3",
                    "--audio-quality", "0",
                    "-o", outputFile,
                    url
                ]
            )

            if !result.standardOutput.isEmpty {
                print(NSLocalizedString("Download output: %@", comment: "Log message showing download output"), result.standardOutput)
            }

            if !result.standardError.isEmpty {
                print(NSLocalizedString("Download error output: %@", comment: "Log message showing download error"), result.standardError)
            }

            if result.terminationStatus == 0 {
                try Task.checkCancellation()
                let completedFile = workDirectory.appendingPathComponent("audio.mp3")
                guard renamex_np(completedFile.path, finalFile.path, UInt32(RENAME_EXCL)) == 0 else {
                    throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
                }
                print(NSLocalizedString("Download successful", comment: "Log message when download succeeds"))

                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("RefreshMusicLibrary"), object: nil,
                        userInfo: ["libraryID": destination.id]
                    )
                }
            } else {
                print(NSLocalizedString("Download failed, exit status: %d", comment: "Log message when download fails"), result.terminationStatus)
                throw DownloadError.downloadFailed(result.standardError)
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as DownloadError {
            throw error
        } catch {
            print(NSLocalizedString("Error during download: %@", comment: "Log message when download error occurs"), error)
            throw DownloadError.downloadFailed(error.localizedDescription)
        }
    }


    func isPlaylistURL(_ url: String) -> Bool {
        ["list=", "/playlist", "/sets/"].contains { url.contains($0) }
    }

    func fetchPlaylistInfo(from url: String) async throws -> PlaylistInfo {
        print(NSLocalizedString("Getting playlist information, URL: %@", comment: "Log message when fetching playlist info"), url)

        guard URL(string: url) != nil else {
            throw DownloadError.invalidURL
        }

        try Task.checkCancellation()

        let ytDlpPath = try checkYtDlpAvailability()
        let ffmpegPath = try checkFFmpegAvailability()

        do {
            let result = try await runCancellableProcess(
                executablePath: ytDlpPath,
                arguments: [
                    "--ffmpeg-location", ffmpegPath,
                    "--flat-playlist",
                    "--dump-single-json",
                    url
                ]
            )

            if result.terminationStatus == 0 {
                return try parsePlaylistFromOutput(result.standardOutput)
            } else {
                print(NSLocalizedString("Failed to get playlist info: %@", comment: "Log message when playlist fetching fails"), result.standardError)
                throw DownloadError.playlistFetchFailed
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as DownloadError {
            throw error
        } catch {
            print(NSLocalizedString("Error getting playlist info: %@", comment: "Log message when getting playlist info fails"), error)
            throw DownloadError.playlistFetchFailed
        }
    }

    private func parsePlaylistFromOutput(_ output: String) throws -> PlaylistInfo {
        guard let data = output.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = json["entries"] as? [Any] else {
            throw DownloadError.playlistFetchFailed
        }
        let items = entries.compactMap { rawEntry -> PlaylistItem? in
            guard let entry = rawEntry as? [String: Any],
                  let url = entry["webpage_url"] as? String ?? entry["url"] as? String, !url.isEmpty else { return nil }
            return PlaylistItem(
                title: entry["title"] as? String ?? NSLocalizedString("Unknown Title", comment: ""),
                url: url,
                duration: durationText(entry)
            )
        }
        guard !items.isEmpty else { throw DownloadError.playlistFetchFailed }
        return PlaylistInfo(title: json["title"] as? String ?? NSLocalizedString("Playlist", comment: ""), items: items)
    }

    private func outputTitles(forPlaylistItems items: [PlaylistItem]) -> [String] {
        let baseTitles = items.map { sanitizedFileTitle($0.title) }
        let titleCounts = Dictionary(grouping: baseTitles, by: { $0 }).mapValues(\.count)
        var occurrences: [String: Int] = [:]
        var usedTitles = Set<String>()

        return baseTitles.map { title in
            var candidate = title
            var occurrence = occurrences[title] ?? 0

            if titleCounts[title, default: 0] > 1 {
                occurrence += 1
                occurrences[title] = occurrence
                candidate = "\(title) [\(occurrence)]"
            }

            while usedTitles.contains(candidate) {
                occurrence += 1
                candidate = "\(title) [\(occurrence)]"
            }

            occurrences[title] = occurrence
            usedTitles.insert(candidate)
            return candidate
        }
    }

    func downloadPlaylistItems(
        _ items: [PlaylistItem],
        destination: MusicLibrary,
        maxConcurrentDownloads: Int = 3,
        progressCallback: @escaping (PlaylistDownloadProgress) -> Void
    ) async throws -> PlaylistDownloadResult {
        if items.isEmpty {
            throw DownloadError.playlistDownloadFailed(NSLocalizedString("Playlist is empty", comment: "Error when playlist has no downloadable items"))
        }

        var completed = 0
        var failed = 0
        var nextIndex = 0
        let totalCount = items.count
        let concurrentLimit = max(1, min(maxConcurrentDownloads, totalCount))
        let outputTitles = outputTitles(forPlaylistItems: items)

        try await withThrowingTaskGroup(of: (PlaylistItem, Bool).self) { group in
            func startNextDownload() async {
                let item = items[nextIndex]
                let outputTitle = outputTitles[nextIndex]
                nextIndex += 1

                let progress = PlaylistDownloadProgress(completedCount: completed, failedCount: failed, totalCount: totalCount, currentTitle: item.title)
                await MainActor.run {
                    progressCallback(progress)
                }

                group.addTask {
                    do {
                        try await self.downloadAudio(from: item.url, formatId: "bestaudio", destination: destination, outputTitle: outputTitle)
                        return (item, true)
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        print(String(format: NSLocalizedString("Failed to download: %@ - Error: %@", comment: "Log message when item download fails"), item.title, error.localizedDescription))
                        return (item, false)
                    }
                }
            }

            while nextIndex < concurrentLimit {
                await startNextDownload()
            }

            while let (item, succeeded) = try await group.next() {
                if succeeded {
                    completed += 1
                    print(String(format: NSLocalizedString("Successfully downloaded: %@", comment: "Log message when item downloaded successfully"), item.title))
                } else {
                    failed += 1
                }

                let progress = PlaylistDownloadProgress(completedCount: completed, failedCount: failed, totalCount: totalCount, currentTitle: item.title)
                await MainActor.run {
                    progressCallback(progress)
                }

                try Task.checkCancellation()

                if nextIndex < totalCount {
                    await startNextDownload()
                }
            }
        }

        try Task.checkCancellation()
        return PlaylistDownloadResult(completedCount: completed, failedCount: failed)
    }
}
