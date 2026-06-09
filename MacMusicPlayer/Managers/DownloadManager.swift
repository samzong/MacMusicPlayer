import Foundation
import AppKit

public class DownloadManager {
    public static let shared = DownloadManager()

    private var libraryManager: LibraryManager

    private init() {
        self.libraryManager = LibraryManager()
    }

    @MainActor
    func updateLibraryManager(_ libraryManager: LibraryManager) {
        self.libraryManager = libraryManager
    }

    public struct DownloadFormat {
        public let formatId: String
        public let fileExtension: String
        public let description: String
        public let bitrate: String
        public let sampleRate: String
        public let channels: String
        public let fileSize: String

        public init(formatId: String, fileExtension: String, description: String, bitrate: String = "", sampleRate: String = "", channels: String = "", fileSize: String = "") {
            self.formatId = formatId
            self.fileExtension = fileExtension
            self.description = description
            self.bitrate = bitrate
            self.sampleRate = sampleRate
            self.channels = channels
            self.fileSize = fileSize
        }
    }

    public struct PlaylistInfo {
        public let id: String
        public let title: String
        public let description: String
        public let uploader: String
        public let videoCount: Int
        public let items: [PlaylistItem]

        public init(id: String, title: String, description: String, uploader: String, videoCount: Int, items: [PlaylistItem]) {
            self.id = id
            self.title = title
            self.description = description
            self.uploader = uploader
            self.videoCount = videoCount
            self.items = items
        }
    }

    public struct PlaylistItem {
        public let videoId: String
        public let title: String
        public let url: String
        public let duration: String
        public let thumbnailUrl: String

        public init(videoId: String, title: String, url: String, duration: String, thumbnailUrl: String) {
            self.videoId = videoId
            self.title = title
            self.url = url
            self.duration = duration
            self.thumbnailUrl = thumbnailUrl
        }
    }

    public struct PlaylistDownloadProgress {
        public let currentIndex: Int
        public let totalCount: Int
        public let currentTitle: String
        public let completed: Int
        public let failed: Int

        public init(currentIndex: Int, totalCount: Int, currentTitle: String, completed: Int, failed: Int) {
            self.currentIndex = currentIndex
            self.totalCount = totalCount
            self.currentTitle = currentTitle
            self.completed = completed
            self.failed = failed
        }
    }

    public enum DownloadError: Error {
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

    private struct FormatDescriptionProperties {
        let fileExtension: String
        let bitrate: String
        let sampleRate: String
        let channels: String
        let fileSize: String
        let codec: String
    }

    private func checkFFmpegAvailability() throws -> String {
        let task = Process()
        task.launchPath = "/usr/bin/which"
        task.arguments = ["ffmpeg"]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            task.launch()
            task.waitUntilExit()

            if task.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    print(NSLocalizedString("Found ffmpeg path: %@", comment: "Log message when ffmpeg is found"), path)
                    return path
                }
            }

            let commonPaths = [
                "/usr/local/bin/ffmpeg",
                "/opt/homebrew/bin/ffmpeg"
            ]

            for path in commonPaths where FileManager.default.fileExists(atPath: path) {
                print(NSLocalizedString("Found ffmpeg path: %@", comment: "Log message when ffmpeg is found"), path)
                return path
            }

