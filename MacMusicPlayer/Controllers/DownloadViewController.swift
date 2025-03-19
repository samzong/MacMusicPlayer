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
    
    // MARK: - Properties
    private var formats: [DownloadManager.DownloadFormat] = []
    private var selectedFormat: DownloadManager.DownloadFormat?
    private var ytDlpVersion: String = ""
    private var ffmpegVersion: String = ""
    private var isYtDlpInstalled: Bool = false
    private var isFfmpegInstalled: Bool = false
    
    // MARK: - Lifecycle
    override func loadView() {
        // Set an appropriate initial size, consistent with the compact height used later
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 140))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        checkDependencies()
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
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.wantsLayer = true
        
        if let window = view.window {
            window.title = NSLocalizedString("Download Music", comment: "")
            window.titleVisibility = .visible
            window.titlebarAppearsTransparent = false
        }
        
        setupURLField()
        setupDetectButton()
        setupStatusLabel()
        setupTableView()
        setupProgressIndicator()
        setupVersionInfo()
        setupGithubLink()
    }
    
    private func setupURLField() {
        urlTextField.translatesAutoresizingMaskIntoConstraints = false
        urlTextField.placeholderString = NSLocalizedString("Enter video URL", comment: "")
        urlTextField.font = NSFont.systemFont(ofSize: 13)
        urlTextField.bezelStyle = .roundedBezel
        urlTextField.focusRingType = .exterior
        urlTextField.target = self
        urlTextField.action = #selector(detectFormats)
        view.addSubview(urlTextField)
        
        NSLayoutConstraint.activate([
            urlTextField.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            urlTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            urlTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -110),
            urlTextField.heightAnchor.constraint(equalToConstant: 28)
        ])
    }
    
    private func setupDetectButton() {
        detectButton.translatesAutoresizingMaskIntoConstraints = false
        detectButton.title = NSLocalizedString("Detect", comment: "")
        detectButton.bezelStyle = .rounded
        detectButton.target = self
        detectButton.action = #selector(detectFormats)
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
        if let userInfo = event.trackingArea?.userInfo as? [String: String],
           userInfo["button"] == "github" {
            let attributedString = NSMutableAttributedString(string: githubLinkButton.title)
            attributedString.addAttribute(.underlineStyle, 
                                         value: NSUnderlineStyle.single.rawValue, 
                                         range: NSRange(location: 0, length: attributedString.length))
            githubLinkButton.attributedTitle = attributedString
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if let userInfo = event.trackingArea?.userInfo as? [String: String],
           userInfo["button"] == "github" {
            githubLinkButton.attributedTitle = NSAttributedString(string: githubLinkButton.title)
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
    
    // MARK: - Actions
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
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            progressIndicator.animator().alphaValue = 0
        }, completionHandler: {
            self.progressIndicator.stopAnimation(nil)
            self.progressIndicator.isHidden = true
            self.progressIndicator.alphaValue = 1
        })
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
        return formats.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
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
            
            class ButtonAnimationDelegate: NSObject {
                @objc func mouseEntered(_ sender: NSEvent) {
                    guard let button = sender.trackingArea?.owner as? NSButton else { return }
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 0.2
                        button.animator().alphaValue = 0.9
                    })
                }
                
                @objc func mouseExited(_ sender: NSEvent) {
                    guard let button = sender.trackingArea?.owner as? NSButton else { return }
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 0.2
                        button.animator().alphaValue = 1.0
                    })
                }
                
                @objc func mouseDown(_ sender: NSEvent) {
                    guard let button = sender.trackingArea?.owner as? NSButton else { return }
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 0.1
                        button.animator().setFrameOrigin(NSPoint(x: button.frame.origin.x, y: button.frame.origin.y - 1))
                    })
                }
                
                @objc func mouseUp(_ sender: NSEvent) {
                    guard let button = sender.trackingArea?.owner as? NSButton else { return }
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 0.1
                        button.animator().setFrameOrigin(NSPoint(x: button.frame.origin.x, y: button.frame.origin.y + 1))
                    })
                }
            }
            
            let animationDelegate = ButtonAnimationDelegate()
            objc_setAssociatedObject(downloadButton, "animationDelegate", animationDelegate, .OBJC_ASSOCIATION_RETAIN)
            
            NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { _ in
                downloadButton.contentTintColor = NSColor.white
                if #available(macOS 11.0, *) {
                    downloadButton.bezelColor = NSColor.controlAccentColor
                } else {
                    downloadButton.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
                }
            }
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
    
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let identifier = NSUserInterfaceItemIdentifier("FormatRowView")
        var rowView = tableView.makeView(withIdentifier: identifier, owner: self) as? CustomTableRowView
        
        if rowView == nil {
            rowView = CustomTableRowView()
            rowView?.identifier = identifier
        }
        
        return rowView
    }
}
