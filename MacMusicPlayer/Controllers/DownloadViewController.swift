//
//  DownloadViewController.swift
//  MacMusicPlayer
//
//  Created by X on 2024/09/18.
//
import Cocoa
import AppKit

class DownloadViewController: NSViewController {
    // MARK: - UI Components
    private let urlTextField = NSTextField()
    private let detectButton = NSButton()
    private let statusLabel = NSTextField()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let progressIndicator = NSProgressIndicator()
    private let versionInfoLabel = NSTextField()
    private let githubLinkButton = NSButton()
    private let backgroundView = NSVisualEffectView()
    private let tableBackgroundView = NSVisualEffectView()
    private let libraryPopup = NSPopUpButton()
    private let libraryLabel = NSTextField()
    
    // 添加分页按钮
    private let nextPageButton = NSButton()
    
    // MARK: - Properties
    private var formats: [DownloadManager.DownloadFormat] = []
    private var selectedFormat: DownloadManager.DownloadFormat?
    private var ytDlpVersion: String = ""
    private var ffmpegVersion: String = ""
    private var isYtDlpInstalled: Bool = false
    private var isFfmpegInstalled: Bool = false
    private var libraryManager = LibraryManager()
    
    // 搜索相关属性
    private var searchResults: [YTSearchManager.SearchResult.VideoItem] = []
    private var isSearchMode: Bool = false
    private var currentNextPageToken: String? = nil
    private var lastSearchKeyword: String = ""  // 保存最后一次搜索关键词
    private let ytSearchManager = YTSearchManager.shared
    private let configManager = ConfigManager.shared
    
    // UI相关约束
    private var nextPageButtonLeadingConstraint: NSLayoutConstraint?
    
    // 添加一个新的属性来跟踪哪个视频行处于展开状态
    private var expandedVideoRow: Int? = nil
    private var formatOptions: [FormatOption] = []
    
    // 格式选项结构
    struct FormatOption {
        let title: String
        let formatId: String
        let videoItem: YTSearchManager.SearchResult.VideoItem
    }
    
