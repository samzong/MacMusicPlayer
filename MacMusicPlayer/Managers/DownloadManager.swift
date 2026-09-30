import Foundation
import AppKit

class DownloadManager {
    static let shared = DownloadManager()

    private var libraryManager: LibraryManager?

    private init() {}

    @MainActor
    func updateLibraryManager(_ libraryManager: LibraryManager) {
        self.libraryManager = libraryManager
    }

    struct DownloadFormat {
        let formatId: String
        let description: String
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
        let currentIndex: Int
        let totalCount: Int
        let currentTitle: String
    }

    enum DownloadError: Error {
        case formatFetchFailed
        case downloadFailed(String)
        case invalidURL
        case ytDlpNotFound
        case ffmpegNotFound
        case titleFetchFailed
        case playlistFetchFailed
        case playlistDownloadFailed(String)

        var localizedDescription: String {
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
            let process = self.process
            lock.unlock()

            if process?.isRunning == true {
                process?.terminate()
            }
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
                process?.terminate()
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

            try Task.checkCancellation()
            try task.run()

            if processBox.isCancelled && task.isRunning {
                task.terminate()
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

    func fetchAvailableFormats(from url: String) async throws -> [DownloadFormat] {
        print(NSLocalizedString("Getting available formats, URL: %@", comment: "Log message when fetching formats"), url)

        guard URL(string: url) != nil else {
            throw DownloadError.invalidURL
        }

        let ytDlpPath = try checkYtDlpAvailability()
        let ffmpegPath = try checkFFmpegAvailability()

        let result = try await runCancellableProcess(
            executablePath: ytDlpPath,
            arguments: [
                "--ffmpeg-location", ffmpegPath,
                "-F",
                url
            ]
        )

        guard result.terminationStatus == 0 else {
            print(NSLocalizedString("Failed to get formats: %@", comment: "Log message when format fetching fails"), result.standardError)
            throw DownloadError.formatFetchFailed
        }

        return parseFormatsFromOutput(result.standardOutput)
    }

    private func parseFormatsFromOutput(_ output: String) -> [DownloadFormat] {
        var formats = [DownloadFormat(
            formatId: "bestaudio",
            description: NSLocalizedString("🎵 Best Quality (Auto Select)", comment: "Format description for best audio quality")
        )]

        formats += output.components(separatedBy: .newlines)
            .filter { $0.contains("audio only") }
            .compactMap(parseAudioFormatLine)

        if formats.count <= 1 {
            formats += [
                DownloadFormat(
                    formatId: "140",
                    description: NSLocalizedString("M4A Audio (128kbps, 44kHz, stereo, 3.5MiB) [AAC]", comment: "Predefined format description")
                ),
                DownloadFormat(
                    formatId: "251",
                    description: NSLocalizedString("WebM Audio (160kbps, 48kHz, stereo, 3.2MiB) [Opus]", comment: "Predefined format description")
                )
            ]
        }

        var seenDescriptions = Set<String>()
        return formats.filter { seenDescriptions.insert($0.description).inserted }
    }

    private func parseAudioFormatLine(_ line: String) -> DownloadFormat? {
        let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard components.count >= 2 else { return nil }

        let formatId = components[0]

        var fileExtension = "mp3"

        if line.contains("m4a") {
            fileExtension = "m4a"
        } else if line.contains("webm") {
            fileExtension = "webm"
        } else if line.contains("opus") {
            fileExtension = "opus"
        }

        var bitrate = ""
        if let bitrateRange = line.range(of: "\\d+k", options: .regularExpression) {
            bitrate = String(line[bitrateRange])
        }

        var sampleRate = ""
        if let sampleRateRange = line.range(of: "\\d+\\.?\\d*kHz|\\d+Hz|\\d+k\\s", options: .regularExpression) {
            sampleRate = String(line[sampleRateRange]).trimmingCharacters(in: .whitespaces)
        } else if line.contains("44k") {
            sampleRate = "44kHz"
        } else if line.contains("48k") {
            sampleRate = "48kHz"
        }

        let channels: String
        if line.contains("stereo") || line.contains("2.0") {
            channels = NSLocalizedString("stereo", comment: "Audio channel type")
        } else if line.contains("mono") || line.contains("1.0") {
            channels = NSLocalizedString("mono", comment: "Audio channel type")
        } else if line.contains("5.1") {
            channels = NSLocalizedString("5.1 channels", comment: "Audio channel type")
        } else {
            channels = NSLocalizedString("stereo", comment: "Audio channel type")
        }

        var fileSize = ""
        if let fileSizeRange = line.range(of: "\\d+\\.?\\d*[KMG]iB", options: .regularExpression) {
            fileSize = String(line[fileSizeRange])
        }

        var codec = ""
        if line.contains("opus") {
            codec = "Opus"
        } else if line.contains("mp4a") {
            codec = "AAC"
        } else if line.contains("mp3") {
            codec = "MP3"
        } else if line.contains("vorbis") {
            codec = "Vorbis"
        }

        var description: String
        if bitrate.isEmpty {
            description = String(format: NSLocalizedString("%@ Audio", comment: "Format description without details"), fileExtension.uppercased())
            let details = [sampleRate, channels, fileSize].filter { !$0.isEmpty }.joined(separator: ", ")
            if !details.isEmpty {
                description += " (\(details))"
            }
        } else {
            description = String(format: NSLocalizedString("%@ Audio (%@", comment: "Format description with bitrate"), fileExtension.uppercased(), bitrate)
            for detail in [sampleRate, channels, fileSize] where !detail.isEmpty {
                description += ", \(detail)"
            }
            description += ")"
        }

        if !codec.isEmpty {
            description += " [\(codec)]"
        }

        return DownloadFormat(formatId: formatId, description: description)
    }

    func downloadAudio(from url: String, formatId: String, outputTitle: String? = nil) async throws {
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

        guard let currentLibrary = libraryManager?.currentLibrary else {
            throw DownloadError.downloadFailed("No music library selected")
        }

        let musicPath = currentLibrary.path
        let outputFile = "\(musicPath)/\(videoTitle).%(ext)s"
        print(NSLocalizedString("Downloading to file: %@", comment: "Log message showing output file"), outputFile)

        do {
            print(NSLocalizedString("Executing download command...", comment: "Log message when executing download command"))

            let result = try await runCancellableProcess(
                executablePath: ytDlpPath,
                arguments: [
                    "--ffmpeg-location", ffmpegPath,
                    "-f", formatId,
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
                print(NSLocalizedString("Download successful", comment: "Log message when download succeeds"))

                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshMusicLibrary"), object: nil)
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
                    "--dump-json",
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
        var items: [PlaylistItem] = []
        var playlistTitle = "Unknown Playlist"

        for line in output.components(separatedBy: .newlines) where !line.isEmpty {
            guard let data = line.data(using: .utf8),
                  let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { continue }

            let entryType = json["_type"] as? String
            if entryType == "url" {
                items.append(PlaylistItem(
                    title: json["title"] as? String ?? "Unknown Title",
                    url: json["url"] as? String ?? "",
                    duration: json["duration_string"] as? String ?? ""
                ))
            } else if json["_type"] == nil || entryType == "playlist", let title = json["title"] as? String {
                playlistTitle = title
            }
        }

        if items.isEmpty {
            throw DownloadError.playlistFetchFailed
        }

        return PlaylistInfo(title: playlistTitle, items: items)
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
        maxConcurrentDownloads: Int = 3,
        progressCallback: @escaping (PlaylistDownloadProgress) -> Void
    ) async throws {
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

                let progress = PlaylistDownloadProgress(currentIndex: nextIndex, totalCount: totalCount, currentTitle: item.title)
                await MainActor.run {
                    progressCallback(progress)
                }

                group.addTask {
                    do {
                        try await self.downloadAudio(from: item.url, formatId: "bestaudio", outputTitle: outputTitle)
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

                let progress = PlaylistDownloadProgress(currentIndex: nextIndex, totalCount: totalCount, currentTitle: item.title)
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
        let finalProgress = PlaylistDownloadProgress(
            currentIndex: totalCount,
            totalCount: totalCount,
            currentTitle: NSLocalizedString("Completed", comment: "Download completion status")
        )

        await MainActor.run {
            progressCallback(finalProgress)
        }

        if failed > 0 && completed == 0 {
            throw DownloadError.playlistDownloadFailed(NSLocalizedString("All downloads failed", comment: "Error when all playlist downloads fail"))
        }

        print(String(format: NSLocalizedString("Playlist download completed: %d successful, %d failed", comment: "Log message when playlist download completes"), completed, failed))
    }
}
