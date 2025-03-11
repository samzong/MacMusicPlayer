import Cocoa

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
    private let backgroundView = NSView()
    
    // MARK: - Properties
    private var formats: [DownloadManager.DownloadFormat] = []
    private var selectedFormat: DownloadManager.DownloadFormat?
    private var ytDlpVersion: String = ""
    private var ffmpegVersion: String = ""
    private var isYtDlpInstalled: Bool = false
    private var isFfmpegInstalled: Bool = false
    
    // MARK: - Lifecycle
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 300))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        checkDependencies()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        setupURLField()
        setupDetectButton()
        setupStatusLabel()
        setupTableView()
        setupProgressIndicator()
        setupVersionInfo()
        setupGithubLink()
        
        // 根据初始视图状态调整窗口大小
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.view.window else { return }
            // 初始窗口高度：只显示URL输入框、状态标签和版本信息
            let compactHeight: CGFloat = 140
            let frame = NSRect(
                x: window.frame.origin.x,
                y: window.frame.origin.y + window.frame.height - compactHeight,
                width: window.frame.width,
                height: compactHeight
            )
            window.setFrame(frame, display: true, animate: false)
        }
    }
    
    private func setupURLField() {
        urlTextField.frame = NSRect(x: 20, y: view.frame.height - 50, width: view.frame.width - 130, height: 30)
        urlTextField.placeholderString = NSLocalizedString("Enter video URL", comment: "")
        urlTextField.font = NSFont.systemFont(ofSize: 14)
        urlTextField.bezelStyle = .roundedBezel
        urlTextField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(urlTextField)
        
        NSLayoutConstraint.activate([
            urlTextField.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            urlTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            urlTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -110),
            urlTextField.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    private func setupDetectButton() {
        detectButton.translatesAutoresizingMaskIntoConstraints = false
        detectButton.title = NSLocalizedString("Detect", comment: "")
        detectButton.bezelStyle = .rounded
        detectButton.target = self
        detectButton.action = #selector(detectFormats)
        detectButton.font = NSFont.systemFont(ofSize: 14)
        view.addSubview(detectButton)
        
        NSLayoutConstraint.activate([
            detectButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            detectButton.leadingAnchor.constraint(equalTo: urlTextField.trailingAnchor, constant: 10),
            detectButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            detectButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    private func setupStatusLabel() {
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.backgroundColor = .clear
        statusLabel.alignment = .center
        statusLabel.font = NSFont.systemFont(ofSize: 13)
        statusLabel.textColor = NSColor.secondaryLabelColor
        view.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: urlTextField.bottomAnchor, constant: 10),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            statusLabel.heightAnchor.constraint(equalToConstant: 20)
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
        scrollView.wantsLayer = true
        
        // 添加圆角背景视图
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        backgroundView.layer?.cornerRadius = 8
        backgroundView.layer?.borderWidth = 0.5  // 更细的边框
        backgroundView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.2).cgColor  // 更淡的边框颜色
        backgroundView.layer?.shadowOpacity = 0.1  // 添加轻微阴影
        backgroundView.layer?.shadowOffset = CGSize(width: 0, height: 1)
        backgroundView.layer?.shadowRadius = 2
        view.addSubview(backgroundView)
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -60)
        ])
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: backgroundView.topAnchor, constant: 5),
            scrollView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 5),
            scrollView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -5),
            scrollView.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor, constant: -5)
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
        tableView.gridStyleMask = [] // 移除所有网格线
        tableView.usesAlternatingRowBackgroundColors = false // 禁用交替行背景色
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("FormatColumn"))
        column.width = scrollView.frame.width - 20
        tableView.addTableColumn(column)
        
        scrollView.documentView = tableView
        
        // 初始状态下隐藏背景视图和表格
        backgroundView.isHidden = true
        scrollView.isHidden = true
    }
    
    private func setupVersionInfo() {
        versionInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        versionInfoLabel.isEditable = false
        versionInfoLabel.isBordered = false
        versionInfoLabel.backgroundColor = .clear
        versionInfoLabel.alignment = .left
        versionInfoLabel.font = NSFont.systemFont(ofSize: 11)
        versionInfoLabel.textColor = NSColor.secondaryLabelColor
        view.addSubview(versionInfoLabel)
        
        NSLayoutConstraint.activate([
            versionInfoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            versionInfoLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            versionInfoLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    private func setupGithubLink() {
        githubLinkButton.translatesAutoresizingMaskIntoConstraints = false
        githubLinkButton.title = "GitHub"
        githubLinkButton.bezelStyle = .inline
        githubLinkButton.isBordered = false
        githubLinkButton.target = self
        githubLinkButton.action = #selector(openGithub)
        githubLinkButton.font = NSFont.systemFont(ofSize: 11)
        githubLinkButton.contentTintColor = NSColor.linkColor
        view.addSubview(githubLinkButton)
        
        NSLayoutConstraint.activate([
            githubLinkButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            githubLinkButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            githubLinkButton.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    // MARK: - Dependencies Check
    private func checkDependencies() {
        // 立即设置默认值，避免UI显示"Not installed"
        isYtDlpInstalled = false
        isFfmpegInstalled = false
        
        // 使用shell脚本直接检测工具
        let script = """
        #!/bin/bash
        export PATH=$PATH:/usr/local/bin:/opt/homebrew/bin:/opt/local/bin:/usr/bin
        
        # 检查yt-dlp
        if command -v yt-dlp &> /dev/null; then
            echo "YT_DLP_INSTALLED=true"
            echo "YT_DLP_VERSION=$(yt-dlp --version 2>/dev/null)"
        else
            echo "YT_DLP_INSTALLED=false"
        fi
        
        # 检查ffmpeg
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
                // 解析输出
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
                
                // 更新UI
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.updateVersionInfo()
                }
            }
        } catch {
            print("Error checking dependencies: \(error)")
            // 如果脚本执行失败，尝试备用方法
            checkDependenciesWithDirectCommands()
        }
    }
    
    private func checkDependenciesWithDirectCommands() {
        // 直接检查yt-dlp
        checkYtDlp()
        
        // 直接检查ffmpeg
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
                
                // 获取版本
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
            
            // 更新UI
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
                
                // 获取版本
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
            
            // 更新UI
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
        
        // 如果有依赖未安装，显示提示
        if !isYtDlpInstalled || !isFfmpegInstalled {
            statusLabel.stringValue = NSLocalizedString("Please install missing dependencies", comment: "")
            statusLabel.textColor = NSColor.systemRed
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
        
        // 检查依赖是否已安装
        if !isYtDlpInstalled || !isFfmpegInstalled {
            statusLabel.stringValue = NSLocalizedString("Please install missing dependencies", comment: "")
            statusLabel.textColor = NSColor.systemRed
            return
        }
        
        statusLabel.stringValue = NSLocalizedString("Detecting available formats...", comment: "")
        statusLabel.textColor = NSColor.secondaryLabelColor
        detectButton.isEnabled = false
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
        
        Task {
            do {
                formats = try await DownloadManager.shared.fetchAvailableFormats(from: urlString)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.tableView.reloadData()
                    self.backgroundView.isHidden = false
                    self.scrollView.isHidden = false
                    self.statusLabel.stringValue = NSLocalizedString("Please select a format to download", comment: "")
                    self.statusLabel.textColor = NSColor.secondaryLabelColor
                    self.detectButton.isEnabled = true
                    self.progressIndicator.stopAnimation(nil)
                    self.progressIndicator.isHidden = true
                    
                    // 调整窗口大小以适应表格内容
                    if let window = self.view.window {
                        // 计算所需的高度：URL输入框+状态标签+表格+版本信息
                        let headerHeight: CGFloat = 60 // URL输入框和状态标签的高度加上边距
                        let footerHeight: CGFloat = 40 // 版本信息的高度加上边距
                        
                        // 计算表格高度，但确保不会太高
                        let itemHeight: CGFloat = 40 // 每行的高度
                        let padding: CGFloat = 20 // 表格上下的内边距
                        let maxRows = 5 // 最多显示的行数
                        let visibleRows = min(self.formats.count, maxRows)
                        let tableHeight = CGFloat(visibleRows) * itemHeight + padding
                        
                        let totalHeight = headerHeight + tableHeight + footerHeight
                        
                        let frame = NSRect(
                            x: window.frame.origin.x,
                            y: window.frame.origin.y + window.frame.height - totalHeight,
                            width: window.frame.width,
                            height: totalHeight
                        )
                        window.setFrame(frame, display: true, animate: true)
                    }
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    if let downloadError = error as? DownloadManager.DownloadError {
                        self.statusLabel.stringValue = downloadError.localizedDescription
                    } else {
                        self.statusLabel.stringValue = NSLocalizedString("Failed to detect formats", comment: "")
                    }
                    self.statusLabel.textColor = NSColor.systemRed
                    self.detectButton.isEnabled = true
                    self.progressIndicator.stopAnimation(nil)
                    self.progressIndicator.isHidden = true
                }
            }
        }
    }
    
    @objc private func downloadAudio(sender: NSButton) {
        // 获取点击的行
        let row = sender.tag
        guard row >= 0 && row < formats.count else { return }
        
        let format = formats[row]
        let urlString = urlTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if urlString.isEmpty { return }
        
        statusLabel.stringValue = NSLocalizedString("Downloading...", comment: "")
        statusLabel.textColor = NSColor.secondaryLabelColor
        sender.isEnabled = false
        detectButton.isEnabled = false
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
        
        Task {
            do {
                try await DownloadManager.shared.downloadAudio(from: urlString, formatId: format.formatId)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.statusLabel.stringValue = NSLocalizedString("Download completed", comment: "")
                    self.statusLabel.textColor = NSColor.systemGreen
                    sender.isEnabled = true
                    self.detectButton.isEnabled = true
                    self.progressIndicator.stopAnimation(nil)
                    self.progressIndicator.isHidden = true
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    if let downloadError = error as? DownloadManager.DownloadError {
                        self.statusLabel.stringValue = downloadError.localizedDescription
                    } else {
                        self.statusLabel.stringValue = NSLocalizedString("Download failed", comment: "")
                    }
                    self.statusLabel.textColor = NSColor.systemRed
                    sender.isEnabled = true
                    self.detectButton.isEnabled = true
                    self.progressIndicator.stopAnimation(nil)
                    self.progressIndicator.isHidden = true
                }
            }
        }
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
            
            // 创建容器视图，用于布局
            let containerView = NSView()
            containerView.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(containerView)
            
            NSLayoutConstraint.activate([
                containerView.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 5),
                containerView.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -5),
                containerView.topAnchor.constraint(equalTo: cell!.topAnchor),
                containerView.bottomAnchor.constraint(equalTo: cell!.bottomAnchor)
            ])
            
            // 格式信息
            let text = NSTextField()
            text.identifier = NSUserInterfaceItemIdentifier("FormatText")
            text.translatesAutoresizingMaskIntoConstraints = false
            text.isEditable = false
            text.isBordered = false
            text.backgroundColor = .clear
            text.drawsBackground = false
            text.font = NSFont.systemFont(ofSize: 13)
            text.lineBreakMode = .byTruncatingTail
            containerView.addSubview(text)
            
            // 下载按钮
            let downloadButton = NSButton()
            downloadButton.identifier = NSUserInterfaceItemIdentifier("DownloadButton")
            downloadButton.translatesAutoresizingMaskIntoConstraints = false
            downloadButton.title = NSLocalizedString("Download", comment: "")
            downloadButton.bezelStyle = .rounded
            downloadButton.font = NSFont.systemFont(ofSize: 12)
            downloadButton.target = self
            downloadButton.action = #selector(downloadAudio(sender:))
            
            // 确保按钮宽度足够显示文本
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
                downloadButton.heightAnchor.constraint(equalToConstant: 24)
            ])
            
            cell?.textField = text
        }
        
        // 更新内容
        cell?.textField?.stringValue = format.description
        
        // 更新下载按钮的tag，用于标识行
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

// 自定义表格行视图，添加分隔线和悬停效果
class CustomTableRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        if self.selectionHighlightStyle != .none {
            super.drawSelection(in: dirtyRect)
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // 绘制底部分隔线
        let bottomLine = NSBezierPath()
        NSColor.separatorColor.withAlphaComponent(0.3).setStroke()
        bottomLine.move(to: NSPoint(x: 10, y: 0))
        bottomLine.line(to: NSPoint(x: self.bounds.width - 10, y: 0))
        bottomLine.stroke()
    }
    
    // 添加鼠标悬停效果
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        for trackingArea in self.trackingAreas {
            self.removeTrackingArea(trackingArea)
        }
        
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        let trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea)
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        self.layer?.backgroundColor = NSColor.clear.cgColor
    }
} 