    // MARK: - Lifecycle
    override func loadView() {
        // Set an appropriate initial size, consistent with the compact height used later
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 140))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        checkDependencies()
        
        // 添加文本框变化事件监听
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textFieldDidChange(_:)),
            name: NSControl.textDidChangeNotification,
            object: urlTextField
        )
        
        // 添加配置更新的通知监听
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConfigUpdated),
            name: NSNotification.Name("ConfigUpdated"),
            object: nil
        )
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        // Ensure window becomes the focus window
        if let window = view.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            
            // Set focus to URL input field
            self.view.window?.makeFirstResponder(urlTextField)
        }
        
        updateLibraryPopup()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.wantsLayer = true
        
        if let window = view.window {
            window.title = NSLocalizedString("Download Music", comment: "")
            window.titleVisibility = .visible
            window.titlebarAppearsTransparent = false
        }
        
        setupLibrarySelector()
        setupURLField()
        setupDetectButton()
        setupStatusLabel()
        setupTableView()
        setupProgressIndicator()
        setupVersionInfo()
        setupGithubLink()
        setupNextPageButton()
    }
    
    private func setupURLField() {
        urlTextField.translatesAutoresizingMaskIntoConstraints = false
        urlTextField.placeholderString = NSLocalizedString("Enter video URL or search keyword", comment: "")
        urlTextField.font = NSFont.systemFont(ofSize: 13)
        urlTextField.bezelStyle = .roundedBezel
        urlTextField.focusRingType = .exterior
        urlTextField.target = self
        urlTextField.action = #selector(detectOrSearch)
        view.addSubview(urlTextField)
        
        NSLayoutConstraint.activate([
            urlTextField.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            urlTextField.leadingAnchor.constraint(equalTo: libraryPopup.trailingAnchor, constant: 8),
            urlTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -110),
            urlTextField.heightAnchor.constraint(equalToConstant: 28)
        ])
    }
    
    private func setupDetectButton() {
        detectButton.translatesAutoresizingMaskIntoConstraints = false
        detectButton.title = NSLocalizedString("Search", comment: "") // default is "Search"
        detectButton.bezelStyle = .rounded
        detectButton.target = self
        detectButton.action = #selector(detectOrSearch)
        detectButton.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        detectButton.contentTintColor = .white
        detectButton.wantsLayer = true
        
        if #available(macOS 11.0, *) {
            detectButton.bezelColor = NSColor.controlAccentColor
        } else {
            detectButton.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        }
        
        view.addSubview(detectButton)
        
        NSLayoutConstraint.activate([
            detectButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            detectButton.leadingAnchor.constraint(equalTo: urlTextField.trailingAnchor, constant: 8),
            detectButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            detectButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }
    
    private func setupNextPageButton() {
        nextPageButton.translatesAutoresizingMaskIntoConstraints = false
        nextPageButton.title = NSLocalizedString("View more", comment: "")
        nextPageButton.bezelStyle = .inline
        nextPageButton.isBordered = false
        nextPageButton.target = self
        nextPageButton.action = #selector(loadNextPage)
        nextPageButton.font = NSFont.systemFont(ofSize: 12)
        nextPageButton.contentTintColor = NSColor.linkColor
        nextPageButton.isHidden = true // 初始状态隐藏
        
        // 添加鼠标悬停效果
        let trackingArea = NSTrackingArea(
            rect: NSRect.zero,
            options: [.inVisibleRect, .activeAlways, .mouseEnteredAndExited],
            owner: self,
            userInfo: ["button": "nextPage"]
        )
        nextPageButton.addTrackingArea(trackingArea)
        
        view.addSubview(nextPageButton)
        
        // 修改为右对齐，不再使用相对于statusLabel的位置
        nextPageButtonLeadingConstraint = nil
        
        NSLayoutConstraint.activate([
            nextPageButton.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            nextPageButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            nextPageButton.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    private func setupLibrarySelector() {
        libraryLabel.translatesAutoresizingMaskIntoConstraints = false
        libraryLabel.isEditable = false
        libraryLabel.isBordered = false
        libraryLabel.backgroundColor = .clear
        libraryLabel.alignment = .right
        libraryLabel.font = NSFont.systemFont(ofSize: 13)
        libraryLabel.textColor = NSColor.labelColor
        libraryLabel.stringValue = ""
        libraryLabel.isHidden = true
        view.addSubview(libraryLabel)
        
        libraryPopup.translatesAutoresizingMaskIntoConstraints = false
        libraryPopup.target = self
        libraryPopup.action = #selector(handleLibrarySelection(_:))
        view.addSubview(libraryPopup)
        
        NSLayoutConstraint.activate([
            libraryLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            libraryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            libraryLabel.heightAnchor.constraint(equalToConstant: 28),
            
            libraryPopup.centerYAnchor.constraint(equalTo: libraryLabel.centerYAnchor),
            libraryPopup.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            libraryPopup.widthAnchor.constraint(equalToConstant: 120),
            libraryPopup.heightAnchor.constraint(equalToConstant: 28)
        ])
        
        updateLibraryPopup()
    }
    
    private func updateLibraryPopup() {
        libraryPopup.removeAllItems()
        
        for library in libraryManager.libraries {
            libraryPopup.addItem(withTitle: library.name)
        }
        
        if let currentLibrary = libraryManager.currentLibrary,
           let index = libraryManager.libraries.firstIndex(where: { $0.id == currentLibrary.id }) {
            libraryPopup.selectItem(at: index)
        }
    }
    
    @objc private func handleLibrarySelection(_ sender: NSPopUpButton) {
        let selectedIndex = sender.indexOfSelectedItem
        guard selectedIndex >= 0 && selectedIndex < libraryManager.libraries.count else { return }
        
        let selectedLibrary = libraryManager.libraries[selectedIndex]
        libraryManager.switchLibrary(id: selectedLibrary.id)
    }
    
    private func setupStatusLabel() {
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.backgroundColor = .clear
        statusLabel.alignment = .left
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.textColor = NSColor.secondaryLabelColor
        statusLabel.stringValue = ""
        view.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: urlTextField.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            statusLabel.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    private func setupProgressIndicator() {
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isIndeterminate = true
        progressIndicator.isHidden = true
        view.addSubview(progressIndicator)
        
        NSLayoutConstraint.activate([
            progressIndicator.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            progressIndicator.trailingAnchor.constraint(equalTo: statusLabel.trailingAnchor),
            progressIndicator.widthAnchor.constraint(equalToConstant: 16),
            progressIndicator.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    private func setupTableView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        // Use translucent material background
        tableBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        tableBackgroundView.material = .popover
        tableBackgroundView.state = .active
        tableBackgroundView.wantsLayer = true
        tableBackgroundView.layer?.cornerRadius = 8
        tableBackgroundView.layer?.masksToBounds = true
        view.addSubview(tableBackgroundView)
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            tableBackgroundView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            tableBackgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            tableBackgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            tableBackgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50)
        ])
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: tableBackgroundView.topAnchor, constant: 0),
            scrollView.leadingAnchor.constraint(equalTo: tableBackgroundView.leadingAnchor, constant: 0),
            scrollView.trailingAnchor.constraint(equalTo: tableBackgroundView.trailingAnchor, constant: 0),
            scrollView.bottomAnchor.constraint(equalTo: tableBackgroundView.bottomAnchor, constant: 0)
        ])
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.headerView = nil
        tableView.allowsMultipleSelection = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 40
        tableView.selectionHighlightStyle = .none
        tableView.backgroundColor = .clear
        tableView.enclosingScrollView?.drawsBackground = false
        tableView.gridStyleMask = [] 
        tableView.usesAlternatingRowBackgroundColors = false
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("FormatColumn"))
        column.width = scrollView.frame.width - 20
        tableView.addTableColumn(column)
        
        scrollView.documentView = tableView
        
        // Hide background view and table in initial state
        tableBackgroundView.isHidden = true
        scrollView.isHidden = true
    }
    
    private func setupVersionInfo() {
        versionInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        versionInfoLabel.isEditable = false
        versionInfoLabel.isBordered = false
        versionInfoLabel.backgroundColor = .clear
        versionInfoLabel.alignment = .left
        versionInfoLabel.font = NSFont.systemFont(ofSize: 10)
        versionInfoLabel.textColor = NSColor.tertiaryLabelColor
        view.addSubview(versionInfoLabel)
        
        NSLayoutConstraint.activate([
            versionInfoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            versionInfoLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
            versionInfoLabel.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    private func setupGithubLink() {
        githubLinkButton.translatesAutoresizingMaskIntoConstraints = false
        githubLinkButton.title = "GitHub"
        githubLinkButton.bezelStyle = .inline
        githubLinkButton.isBordered = false
        githubLinkButton.target = self
        githubLinkButton.action = #selector(openGithub)
        githubLinkButton.font = NSFont.systemFont(ofSize: 10)
        githubLinkButton.contentTintColor = NSColor.linkColor
        
        let trackingArea = NSTrackingArea(
            rect: NSRect.zero,
            options: [.inVisibleRect, .activeAlways, .mouseEnteredAndExited],
            owner: self,
            userInfo: ["button": "github"]
        )
        githubLinkButton.addTrackingArea(trackingArea)
        
        view.addSubview(githubLinkButton)
        
        NSLayoutConstraint.activate([
            githubLinkButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            githubLinkButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
            githubLinkButton.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    // MARK: - Mouse Tracking for GitHub Link
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if let userInfo = event.trackingArea?.userInfo as? [String: String] {
            if userInfo["button"] == "github" {
                let attributedString = NSMutableAttributedString(string: githubLinkButton.title)
                attributedString.addAttribute(.underlineStyle, 
                                             value: NSUnderlineStyle.single.rawValue, 
                                             range: NSRange(location: 0, length: attributedString.length))
                githubLinkButton.attributedTitle = attributedString
            } else if userInfo["button"] == "nextPage" {
                let attributedString = NSMutableAttributedString(string: nextPageButton.title)
                attributedString.addAttribute(.underlineStyle, 
                                             value: NSUnderlineStyle.single.rawValue, 
                                             range: NSRange(location: 0, length: attributedString.length))
                nextPageButton.attributedTitle = attributedString
            }
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if let userInfo = event.trackingArea?.userInfo as? [String: String] {
            if userInfo["button"] == "github" {
                githubLinkButton.attributedTitle = NSAttributedString(string: githubLinkButton.title)
            } else if userInfo["button"] == "nextPage" {
                nextPageButton.attributedTitle = NSAttributedString(string: nextPageButton.title)
            }
        }
    }
    
    // MARK: - Dependencies Check
    private func checkDependencies() {
        isYtDlpInstalled = false
        isFfmpegInstalled = false
        
        // Shell script direct detection tool
        let script = """
        #!/bin/bash
        export PATH=$PATH:/usr/local/bin:/opt/homebrew/bin:/opt/local/bin:/usr/bin
        
        # Check yt-dlp
        if command -v yt-dlp &> /dev/null; then
            echo "YT_DLP_INSTALLED=true"
            echo "YT_DLP_VERSION=$(yt-dlp --version 2>/dev/null)"
        else
            echo "YT_DLP_INSTALLED=false"
        fi
        
        # Check ffmpeg
        if command -v ffmpeg &> /dev/null; then
            echo "FFMPEG_INSTALLED=true"
            FFMPEG_VERSION=$(ffmpeg -version 2>/dev/null | head -n1 | awk '{print $3}')
            echo "FFMPEG_VERSION=$FFMPEG_VERSION"
        else
            echo "FFMPEG_INSTALLED=false"
        fi
        """
        
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", script]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Parse output
                let lines = output.components(separatedBy: "\n")
                for line in lines {
                    if line.starts(with: "YT_DLP_INSTALLED=") {
                        isYtDlpInstalled = line.contains("true")
                    } else if line.starts(with: "YT_DLP_VERSION=") {
                        if let version = line.components(separatedBy: "=").last {
                            ytDlpVersion = version.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    } else if line.starts(with: "FFMPEG_INSTALLED=") {
                        isFfmpegInstalled = line.contains("true")
                    } else if line.starts(with: "FFMPEG_VERSION=") {
                        if let version = line.components(separatedBy: "=").last {
                            ffmpegVersion = version.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                }
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.updateVersionInfo()
                }
            }
        } catch {
            print("Error checking dependencies: \(error)")
            // If script execution fails, try alternative method
            checkDependenciesWithDirectCommands()
        }
    }
    
    private func checkDependenciesWithDirectCommands() {
        checkYtDlp()
        checkFfmpeg()
    }
    
    private func checkYtDlp() {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = ["which", "yt-dlp"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                isYtDlpInstalled = true
                
                // Get version
                let versionTask = Process()
                versionTask.launchPath = "/usr/bin/env"
                versionTask.arguments = ["yt-dlp", "--version"]
                
                let versionPipe = Pipe()
                versionTask.standardOutput = versionPipe
                
                try versionTask.run()
                versionTask.waitUntilExit()
                
                if versionTask.terminationStatus == 0 {
                    let data = versionPipe.fileHandleForReading.readDataToEndOfFile()
                    if let version = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                        ytDlpVersion = version
                    } else {
                        ytDlpVersion = "已安装"
                    }
                } else {
                    ytDlpVersion = "已安装"
                }
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.updateVersionInfo()
            }
        } catch {
            print("Error checking yt-dlp: \(error)")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.updateVersionInfo()
            }
        }
    }
    
    private func checkFfmpeg() {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = ["which", "ffmpeg"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                isFfmpegInstalled = true
                
                let versionTask = Process()
                versionTask.launchPath = "/usr/bin/env"
                versionTask.arguments = ["ffmpeg", "-version"]
                
                let versionPipe = Pipe()
                versionTask.standardOutput = versionPipe
                
                try versionTask.run()
                versionTask.waitUntilExit()
                
                if versionTask.terminationStatus == 0 {
                    let data = versionPipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        if let versionLine = output.components(separatedBy: "\n").first,
                           let version = versionLine.components(separatedBy: " version ").last?.components(separatedBy: " ").first {
                            ffmpegVersion = version
                        } else {
                            ffmpegVersion = "已安装"
                        }
                    } else {
                        ffmpegVersion = "已安装"
                    }
                } else {
                    ffmpegVersion = "已安装"
                }
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.updateVersionInfo()
            }
        } catch {
            print("Error checking ffmpeg: \(error)")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.updateVersionInfo()
            }
        }
    }
    
    private func updateVersionInfo() {
        var infoText = ""
        
        if isYtDlpInstalled {
            infoText += "yt-dlp: v\(ytDlpVersion)"
        } else {
            infoText += "yt-dlp: " + NSLocalizedString("Not installed", comment: "")
        }
        
        infoText += " | "
        
        if isFfmpegInstalled {
            infoText += "ffmpeg: v\(ffmpegVersion)"
        } else {
            infoText += "ffmpeg: " + NSLocalizedString("Not installed", comment: "")
        }
        
        versionInfoLabel.stringValue = infoText
        
        // If dependencies are missing, show a prompt
        if !isYtDlpInstalled || !isFfmpegInstalled {
            statusLabel.stringValue = NSLocalizedString("Please install missing dependencies", comment: "")
            statusLabel.textColor = NSColor.systemRed
        } else {
            statusLabel.stringValue = ""
        }
    }
    
    // MARK: - Input Field Change
    @objc private func textFieldDidChange(_ notification: Notification) {
        if let textField = notification.object as? NSTextField, textField == urlTextField {
            updateButtonBasedOnInput()
        }
    }
    
    private func updateButtonBasedOnInput() {
        let text = urlTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 简单的URL验证
        if text.hasPrefix("http://") || text.hasPrefix("https://") {
            detectButton.title = NSLocalizedString("Detect", comment: "")
            isSearchMode = false
        } else {
            detectButton.title = NSLocalizedString("Search", comment: "")
            isSearchMode = true
        }
    }
    
    // MARK: - Config Updated
    @objc private func handleConfigUpdated() {
        // 当配置更新时，可以在这里做一些事情，例如清除之前的搜索结果
        searchResults = []
        if isSearchMode {
            tableView.reloadData()
        }
    }
    
    // MARK: - Actions
    @objc private func detectOrSearch() {
        let input = urlTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if input.isEmpty {
            statusLabel.stringValue = NSLocalizedString("Please enter a URL or search keyword", comment: "")
            statusLabel.textColor = NSColor.systemRed
            return
        }
        
        if isSearchMode {
            performSearch(keyword: input)
        } else {
            detectFormats()
        }
    }
    
    private func performSearch(keyword: String, pageToken: String? = nil) {
        // 验证配置
        if !configManager.isConfigValid {
            showConfigRequiredPrompt()
            return
        }
        
        // 更新最后搜索的关键词
        lastSearchKeyword = keyword
        
        // 开始搜索前的UI准备
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            progressIndicator.isHidden = false
            progressIndicator.startAnimation(nil)
            statusLabel.stringValue = pageToken == nil ? 
                NSLocalizedString("Searching...", comment: "") : 
                NSLocalizedString("Load more results...", comment: "")
            statusLabel.textColor = NSColor.secondaryLabelColor
        })
        
        // 如果是新搜索(没有pageToken)，清空旧结果和上一次的pageToken
        if pageToken == nil {
            searchResults = []
            currentNextPageToken = nil  // 重置token
            nextPageButton.isHidden = true  // 隐藏下一页按钮直到确认有更多结果
            tableView.reloadData()
        }
        
        // 执行搜索
        ytSearchManager.search(keyword: keyword, pageToken: pageToken) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.hideProgressIndicator()
                
                switch result {
                case .success(let searchResult):
                    // 保存或追加搜索结果
                    if pageToken == nil {
                        self.searchResults = searchResult.items
                    } else {
                        self.searchResults.append(contentsOf: searchResult.items)
                    }
                    
                    // 保存nextPageToken用于下一页加载，确保空字符串被视为nil
                    let hasNextPage: Bool
                    if let token = searchResult.nextPageToken, !token.isEmpty {
                        self.currentNextPageToken = token
                        hasNextPage = true
                    } else {
                        self.currentNextPageToken = nil
                        hasNextPage = false
                    }
                    
                    // 更新UI
                    if !self.searchResults.isEmpty {
                        self.tableBackgroundView.isHidden = false
                        self.scrollView.isHidden = false
                        self.updateSearchStatus(totalResults: searchResult.totalResults, hasNextPage: hasNextPage)
                        
                        // 更新nextPageToken和分页按钮 - 明确检查是否有下一页
                        self.nextPageButton.isHidden = !hasNextPage
                        
                        // 根据是否有下一页调整nextPageButton的位置
                        if hasNextPage {
                            // 动态调整nextPageButton位置，放在文字后面
                            let textWidth = self.statusLabel.attributedStringValue.size().width
                            self.nextPageButtonLeadingConstraint?.constant = textWidth + 10
                            self.view.layoutSubtreeIfNeeded()
                        }
                        
                        // 调整窗口大小
                        if let window = self.view.window {
                            let expandedHeight: CGFloat = min(540, 140 + CGFloat(min(8, self.searchResults.count)) * 40 + 60)
                            let newFrame = NSRect(
                                x: window.frame.origin.x,
                                y: window.frame.origin.y + window.frame.height - expandedHeight,
                                width: window.frame.width,
                                height: expandedHeight
                            )
                            window.animator().setFrame(newFrame, display: true)
                        }
                    } else {
                        self.statusLabel.stringValue = NSLocalizedString("No results found", comment: "")
                        self.statusLabel.textColor = NSColor.secondaryLabelColor
                    }
                    
                    self.tableView.reloadData()
                    
                case .failure(let error):
                    self.statusLabel.stringValue = String(format: NSLocalizedString("Search Error: %@", comment: ""), error.localizedDescription)
                    self.statusLabel.textColor = NSColor.systemRed
                    
                    // 提供更详细的错误信息和建议
                    if let nsError = error as NSError? {
                        if nsError.domain == "YTSearchManager" && nsError.code == 1001 {
                            self.statusLabel.stringValue = NSLocalizedString("Search error: API configuration not completed, please set API URL and API Key", comment: "")
                        } else if nsError.domain == "YTSearchManager" && nsError.code == 1002 {
                            self.statusLabel.stringValue = NSLocalizedString("Search error: Invalid API URL, please check the configuration", comment: "")
                        } else if let code = (error as NSError?)?.code, code >= 400, code < 500 {
                            self.statusLabel.stringValue = NSLocalizedString("Search error: API authentication failed, please check the API Key", comment: "")
                        } else if let code = (error as NSError?)?.code, code >= 500 {
                            self.statusLabel.stringValue = NSLocalizedString("Search error: Server error, please try again later", comment: "")
                        }
                    }
                    
                    // 添加复制错误信息的按钮
                    let copyButton = NSButton(frame: NSRect(x: 0, y: 0, width: 80, height: 20))
                    copyButton.title = NSLocalizedString("Copy error", comment: "")
                    copyButton.bezelStyle = .inline
                    copyButton.target = self
                    copyButton.action = #selector(self.copyErrorMessage)
                    copyButton.tag = 100 // 用于标识
                    
                    // 移除已有的复制按钮
                    for subview in self.view.subviews {
                        if let button = subview as? NSButton, button.tag == 100 {
                            button.removeFromSuperview()
                            break
                        }
                    }
                    
                    self.view.addSubview(copyButton)
                    copyButton.translatesAutoresizingMaskIntoConstraints = false
                    NSLayoutConstraint.activate([
                        copyButton.leadingAnchor.constraint(equalTo: self.statusLabel.trailingAnchor, constant: 8),
                        copyButton.centerYAnchor.constraint(equalTo: self.statusLabel.centerYAnchor),
                        copyButton.heightAnchor.constraint(equalToConstant: 20)
                    ])
                }
            }
        }
    }
    
    @objc private func loadNextPage() {
        // 检查是否有下一页的令牌
        guard let token = currentNextPageToken, !token.isEmpty else {
            // 如果没有下一页，隐藏按钮
            nextPageButton.isHidden = true
            return
        }
        
        // 保存当前的滚动位置
        let scrollPosition = tableView.enclosingScrollView?.contentView.bounds.origin.y ?? 0
        
        // 使用上一次的搜索关键词和当前的令牌加载下一页
        performSearch(keyword: lastSearchKeyword, pageToken: token)
        
        // 在加载完成后恢复滚动位置（需要在主线程中执行）
        DispatchQueue.main.async { [weak self] in
            self?.tableView.enclosingScrollView?.contentView.scroll(to: NSPoint(x: 0, y: scrollPosition))
        }
    }
    
    @objc private func copyErrorMessage() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(statusLabel.stringValue, forType: .string)
        
        // 显示复制成功的临时提示
        let originalText = statusLabel.stringValue
        statusLabel.stringValue = NSLocalizedString("Copied to clipboard", comment: "")
        statusLabel.textColor = NSColor.systemGreen
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.statusLabel.stringValue = originalText
            self?.statusLabel.textColor = NSColor.systemRed
        }
    }
    
    private func showConfigRequiredPrompt() {
        statusLabel.stringValue = NSLocalizedString("Please configure the search service API (API URL and API Key)", comment: "")
        statusLabel.textColor = NSColor.systemRed
        
        // 添加前往设置的按钮
        let goToConfigButton = NSButton(frame: NSRect(x: 0, y: 0, width: 80, height: 20))
        goToConfigButton.title = NSLocalizedString("Go to settings", comment: "")
        goToConfigButton.bezelStyle = .inline
        goToConfigButton.target = self
        goToConfigButton.action = #selector(openConfigWindow)
        goToConfigButton.tag = 101 // 用于标识
        
        // 移除已有的按钮
        for subview in self.view.subviews {
            if let button = subview as? NSButton, button.tag == 101 {
                button.removeFromSuperview()
                break
            }
        }
        
        view.addSubview(goToConfigButton)
        goToConfigButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            goToConfigButton.leadingAnchor.constraint(equalTo: statusLabel.trailingAnchor, constant: 8),
            goToConfigButton.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            goToConfigButton.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    @objc private func openConfigWindow() {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.showConfigWindow()
        }
    }
    
    @objc private func detectFormats() {
        let urlString = urlTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if urlString.isEmpty {
            statusLabel.stringValue = NSLocalizedString("Please enter a valid URL", comment: "")
            statusLabel.textColor = NSColor.systemRed
            return
        }
        
        // Add smooth UI state transition
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            // Show progress indicator
            progressIndicator.isHidden = false
            progressIndicator.startAnimation(nil)
            
            // Update status label
            statusLabel.stringValue = NSLocalizedString("Detecting available formats...", comment: "")
            statusLabel.textColor = NSColor.secondaryLabelColor
        })
        
        formats = []
        tableView.reloadData()
        
        // Hide next page button in detect mode
        nextPageButton.isHidden = true
        
        // Use Task to execute asynchronous operations
        Task {
            do {
                if !self.isYtDlpInstalled {
                    DispatchQueue.main.async {
                        self.hideProgressIndicator()
                        self.statusLabel.stringValue = NSLocalizedString("yt-dlp not found, please make sure it's installed (brew install yt-dlp)", comment: "")
                        self.statusLabel.textColor = NSColor.systemRed
                    }
                    return
                }
                
                if !self.isFfmpegInstalled {
                    DispatchQueue.main.async {
                        self.hideProgressIndicator()
                        self.statusLabel.stringValue = NSLocalizedString("ffmpeg not found, please make sure it's installed (brew install ffmpeg)", comment: "")
                        self.statusLabel.textColor = NSColor.systemRed
                    }
                    return
                }
                
                let newFormats = try await DownloadManager.shared.fetchAvailableFormats(from: urlString)
                
                DispatchQueue.main.async {
                    self.formats = newFormats
                    
                    if !self.formats.isEmpty {
                        NSAnimationContext.runAnimationGroup({ context in
                            context.duration = 0.3
                            self.hideProgressIndicator()
                            
                            self.tableBackgroundView.isHidden = false
                            self.scrollView.isHidden = false
                            
                            self.statusLabel.stringValue = String(format: NSLocalizedString("Found %d available formats", comment: ""), self.formats.count)
                            self.statusLabel.textColor = NSColor.secondaryLabelColor
                        }, completionHandler: {
                            self.tableView.reloadData()
                            
                            if let window = self.view.window {
                                let expandedHeight: CGFloat = min(540, 140 + CGFloat(min(8, self.formats.count)) * 40 + 60)
                                
                                let newFrame = NSRect(
                                    x: window.frame.origin.x,
                                    y: window.frame.origin.y + window.frame.height - expandedHeight,
                                    width: window.frame.width,
                                    height: expandedHeight
                                )
                                
                                window.animator().setFrame(newFrame, display: true)
                            }
                        })
                    } else {
                        self.hideProgressIndicator()
                        self.statusLabel.stringValue = NSLocalizedString("No formats found", comment: "")
                        self.statusLabel.textColor = NSColor.secondaryLabelColor
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.hideProgressIndicator()
                    self.statusLabel.stringValue = String(format: NSLocalizedString("Error: %@", comment: ""), error.localizedDescription)
                    self.statusLabel.textColor = NSColor.systemRed
                }
            }
        }
    }
    
    private func hideProgressIndicator() {
        progressIndicator.isHidden = true
        progressIndicator.stopAnimation(nil)
    }
    
    // 搜索完成时的状态显示
    private func updateSearchStatus(totalResults: Int, hasNextPage: Bool) {
        let statusText = String(format: NSLocalizedString("Found %d results", comment: ""), totalResults)
        statusLabel.stringValue = statusText
        statusLabel.textColor = NSColor.secondaryLabelColor
        
        // 控制下一页按钮的可见性
        nextPageButton.isHidden = !hasNextPage
    }
    
    @objc private func downloadAudio(sender: NSButton) {
        let row = sender.tag
        guard row >= 0 && row < formats.count else { return }
        
        let format = formats[row]
        let videoUrl = urlTextField.stringValue
        
        sender.isEnabled = false
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            sender.animator().alphaValue = 0.6
        })
        
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
        statusLabel.stringValue = NSLocalizedString("Starting download...", comment: "")
        
        Task {
            do {
                try await DownloadManager.shared.downloadAudio(from: videoUrl, formatId: format.formatId)
                
                DispatchQueue.main.async {
                    self.hideProgressIndicator()
                    self.statusLabel.stringValue = NSLocalizedString("Download completed successfully", comment: "")
                    self.statusLabel.textColor = NSColor.systemGreen
                    
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 0.2
                        sender.animator().alphaValue = 1.0
                    }, completionHandler: {
                        sender.isEnabled = true
                    })
                    
                    // Notify player to refresh music library
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshMusicLibrary"), object: nil)
                }
            } catch {
                DispatchQueue.main.async {
                    self.hideProgressIndicator()
                    self.statusLabel.stringValue = String(format: NSLocalizedString("Download failed: %@", comment: ""), error.localizedDescription)
                    self.statusLabel.textColor = NSColor.systemRed
                    
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 0.2
                        sender.animator().alphaValue = 1.0
                    }, completionHandler: {
                        sender.isEnabled = true
                    })
                }
            }
        }
    }
    
    private func showAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Information", comment: "")
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        alert.beginSheetModal(for: view.window!) { _ in }
    }
    
    @objc private func openGithub() {
        if let url = URL(string: "https://github.com/samzong/macmusicplayer") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - NSTableViewDataSource & NSTableViewDelegate
extension DownloadViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        if isSearchMode {
            // 如果有展开的行，则添加格式选项数量
            if let expandedRow = expandedVideoRow, expandedRow < searchResults.count {
                return searchResults.count + formatOptions.count
            }
            return searchResults.count
        } else {
            return formats.count
        }
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if isSearchMode {
            // 判断是否是格式选项行
            if let expandedRow = expandedVideoRow, row > expandedRow && row <= expandedRow + formatOptions.count {
                return getFormatOptionCellView(for: row - expandedRow - 1)
            }
            
            // 正常搜索结果行
            let actualRow = row > expandedVideoRow ?? -1 ? row - formatOptions.count : row
            return getSearchResultCellView(for: actualRow)
        } else {
            return getFormatCellView(for: row)
        }
    }
    
    private func getSearchResultCellView(for row: Int) -> NSView? {
        let video = searchResults[row]
        
        let cellIdentifier = NSUserInterfaceItemIdentifier("SearchCell")
        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
        
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = cellIdentifier
            
            let containerView = NSView()
            containerView.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(containerView)
            
            NSLayoutConstraint.activate([
                containerView.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 5),
                containerView.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -5),
                containerView.topAnchor.constraint(equalTo: cell!.topAnchor),
                containerView.bottomAnchor.constraint(equalTo: cell!.bottomAnchor)
            ])
            
            // 缩略图
            let thumbnailView = NSImageView()
            thumbnailView.identifier = NSUserInterfaceItemIdentifier("ThumbnailView")
            thumbnailView.translatesAutoresizingMaskIntoConstraints = false
            thumbnailView.imageScaling = .scaleProportionallyUpOrDown
            containerView.addSubview(thumbnailView)
            
            // 标题文本
            let titleField = NSTextField()
            titleField.identifier = NSUserInterfaceItemIdentifier("TitleField")
            titleField.translatesAutoresizingMaskIntoConstraints = false
            titleField.isEditable = false
            titleField.isBordered = false
            titleField.backgroundColor = .clear
            titleField.drawsBackground = false
            titleField.font = NSFont.systemFont(ofSize: 12)
            titleField.lineBreakMode = .byTruncatingTail
            containerView.addSubview(titleField)
            
            // 详情按钮
            let detailButton = NSButton()
            detailButton.identifier = NSUserInterfaceItemIdentifier("DetailButton")
            detailButton.translatesAutoresizingMaskIntoConstraints = false
            detailButton.title = NSLocalizedString("Details", comment: "")
            detailButton.bezelStyle = .rounded
            detailButton.font = NSFont.systemFont(ofSize: 12)
            detailButton.target = self
            detailButton.action = #selector(openVideoDetail(sender:))
            containerView.addSubview(detailButton)
            
            // 检测按钮
            let detectButton = NSButton()
            detectButton.identifier = NSUserInterfaceItemIdentifier("VideoDetectButton")
            detectButton.translatesAutoresizingMaskIntoConstraints = false
            detectButton.title = NSLocalizedString("Detect", comment: "")
            detectButton.bezelStyle = .rounded
            detectButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            detectButton.target = self
            detectButton.action = #selector(detectVideoFormats(sender:))
            detectButton.contentTintColor = NSColor.white
            
            if #available(macOS 11.0, *) {
                detectButton.bezelColor = NSColor.controlAccentColor
            } else {
                detectButton.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
            }
            
            containerView.addSubview(detectButton)
            
            NSLayoutConstraint.activate([
                thumbnailView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 5),
                thumbnailView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                thumbnailView.widthAnchor.constraint(equalToConstant: 40),
                thumbnailView.heightAnchor.constraint(equalToConstant: 30),
                
                titleField.leadingAnchor.constraint(equalTo: thumbnailView.trailingAnchor, constant: 10),
                titleField.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                titleField.trailingAnchor.constraint(equalTo: detailButton.leadingAnchor, constant: -10),
                
                detectButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -5),
                detectButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                detectButton.widthAnchor.constraint(equalToConstant: 60),
                detectButton.heightAnchor.constraint(equalToConstant: 26),
                
                detailButton.trailingAnchor.constraint(equalTo: detectButton.leadingAnchor, constant: -5),
                detailButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                detailButton.widthAnchor.constraint(equalToConstant: 60),
                detailButton.heightAnchor.constraint(equalToConstant: 26)
            ])
        }
        
        // 更新缩略图
        if let thumbnailView = cell?.subviews.first?.subviews.first(where: { $0.identifier?.rawValue == "ThumbnailView" }) as? NSImageView {
            // 异步加载缩略图
            DispatchQueue.global().async {
                if let url = URL(string: video.thumbnailUrl),
                   let imageData = try? Data(contentsOf: url),
                   let image = NSImage(data: imageData) {
                    DispatchQueue.main.async {
                        thumbnailView.image = image
                    }
                } else {
                    DispatchQueue.main.async {
                        thumbnailView.image = NSImage(named: "NSCaution")
                    }
                }
            }
        }
        
        // 更新标题
        if let titleField = cell?.subviews.first?.subviews.first(where: { $0.identifier?.rawValue == "TitleField" }) as? NSTextField {
            titleField.stringValue = video.title
        }
        
        // 更新按钮标签
        if let detailButton = cell?.subviews.first?.subviews.first(where: { $0.identifier?.rawValue == "DetailButton" }) as? NSButton {
            detailButton.tag = row
        }
        
        if let detectButton = cell?.subviews.first?.subviews.first(where: { $0.identifier?.rawValue == "VideoDetectButton" }) as? NSButton {
            detectButton.tag = row
        }
        
        return cell
    }
    
    private func getFormatCellView(for row: Int) -> NSView? {
        let format = formats[row]
        
        let cellIdentifier = NSUserInterfaceItemIdentifier("FormatCell")
        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
        
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = cellIdentifier
            
            let containerView = NSView()
            containerView.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(containerView)
            
            NSLayoutConstraint.activate([
                containerView.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 5),
                containerView.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -5),
                containerView.topAnchor.constraint(equalTo: cell!.topAnchor),
                containerView.bottomAnchor.constraint(equalTo: cell!.bottomAnchor)
            ])
            
            let text = NSTextField()
            text.identifier = NSUserInterfaceItemIdentifier("FormatText")
            text.translatesAutoresizingMaskIntoConstraints = false
            text.isEditable = false
            text.isBordered = false
            text.backgroundColor = .clear
            text.drawsBackground = false
            text.font = NSFont.systemFont(ofSize: 12)
            text.lineBreakMode = .byTruncatingTail
            text.setAccessibilityLabel("Audio format")
            containerView.addSubview(text)
            
            // Download button - use a more modern style
            let downloadButton = NSButton()
            downloadButton.identifier = NSUserInterfaceItemIdentifier("DownloadButton")
            downloadButton.translatesAutoresizingMaskIntoConstraints = false
            downloadButton.title = NSLocalizedString("Download", comment: "")
            downloadButton.bezelStyle = .rounded
            downloadButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            downloadButton.target = self
            downloadButton.action = #selector(downloadAudio(sender:))
            downloadButton.setAccessibilityLabel("Download this audio format")            
            downloadButton.wantsLayer = true
            downloadButton.contentTintColor = NSColor.white
            
            if #available(macOS 11.0, *) {
                downloadButton.bezelColor = NSColor.controlAccentColor
            } else {
                downloadButton.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
            }
            
            let trackingArea = NSTrackingArea(
                rect: NSRect.zero,
                options: [.inVisibleRect, .activeAlways, .mouseEnteredAndExited],
                owner: downloadButton,
                userInfo: nil
            )
            downloadButton.addTrackingArea(trackingArea)
            
            let minButtonWidth: CGFloat = 90
            let buttonWidth = downloadButton.title.size(withAttributes: [.font: downloadButton.font!]).width + 20
            let actualButtonWidth = max(minButtonWidth, buttonWidth)
            
            containerView.addSubview(downloadButton)
            
            NSLayoutConstraint.activate([
                text.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
                text.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                text.trailingAnchor.constraint(equalTo: downloadButton.leadingAnchor, constant: -10),
                
                downloadButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -5),
                downloadButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                downloadButton.widthAnchor.constraint(equalToConstant: actualButtonWidth),
                downloadButton.heightAnchor.constraint(equalToConstant: 26)
            ])
            
            cell?.textField = text
        }
        
        cell?.textField?.stringValue = format.description
        
        if let downloadButton = cell?.subviews.first?.subviews.first(where: { $0.identifier?.rawValue == "DownloadButton" }) as? NSButton {
            downloadButton.tag = row
        }
        
        return cell
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 40
    }
    
    // MARK: - Search Result Actions
    @objc private func openVideoDetail(sender: NSButton) {
        let row = sender.tag
        guard row >= 0 && row < searchResults.count else { return }
        
        let video = searchResults[row]
        if let url = URL(string: video.videoUrl) {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func detectVideoFormats(sender: NSButton) {
        let row = sender.tag
        guard row >= 0 && row < searchResults.count else { return }
        
        let video = searchResults[row]
        
        // 检查是否需要折叠当前展开的行
        if expandedVideoRow == row {
            // 如果点击的是当前已展开的行，则收起
            expandedVideoRow = nil
            formatOptions = []
            tableView.reloadData()
            return
        } else if expandedVideoRow != nil {
            // 如果有其他行已展开，先收起
            expandedVideoRow = nil
            formatOptions = []
        }
        
        // 显示加载状态
        expandedVideoRow = row
        formatOptions = []
        tableView.reloadData()
        
        // 开始加载按钮的状态更新
        if let videoCell = tableView.rowView(atRow: row, makeIfNecessary: false),
           let cellContent = videoCell.view(atColumn: 0) as? NSView,
           let detectBtn = cellContent.subviews.first?.subviews.first(where: { ($0 as? NSButton)?.action == #selector(detectVideoFormats(sender:)) }) as? NSButton {
            detectBtn.isEnabled = false
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                detectBtn.animator().alphaValue = 0.6
            })
        }
        
        // 创建一个加载中的选项
        let loadingOption = FormatOption(title: NSLocalizedString("Loading formats...", comment: ""), formatId: "", videoItem: video)
        formatOptions = [loadingOption]
        tableView.reloadData()
        
        // 实际执行格式检测
        Task {
            do {
                let detectedFormats = try await DownloadManager.shared.fetchAvailableFormats(from: video.videoUrl)
                
                // 在主线程更新UI
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.expandedVideoRow == row else { return }
                    
                    // 转换检测到的格式为选项
                    self.formatOptions = detectedFormats.map { format in
                        return FormatOption(
                            title: format.description,
                            formatId: format.formatId,
                            videoItem: video
                        )
                    }
                    
                    // 重新启用检测按钮
                    if let videoCell = self.tableView.rowView(atRow: row, makeIfNecessary: false),
                       let cellContent = videoCell.view(atColumn: 0) as? NSView,
                       let detectBtn = cellContent.subviews.first?.subviews.first(where: { ($0 as? NSButton)?.action == #selector(self.detectVideoFormats(sender:)) }) as? NSButton {
                        detectBtn.isEnabled = true
                        NSAnimationContext.runAnimationGroup({ context in
                            context.duration = 0.2
                            detectBtn.animator().alphaValue = 1.0
                        })
                    }
                    
                    // 刷新表格以显示实际格式
                    self.tableView.reloadData()
                }
            } catch {
                // 处理错误
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.expandedVideoRow == row else { return }
                    
                    // 显示错误信息
                    self.formatOptions = [
                        FormatOption(
                            title: String(format: NSLocalizedString("Error: %@", comment: ""), error.localizedDescription),
                            formatId: "",
                            videoItem: video
                        )
                    ]
                    
                    // 重新启用检测按钮
                    if let videoCell = self.tableView.rowView(atRow: row, makeIfNecessary: false),
                       let cellContent = videoCell.view(atColumn: 0) as? NSView,
                       let detectBtn = cellContent.subviews.first?.subviews.first(where: { ($0 as? NSButton)?.action == #selector(self.detectVideoFormats(sender:)) }) as? NSButton {
                        detectBtn.isEnabled = true
                        NSAnimationContext.runAnimationGroup({ context in
                            context.duration = 0.2
                            detectBtn.animator().alphaValue = 1.0
                        })
                    }
                    
                    // 刷新表格以显示错误信息
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    @objc private func downloadFormatOption(sender: NSButton) {
        let optionIndex = sender.tag
        guard optionIndex >= 0 && optionIndex < formatOptions.count else { return }
        
        let option = formatOptions[optionIndex]
        
        // 检查是否有有效的formatId
        if option.formatId.isEmpty {
            return // 跳过无效的选项（如加载中或错误信息）
        }
        
        // 直接下载指定的格式
        downloadSpecificFormat(video: option.videoItem, formatId: option.formatId, formatName: option.title)
        
        // 收起展开的行
        expandedVideoRow = nil
        formatOptions = []
        tableView.reloadData()
    }
    
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let identifier = NSUserInterfaceItemIdentifier("FormatRowView")
        var rowView = tableView.makeView(withIdentifier: identifier, owner: self) as? CustomTableRowView
        
        if rowView == nil {
            rowView = CustomTableRowView()
            rowView?.identifier = identifier
        }
        
        return rowView
    }
    
    // 添加获取格式选项行视图的方法
    private func getFormatOptionCellView(for optionIndex: Int) -> NSView? {
        guard optionIndex >= 0 && optionIndex < formatOptions.count else { return nil }
        
        let option = formatOptions[optionIndex]
        
        let cellIdentifier = NSUserInterfaceItemIdentifier("FormatOptionCell")
        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
        
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = cellIdentifier
            
            let containerView = NSView()
            containerView.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(containerView)
            
            NSLayoutConstraint.activate([
                containerView.leadingAnchor.constraint(equalTo: cell!.leadingAnchor),
                containerView.trailingAnchor.constraint(equalTo: cell!.trailingAnchor),
                containerView.topAnchor.constraint(equalTo: cell!.topAnchor),
                containerView.bottomAnchor.constraint(equalTo: cell!.bottomAnchor)
            ])
            
            // 格式选项显示的文本
            let formatLabel = NSTextField()
            formatLabel.identifier = NSUserInterfaceItemIdentifier("FormatOptionLabel")
            formatLabel.translatesAutoresizingMaskIntoConstraints = false
            formatLabel.isEditable = false
            formatLabel.isBordered = false
            formatLabel.backgroundColor = .clear
            formatLabel.drawsBackground = false
            formatLabel.font = NSFont.systemFont(ofSize: 12)
            formatLabel.lineBreakMode = .byTruncatingTail
            containerView.addSubview(formatLabel)
            
            // 下载按钮
            let downloadButton = NSButton()
            downloadButton.identifier = NSUserInterfaceItemIdentifier("FormatOptionDownloadButton")
            downloadButton.translatesAutoresizingMaskIntoConstraints = false
            downloadButton.title = NSLocalizedString("Download", comment: "")
            downloadButton.bezelStyle = .rounded
            downloadButton.font = NSFont.systemFont(ofSize: 12)
            downloadButton.target = self
            downloadButton.action = #selector(downloadFormatOption(sender:))
            downloadButton.contentTintColor = NSColor.white
            
            if #available(macOS 11.0, *) {
                downloadButton.bezelColor = NSColor.controlAccentColor
            } else {
                downloadButton.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
            }
            
            containerView.addSubview(downloadButton)
            
            NSLayoutConstraint.activate([
                formatLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 25),
                formatLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                formatLabel.trailingAnchor.constraint(equalTo: downloadButton.leadingAnchor, constant: -10),
                
                downloadButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -5),
                downloadButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                downloadButton.widthAnchor.constraint(equalToConstant: 70),
                downloadButton.heightAnchor.constraint(equalToConstant: 26)
            ])
        }
        
        // 更新文本和按钮
        if let label = cell?.subviews.first?.subviews.first(where: { $0.identifier?.rawValue == "FormatOptionLabel" }) as? NSTextField {
            label.stringValue = option.title
        }
        
        if let button = cell?.subviews.first?.subviews.first(where: { $0.identifier?.rawValue == "FormatOptionDownloadButton" }) as? NSButton {
            button.tag = optionIndex
            
            // 根据选项是否有效来控制按钮状态
            if option.formatId.isEmpty {
                button.isEnabled = false
                button.isHidden = option.title.starts(with: "Error") ? true : false
            } else {
                button.isEnabled = true
                button.isHidden = false
            }
        }
        
        return cell
    }
    
    private func downloadSpecificFormat(video: YTSearchManager.SearchResult.VideoItem, formatId: String, formatName: String) {
        // 显示下载进度
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
        statusLabel.stringValue = String(format: NSLocalizedString("Downloading %@...", comment: ""), formatName)
        
        Task {
            do {
                try await DownloadManager.shared.downloadAudio(from: video.videoUrl, formatId: formatId)
                
                DispatchQueue.main.async {
                    self.hideProgressIndicator()
                    self.statusLabel.stringValue = NSLocalizedString("Download completed", comment: "")
                    self.statusLabel.textColor = NSColor.systemGreen
                    
                    // 通知播放器刷新音乐库
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshMusicLibrary"), object: nil)
                }
            } catch {
                DispatchQueue.main.async {
                    self.hideProgressIndicator()
                    self.statusLabel.stringValue = String(format: NSLocalizedString("Download failed: %@", comment: ""), error.localizedDescription)
                    self.statusLabel.textColor = NSColor.systemRed
                }
            }
        }
    }
}
