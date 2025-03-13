//
//  DownloadManager.swift
//  MacMusicPlayer
//
//  Created by X on 2024/09/18.
//

import Foundation
import AppKit

/// A manager class responsible for handling music download operations from various online sources.
/// This class provides functionality to fetch available audio formats and download audio files.
public class DownloadManager {
    /// Shared singleton instance of the DownloadManager.
    public static let shared = DownloadManager()
    
    /// Represents an available audio format for download.
    public struct DownloadFormat {
        /// The format identifier used by yt-dlp.
        public let formatId: String
        /// The file extension of the audio format (e.g., mp3, m4a).
        public let fileExtension: String
        /// A human-readable description of the format.
        public let description: String
        /// The bitrate of the audio format (e.g., 128kbps).
        public let bitrate: String
        /// The sample rate of the audio format (e.g., 44kHz).
        public let sampleRate: String
        /// The channel configuration of the audio format (e.g., stereo, mono).
        public let channels: String
        /// The estimated file size of the audio format.
        public let fileSize: String
        
        /// Initializes a new DownloadFormat instance.
        /// - Parameters:
        ///   - formatId: The format identifier used by yt-dlp.
        ///   - fileExtension: The file extension of the audio format.
        ///   - description: A human-readable description of the format.
        ///   - bitrate: The bitrate of the audio format (optional).
        ///   - sampleRate: The sample rate of the audio format (optional).
        ///   - channels: The channel configuration of the audio format (optional).
        ///   - fileSize: The estimated file size of the audio format (optional).
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
    