            throw DownloadError.ffmpegNotFound
        } catch {
            print(NSLocalizedString("Error checking ffmpeg: %@", comment: "Log message when checking ffmpeg fails"), error)
            throw DownloadError.ffmpegNotFound
        }
    }

    private func checkYtDlpAvailability() throws -> String {
        let task = Process()
        task.launchPath = "/usr/bin/which"
        task.arguments = ["yt-dlp"]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            task.launch()
            task.waitUntilExit()

            if task.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    print(NSLocalizedString("Found yt-dlp path: %@", comment: "Log message when yt-dlp is found"), path)
                    return path
                }
            }

            let commonPaths = [
                "/usr/local/bin/yt-dlp",
                "/opt/homebrew/bin/yt-dlp"
            ]

            for path in commonPaths where FileManager.default.fileExists(atPath: path) {
                print(NSLocalizedString("Found yt-dlp path: %@", comment: "Log message when yt-dlp is found"), path)
                return path
            }

            throw DownloadError.ytDlpNotFound
        } catch {
            print(NSLocalizedString("Error checking yt-dlp: %@", comment: "Log message when checking yt-dlp fails"), error)
            throw DownloadError.ytDlpNotFound
        }
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

    public func fetchAvailableFormats(from url: String) async throws -> [DownloadFormat] {
        print(NSLocalizedString("Getting available formats, URL: %@", comment: "Log message when fetching formats"), url)

        guard URL(string: url) != nil else {
            throw DownloadError.invalidURL
        }

        let ytDlpPath = try checkYtDlpAvailability()
        let ffmpegPath = try checkFFmpegAvailability()

        let task = Process()
        task.launchPath = ytDlpPath
        task.arguments = [
            "--ffmpeg-location", ffmpegPath,
            "-F",
            url
        ]

        let pipe = Pipe()
        task.standardOutput = pipe
        let errorPipe = Pipe()
        task.standardError = errorPipe

        do {
            task.launch()
            task.waitUntilExit()

            if task.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                return try parseFormatsFromOutput(output)
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                print(NSLocalizedString("Failed to get formats: %@", comment: "Log message when format fetching fails"), errorOutput)
                throw DownloadError.formatFetchFailed
            }
        } catch let error as DownloadError {
            throw error
        } catch {
            print(NSLocalizedString("Error getting formats: %@", comment: "Log message when getting formats fails"), error)

            return createDefaultFormats()
        }
    }

    private func createDefaultFormats() -> [DownloadFormat] {
        return [
            DownloadFormat(
                formatId: "bestaudio",
                fileExtension: "mp3",
                description: NSLocalizedString("Best Quality (Auto Select)", comment: "Format description for best audio quality")
            ),
            DownloadFormat(
                formatId: "140",
                fileExtension: "m4a",
                description: NSLocalizedString("M4A Audio (128kbps, 44kHz, stereo, 3.5MiB) [AAC]", comment: "Predefined format description"),
                bitrate: "128kbps",
                sampleRate: "44kHz",
                channels: NSLocalizedString("stereo", comment: "Audio channel type"),
                fileSize: "3.5MiB"
            ),
            DownloadFormat(
                formatId: "251",
                fileExtension: "webm",
                description: NSLocalizedString("WebM Audio (160kbps, 48kHz, stereo, 3.2MiB) [Opus]", comment: "Predefined format description"),
                bitrate: "160kbps",
                sampleRate: "48kHz",
                channels: NSLocalizedString("stereo", comment: "Audio channel type"),
                fileSize: "3.2MiB"
            )
        ]
    }

    private func parseFormatsFromOutput(_ output: String) throws -> [DownloadFormat] {
        var formats: [DownloadFormat] = []

        formats.append(DownloadFormat(
            formatId: "bestaudio",
            fileExtension: "mp3",
            description: NSLocalizedString("🎵 Best Quality (Auto Select)", comment: "Format description for best audio quality")
        ))

        let lines = output.components(separatedBy: .newlines)
        for line in lines where line.contains("audio only") {
            if let format = parseAudioFormatLine(line) {
                formats.append(format)
            }
        }

        if formats.count <= 1 {
            formats.append(contentsOf: createDefaultFormats().dropFirst())
        }

        return removeDuplicateFormats(formats)
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

        var channels = ""
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

        let properties = FormatDescriptionProperties(
            fileExtension: fileExtension,
            bitrate: bitrate,
            sampleRate: sampleRate,
            channels: channels,
            fileSize: fileSize,
            codec: codec
        )

        let description = createFormatDescription(properties: properties)

        return DownloadFormat(
            formatId: formatId,
            fileExtension: fileExtension,
            description: description,
            bitrate: bitrate,
            sampleRate: sampleRate,
            channels: channels,
            fileSize: fileSize
        )
    }

    private func createFormatDescription(properties: FormatDescriptionProperties) -> String {
        var description = ""

        if !properties.bitrate.isEmpty {
            description = String(format: NSLocalizedString("%@ Audio (%@", comment: "Format description with bitrate"), properties.fileExtension.uppercased(), properties.bitrate)

            if !properties.sampleRate.isEmpty {
                description += String(format: ", %@", properties.sampleRate)
            }

            description += String(format: ", %@", properties.channels)

            if !properties.fileSize.isEmpty {
                description += String(format: ", %@", properties.fileSize)
            }

            description += ")"
        } else {
            description = String(format: NSLocalizedString("%@ Audio", comment: "Format description without details"), properties.fileExtension.uppercased())

            if !properties.sampleRate.isEmpty || !properties.channels.isEmpty || !properties.fileSize.isEmpty {
                description += " ("

                if !properties.sampleRate.isEmpty {
                    description += properties.sampleRate

                    if !properties.channels.isEmpty || !properties.fileSize.isEmpty {
                        description += ", "
                    }
                }

                if !properties.channels.isEmpty {
                    description += properties.channels

                    if !properties.fileSize.isEmpty {
                        description += ", "
                    }
                }

                if !properties.fileSize.isEmpty {
                    description += properties.fileSize
                }

                description += ")"
            }
        }

        if !properties.codec.isEmpty {
            description += " [\(properties.codec)]"
        }

        return description
    }

    private func removeDuplicateFormats(_ formats: [DownloadFormat]) -> [DownloadFormat] {
        var uniqueFormats: [DownloadFormat] = []
        var seenDescriptions = Set<String>()

        for format in formats where !seenDescriptions.contains(format.description) {
            uniqueFormats.append(format)
            seenDescriptions.insert(format.description)
        }

        return uniqueFormats
    }

    public func downloadAudio(from url: String, formatId: String, outputTitle: String? = nil) async throws {
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

        guard let currentLibrary = libraryManager.currentLibrary else {
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


    public func isPlaylistURL(_ url: String) -> Bool {
        let playlistPatterns = [
            "list=",
            "/playlist",
            "/sets/",
            "soundcloud.com/.*/.*/sets/",
            "youtube.com/playlist",
            "youtu.be/.*list="
        ]

        return playlistPatterns.contains { pattern in
            url.range(of: pattern, options: .regularExpression) != nil
        }
    }

    public func fetchPlaylistInfo(from url: String) async throws -> PlaylistInfo {
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
                return try parsePlaylistFromOutput(result.standardOutput, originalURL: url)
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

    private func parsePlaylistFromOutput(_ output: String, originalURL: String) throws -> PlaylistInfo {
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var items: [PlaylistItem] = []
        var playlistTitle = "Unknown Playlist"
        var playlistDescription = ""
        var uploader = "Unknown"

        for line in lines {
            guard let data = line.data(using: .utf8) else { continue }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let entryType = json["_type"] as? String, entryType == "url" {
                        let videoId = json["id"] as? String ?? ""
                        let title = json["title"] as? String ?? "Unknown Title"
                        let videoUrl = json["url"] as? String ?? ""
                        let duration = json["duration_string"] as? String ?? ""

                        let thumbnailUrl = "https://img.youtube.com/vi/\(videoId)/default.jpg"

                        let item = PlaylistItem(
                            videoId: videoId,
                            title: title,
                            url: videoUrl,
                            duration: duration,
                            thumbnailUrl: thumbnailUrl
                        )
                        items.append(item)
                    }
                    else if json["_type"] == nil || json["_type"] as? String == "playlist" {
                        if let title = json["title"] as? String {
                            playlistTitle = title
                        }
                        if let desc = json["description"] as? String {
                            playlistDescription = desc
                        }
                        if let uploaderName = json["uploader"] as? String {
                            uploader = uploaderName
                        } else if let channelName = json["channel"] as? String {
                            uploader = channelName
                        }
                    }
                }
            } catch {
                continue
            }
        }

        if items.isEmpty {
            throw DownloadError.playlistFetchFailed
        }

        return PlaylistInfo(
            id: extractPlaylistId(from: originalURL),
            title: playlistTitle,
            description: playlistDescription,
            uploader: uploader,
            videoCount: items.count,
            items: items
        )
    }

    private func extractPlaylistId(from url: String) -> String {
        if let range = url.range(of: "list=([^&]+)", options: .regularExpression) {
            let listPart = String(url[range])
            return String(listPart.dropFirst(5))
        }
        return "unknown"
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

    public func downloadPlaylist(
        from url: String,
        progressCallback: @escaping (PlaylistDownloadProgress) -> Void
    ) async throws {
        print(NSLocalizedString("Starting playlist download, URL: %@", comment: "Log message when starting playlist download"), url)

        try Task.checkCancellation()
        let playlistInfo = try await fetchPlaylistInfo(from: url)
        try await downloadPlaylistItems(playlistInfo.items, progressCallback: progressCallback)
    }

    public func downloadPlaylistItems(
        _ items: [PlaylistItem],
        maxConcurrentDownloads: Int = 3,
        progressCallback: @escaping (PlaylistDownloadProgress) -> Void
    ) async throws {
        if items.isEmpty {
            throw DownloadError.playlistDownloadFailed(NSLocalizedString("Playlist is empty", comment: "Error when playlist has no downloadable items"))
        }

        var completed = 0
        var failed = 0
        var started = 0
        var nextIndex = 0
        let totalCount = items.count
        let concurrentLimit = max(1, min(maxConcurrentDownloads, totalCount))
        let outputTitles = outputTitles(forPlaylistItems: items)

        try await withThrowingTaskGroup(of: (PlaylistItem, Bool).self) { group in
            while nextIndex < concurrentLimit {
                let item = items[nextIndex]
                let outputTitle = outputTitles[nextIndex]
                nextIndex += 1
                started += 1

                let progress = PlaylistDownloadProgress(
                    currentIndex: started,
                    totalCount: totalCount,
                    currentTitle: item.title,
                    completed: completed,
                    failed: failed
                )

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

            while let (item, succeeded) = try await group.next() {
                if succeeded {
                    completed += 1
                    print(String(format: NSLocalizedString("Successfully downloaded: %@", comment: "Log message when item downloaded successfully"), item.title))
                } else {
                    failed += 1
                }

                let progress = PlaylistDownloadProgress(
                    currentIndex: min(started, totalCount),
                    totalCount: totalCount,
                    currentTitle: item.title,
                    completed: completed,
                    failed: failed
                )

                await MainActor.run {
                    progressCallback(progress)
                }

                try Task.checkCancellation()

                if nextIndex < totalCount {
                    let nextItem = items[nextIndex]
                    let nextOutputTitle = outputTitles[nextIndex]
                    nextIndex += 1
                    started += 1

                    let nextProgress = PlaylistDownloadProgress(
                        currentIndex: started,
                        totalCount: totalCount,
                        currentTitle: nextItem.title,
                        completed: completed,
                        failed: failed
                    )

                    await MainActor.run {
                        progressCallback(nextProgress)
                    }

                    group.addTask {
                        do {
                            try await self.downloadAudio(from: nextItem.url, formatId: "bestaudio", outputTitle: nextOutputTitle)
                            return (nextItem, true)
                        } catch is CancellationError {
                            throw CancellationError()
                        } catch {
                            print(String(format: NSLocalizedString("Failed to download: %@ - Error: %@", comment: "Log message when item download fails"), nextItem.title, error.localizedDescription))
                            return (nextItem, false)
                        }
                    }
                }
            }
        }

        try Task.checkCancellation()
        let finalProgress = PlaylistDownloadProgress(
            currentIndex: totalCount,
            totalCount: totalCount,
            currentTitle: NSLocalizedString("Completed", comment: "Download completion status"),
            completed: completed,
            failed: failed
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