    /// Errors that can occur during the download process.
    public enum DownloadError: Error {
        /// Failed to fetch available formats.
        case formatFetchFailed
        /// Download failed with a specific error message.
        case downloadFailed(String)
        /// The provided URL is invalid.
        case invalidURL
        /// The yt-dlp tool was not found on the system.
        case ytDlpNotFound
        /// The ffmpeg tool was not found on the system.
        case ffmpegNotFound
        /// Failed to fetch the video title.
        case titleFetchFailed
        
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
            }
        }
    }
    
    /// Represents the properties of an audio format for description generation.
    private struct FormatDescriptionProperties {
        let fileExtension: String
        let bitrate: String
        let sampleRate: String
        let channels: String
        let fileSize: String
        let codec: String
    }
    
    // 检查 ffmpeg 是否可用
    private func checkFFmpegAvailability() throws -> String {
        // 使用 which 命令查找 ffmpeg 路径
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
            
            // 如果 which 命令找不到，检查常见路径
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
    
    // 检查 yt-dlp 是否可用
    private func checkYtDlpAvailability() throws -> String {
        // 使用 which 命令查找 yt-dlp 路径
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
            
            // 如果 which 命令找不到，检查常见路径
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
    
    // 获取视频标题
    private func getVideoTitle(from url: String, ytDlpPath: String) async throws -> String {
        let task = Process()
        task.launchPath = ytDlpPath
        task.arguments = [
            "--get-title",
            url
        ]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            task.launch()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let title = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !title.isEmpty {
                    // 替换文件名中不允许的字符
                    let invalidChars = CharacterSet(charactersIn: "\\/:*?\"<>|")
                    let safeTitle = title.components(separatedBy: invalidChars).joined(separator: "_")
                    return safeTitle
                }
            }
            
            throw DownloadError.titleFetchFailed
        } catch {
            print(NSLocalizedString("Error getting video title: %@", comment: "Log message when getting video title fails"), error)
            throw DownloadError.titleFetchFailed
        }
    }
    
    /// Fetches available audio formats from a given URL.
    /// - Parameter url: The URL of the video to fetch formats from.
    /// - Returns: An array of available audio formats.
    /// - Throws: A `DownloadError` if the operation fails.
    public func fetchAvailableFormats(from url: String) async throws -> [DownloadFormat] {
        print(NSLocalizedString("Getting available formats, URL: %@", comment: "Log message when fetching formats"), url)
        
        // 检查 URL 是否有效
        guard URL(string: url) != nil else {
            throw DownloadError.invalidURL
        }
        
        // 检查 yt-dlp 是否可用
        let ytDlpPath = try checkYtDlpAvailability()
        
        // 检查 ffmpeg 是否可用
        let ffmpegPath = try checkFFmpegAvailability()
        
        // 使用 yt-dlp 获取可用格式
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
                
                // 解析输出，提取音频格式
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
            
            // 如果出错，返回一些预定义的格式选项
            return createDefaultFormats()
        }
    }
    
    /// Creates a list of default audio formats when format fetching fails.
    /// - Returns: An array of default audio formats.
    private func createDefaultFormats() -> [DownloadFormat] {
        return [
            DownloadFormat(
                formatId: "bestaudio", 
                fileExtension: "mp3", 
                description: NSLocalizedString("🎵 Best Quality (Auto Select)", comment: "Format description for best audio quality")
            ),
            DownloadFormat(
                formatId: "140", 
                fileExtension: "m4a", 
                description: NSLocalizedString("🎵 M4A Audio (128kbps, 44kHz, stereo, 3.5MiB) [AAC]", comment: "Predefined format description"),
                bitrate: "128kbps",
                sampleRate: "44kHz",
                channels: NSLocalizedString("stereo", comment: "Audio channel type"),
                fileSize: "3.5MiB"
            ),
            DownloadFormat(
                formatId: "251", 
                fileExtension: "webm", 
                description: NSLocalizedString("🎵 WebM Audio (160kbps, 48kHz, stereo, 3.2MiB) [Opus]", comment: "Predefined format description"),
                bitrate: "160kbps",
                sampleRate: "48kHz",
                channels: NSLocalizedString("stereo", comment: "Audio channel type"),
                fileSize: "3.2MiB"
            )
        ]
    }
    
    /// Parses the output from yt-dlp to extract available audio formats.
    /// - Parameter output: The output string from yt-dlp.
    /// - Returns: An array of parsed audio formats.
    private func parseFormatsFromOutput(_ output: String) throws -> [DownloadFormat] {
        var formats: [DownloadFormat] = []
        
        // 添加默认的最佳音频选项
        formats.append(DownloadFormat(
            formatId: "bestaudio", 
            fileExtension: "mp3", 
            description: NSLocalizedString("🎵 Best Quality (Auto Select)", comment: "Format description for best audio quality")
        ))
        
        // 解析输出中的音频格式
        let lines = output.components(separatedBy: .newlines)
        for line in lines where line.contains("audio only") {
            if let format = parseAudioFormatLine(line) {
                formats.append(format)
            }
        }
        
        // 如果没有找到音频格式，至少返回一些预定义的选项
        if formats.count <= 1 {
            formats.append(contentsOf: createDefaultFormats().dropFirst())
        }
        
        // 确保没有重复的描述
        return removeDuplicateFormats(formats)
    }
    
    /// Parses a single line from yt-dlp output to extract audio format information.
    /// - Parameter line: A line from yt-dlp output containing audio format information.
    /// - Returns: A DownloadFormat object if parsing succeeds, nil otherwise.
    private func parseAudioFormatLine(_ line: String) -> DownloadFormat? {
        let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard components.count >= 2 else { return nil }
        
        let formatId = components[0]
        
        // 提取文件扩展名
        var fileExtension = "mp3" // 默认
        
        if line.contains("m4a") {
            fileExtension = "m4a"
        } else if line.contains("webm") {
            fileExtension = "webm"
        } else if line.contains("opus") {
            fileExtension = "opus"
        }
        
        // 提取比特率信息
        var bitrate = ""
        if let bitrateRange = line.range(of: "\\d+k", options: .regularExpression) {
            bitrate = String(line[bitrateRange])
        }
        
        // 提取采样率信息
        var sampleRate = ""
        if let sampleRateRange = line.range(of: "\\d+\\.?\\d*kHz|\\d+Hz|\\d+k\\s", options: .regularExpression) {
            sampleRate = String(line[sampleRateRange]).trimmingCharacters(in: .whitespaces)
        } else if line.contains("44k") {
            sampleRate = "44kHz"
        } else if line.contains("48k") {
            sampleRate = "48kHz"
        }
        
        // 提取声道信息
        var channels = ""
        if line.contains("stereo") || line.contains("2.0") {
            channels = NSLocalizedString("stereo", comment: "Audio channel type")
        } else if line.contains("mono") || line.contains("1.0") {
            channels = NSLocalizedString("mono", comment: "Audio channel type")
        } else if line.contains("5.1") {
            channels = NSLocalizedString("5.1 channels", comment: "Audio channel type")
        } else {
            // 默认假设为立体声
            channels = NSLocalizedString("stereo", comment: "Audio channel type")
        }
        
        // 提取文件大小信息
        var fileSize = ""
        if let fileSizeRange = line.range(of: "\\d+\\.?\\d*[KMG]iB", options: .regularExpression) {
            fileSize = String(line[fileSizeRange])
        }
        
        // 确定编解码器
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
        
        // 创建格式描述属性
        let properties = FormatDescriptionProperties(
            fileExtension: fileExtension,
            bitrate: bitrate,
            sampleRate: sampleRate,
            channels: channels,
            fileSize: fileSize,
            codec: codec
        )
        
        // 创建格式描述
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
    
    /// Creates a human-readable description for an audio format.
    /// - Parameter properties: The properties of the audio format.
    /// - Returns: A formatted description string.
    private func createFormatDescription(properties: FormatDescriptionProperties) -> String {
        var description = ""
        
        if !properties.bitrate.isEmpty {
            description = String(format: NSLocalizedString("🎵 %@ Audio (%@", comment: "Format description with bitrate"), properties.fileExtension.uppercased(), properties.bitrate)
            
            if !properties.sampleRate.isEmpty {
                description += String(format: ", %@", properties.sampleRate)
            }
            
            description += String(format: ", %@", properties.channels)
            
            if !properties.fileSize.isEmpty {
                description += String(format: ", %@", properties.fileSize)
            }
            
            description += ")"
        } else {
            description = String(format: NSLocalizedString("🎵 %@ Audio", comment: "Format description without details"), properties.fileExtension.uppercased())
            
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
        
        // 添加编解码器信息
        if !properties.codec.isEmpty {
            description += " [\(properties.codec)]"
        }
        
        return description
    }
    
    /// Removes duplicate formats based on their descriptions.
    /// - Parameter formats: The array of formats to deduplicate.
    /// - Returns: An array of formats with unique descriptions.
    private func removeDuplicateFormats(_ formats: [DownloadFormat]) -> [DownloadFormat] {
        var uniqueFormats: [DownloadFormat] = []
        var seenDescriptions = Set<String>()
        
        for format in formats where !seenDescriptions.contains(format.description) {
            uniqueFormats.append(format)
            seenDescriptions.insert(format.description)
        }
        
        return uniqueFormats
    }
    
    /// Downloads audio from a given URL using the specified format.
    /// - Parameters:
    ///   - url: The URL of the video to download audio from.
    ///   - formatId: The format identifier of the audio format to download.
    /// - Throws: A `DownloadError` if the download operation fails.
    public func downloadAudio(from url: String, formatId: String) async throws {
        print(NSLocalizedString("Starting audio download, URL: %@, Format ID: %@", comment: "Log message when starting download"), url, formatId)
        
        // 检查 URL 是否有效
        guard URL(string: url) != nil else {
            throw DownloadError.invalidURL
        }
        
        // 检查 yt-dlp 是否可用
        let ytDlpPath = try checkYtDlpAvailability()
        
        // 检查 ffmpeg 是否可用
        let ffmpegPath = try checkFFmpegAvailability()
        
        // 获取视频标题
        let videoTitle = try await getVideoTitle(from: url, ytDlpPath: ytDlpPath)
        print(NSLocalizedString("Video title: %@", comment: "Log message showing video title"), videoTitle)
        
        // 使用下载目录
        let musicPath = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask)[0].path
        let outputFile = "\(musicPath)/\(videoTitle).%(ext)s"
        print(NSLocalizedString("Downloading to file: %@", comment: "Log message showing output file"), outputFile)
        
        // 使用 yt-dlp 直接下载音频
        let task = Process()
        task.launchPath = ytDlpPath
        task.arguments = [
            "--ffmpeg-location", ffmpegPath,
            "-f", formatId,
            "--extract-audio",
            "--audio-format", "mp3",
            "--audio-quality", "0",
            "-o", outputFile,
            url
        ]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        let errorPipe = Pipe()
        task.standardError = errorPipe
        
        do {
            print(NSLocalizedString("Executing download command...", comment: "Log message when executing download command"))
            task.launch()
            
            // 创建一个字符串来存储错误输出
            var errorOutput = ""
            
            // 异步读取输出，避免阻塞
            DispatchQueue.global(qos: .background).async {
                let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8)
                if let output = output, !output.isEmpty {
                    print(NSLocalizedString("Download output: %@", comment: "Log message showing download output"), output)
                }
                
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                if let error = String(data: errorData, encoding: .utf8), !error.isEmpty {
                    errorOutput = error
                    print(NSLocalizedString("Download error output: %@", comment: "Log message showing download error"), error)
                }
            }
            
            print(NSLocalizedString("Waiting for download to complete...", comment: "Log message when waiting for download"))
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                print(NSLocalizedString("Download successful", comment: "Log message when download succeeds"))
                
                // 通知播放器刷新音乐库
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshMusicLibrary"), object: nil)
                }
            } else {
                print(NSLocalizedString("Download failed, exit status: %d", comment: "Log message when download fails"), task.terminationStatus)
                throw DownloadError.downloadFailed(errorOutput)
            }
        } catch let error as DownloadError {
            throw error
        } catch {
            print(NSLocalizedString("Error during download: %@", comment: "Log message when download error occurs"), error)
            throw DownloadError.downloadFailed(error.localizedDescription)
        }
    }
} 
