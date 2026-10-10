import Cocoa

@MainActor
class DownloadViewController: NSViewController {
    private let libraryManager: LibraryManager
    private weak var actionTarget: AppDelegate?
    private let sourceField = NSTextField()
    private let sourceSymbol = NSImageView()
    private let fetchButton = NSButton()
    private let libraryPopup = NSPopUpButton()
    private let downloadButton = NSButton()
    private let backgroundButton = NSButton()
    private let stopButton = NSButton()
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let progressIndicator = NSProgressIndicator()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let summaryLabel = NSTextField(labelWithString: "")
    private let durationLabel = NSTextField(labelWithString: "")
    private let formatPopup = NSPopUpButton()
    private let selectAllButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let selectionLabel = NSTextField(labelWithString: "")
    private let nextPageButton = NSButton()
    private let settingsButton = NSButton()
    private var layoutStack: NSStackView!
    private var scrollHeight: NSLayoutConstraint!
    private var contentStack: NSStackView!
    private var audioStack: NSStackView!
    private var playlistHeader: NSStackView!
    private var statusStack: NSStackView!
    private var selectedDestinationID: UUID?
    private var audioInfo: DownloadManager.AudioInfo?
    private var audioURL: String?
    private var playlistInfo: DownloadManager.PlaylistInfo?
    private var selectedPlaylistRows = Set<Int>()
    private var searchResults: [YTSearchManager.SearchResult.VideoItem] = []
    private var nextPageToken: String?
    private var loadID: UUID?
    private var loadTask: Task<Void, Never>?
    private var downloadID: UUID?
    private var downloadTask: Task<Void, Never>?
    private var isStopping = false
    private(set) var isDownloading = false

    init(libraryManager: LibraryManager, actionTarget: AppDelegate) {
        self.libraryManager = libraryManager
        self.actionTarget = actionTarget
        selectedDestinationID = libraryManager.currentLibrary?.id
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 218))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        NotificationCenter.default.addObserver(
            self, selector: #selector(librariesChanged),
            name: NSNotification.Name("LibrariesChanged"), object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(configChanged),
            name: NSNotification.Name("ConfigUpdated"), object: nil
        )
        updateLibraries()
        render()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        render()
    }

    private var input: String { sourceField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var isLink: Bool { input.hasPrefix("http://") || input.hasPrefix("https://") }

    private var destination: MusicLibrary? {
        libraryManager.libraries.first { $0.id == selectedDestinationID }
    }

    private func row(_ views: [NSView], spacing: CGFloat = 12) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.distribution = .fill
        stack.spacing = spacing
        return stack
    }

    private func column(_ views: [NSView], spacing: CGFloat = 12) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        return stack
    }

    private func configure(_ button: NSButton, title: String, action: Selector) {
        button.title = NSLocalizedString(title, comment: "")
        button.bezelStyle = .rounded
        button.font = .systemFont(ofSize: 12)
        button.target = self
        button.action = action
    }

    private func setupViews() {
        let host: NSView
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.cornerRadius = 20
            host = NSView()
            glass.contentView = host
            glass.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(glass)
            NSLayoutConstraint.activate([
                glass.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                glass.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                glass.topAnchor.constraint(equalTo: view.topAnchor),
                glass.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        } else {
            let material = NSVisualEffectView()
            material.material = .hudWindow
            material.blendingMode = .behindWindow
            material.state = .active
            host = material
            view.addSubview(host)
        }
        host.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.topAnchor.constraint(equalTo: view.topAnchor),
            host.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let title = NSTextField(labelWithString: NSLocalizedString("Download Music", comment: ""))
        title.font = .systemFont(ofSize: 16, weight: .medium)

        sourceField.placeholderString = NSLocalizedString("Paste a link or enter a song or artist", comment: "")
        sourceField.font = .systemFont(ofSize: 13)
        sourceField.bezelStyle = .roundedBezel
        sourceField.focusRingType = .none
        sourceField.delegate = self
        sourceField.target = self
        sourceField.action = #selector(fetchSource)
        sourceField.setAccessibilityLabel(NSLocalizedString("Music Source", comment: ""))
        sourceField.identifier = NSUserInterfaceItemIdentifier("DownloadSource")
        sourceSymbol.contentTintColor = .secondaryLabelColor
        sourceSymbol.widthAnchor.constraint(equalToConstant: 16).isActive = true
        sourceSymbol.heightAnchor.constraint(equalToConstant: 16).isActive = true
        sourceField.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal)
        configure(fetchButton, title: "Parse", action: #selector(fetchSource))
        fetchButton.identifier = NSUserInterfaceItemIdentifier("FetchSource")
        fetchButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 72).isActive = true
        let sourceRow = row([sourceSymbol, sourceField, fetchButton], spacing: 8)

        summaryLabel.font = .systemFont(ofSize: 13)
        summaryLabel.lineBreakMode = .byTruncatingTail
        summaryLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        summaryLabel.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal)
        durationLabel.font = .systemFont(ofSize: 11)
        durationLabel.textColor = .secondaryLabelColor
        durationLabel.setContentHuggingPriority(.required, for: .horizontal)
        let summary = row([summaryLabel, durationLabel])
        let formatLabel = NSTextField(labelWithString: NSLocalizedString("Audio Source Format", comment: ""))
        formatLabel.font = .systemFont(ofSize: 12)
        formatLabel.textColor = .secondaryLabelColor
        formatPopup.identifier = NSUserInterfaceItemIdentifier("AudioSourceFormat")
        formatPopup.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal)
        let formatRow = row([formatLabel, formatPopup])
        audioStack = column([summary, formatRow])
        summary.widthAnchor.constraint(equalTo: audioStack.widthAnchor).isActive = true
        formatRow.widthAnchor.constraint(equalTo: audioStack.widthAnchor).isActive = true

        selectAllButton.title = NSLocalizedString("Select All", comment: "")
        selectAllButton.allowsMixedState = true
        selectAllButton.target = self
        selectAllButton.action = #selector(toggleAll)
        selectionLabel.font = .systemFont(ofSize: 11)
        selectionLabel.textColor = .secondaryLabelColor
        let spacer = NSView()
        spacer.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal)
        playlistHeader = row([selectAllButton, spacer, selectionLabel])

        let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("DownloadItems"))
        tableView.addTableColumn(tableColumn)
        tableView.headerView = nil
        tableView.rowHeight = 36
        tableView.intercellSpacing = .zero
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollHeight = scrollView.heightAnchor.constraint(equalToConstant: 216)
        scrollHeight.isActive = true
        configure(nextPageButton, title: "View more", action: #selector(loadNextPage))
        nextPageButton.bezelStyle = .inline
        nextPageButton.contentTintColor = .controlAccentColor
        contentStack = column([audioStack, playlistHeader, scrollView, nextPageButton], spacing: 8)
        for child in [audioStack!, playlistHeader!, scrollView] {
            child.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        }

        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.widthAnchor.constraint(equalToConstant: 16).isActive = true
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.maximumNumberOfLines = 3
        statusLabel.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal)
        configure(settingsButton, title: "Go to settings", action: #selector(openSettings))
        settingsButton.bezelStyle = .inline
        statusStack = row([progressIndicator, statusLabel, settingsButton], spacing: 8)

        let saveLabel = NSTextField(labelWithString: NSLocalizedString("Save to", comment: ""))
        saveLabel.font = .systemFont(ofSize: 12)
        saveLabel.textColor = .secondaryLabelColor
        libraryPopup.font = .systemFont(ofSize: 12)
        libraryPopup.target = self
        libraryPopup.action = #selector(selectLibrary)
        libraryPopup.identifier = NSUserInterfaceItemIdentifier("DownloadDestination")
        libraryPopup.setAccessibilityLabel(NSLocalizedString("Save to", comment: ""))
        libraryPopup.widthAnchor.constraint(lessThanOrEqualToConstant: 160).isActive = true
        let footerSpacer = NSView()
        footerSpacer.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal)
        configure(downloadButton, title: "Start Download", action: #selector(startDownload))
        downloadButton.identifier = NSUserInterfaceItemIdentifier("StartDownload")
        downloadButton.bezelColor = .controlAccentColor
        downloadButton.contentTintColor = .white
        configure(backgroundButton, title: "Background Download", action: #selector(hideWindow))
        backgroundButton.bezelStyle = .inline
        backgroundButton.contentTintColor = .controlAccentColor
        configure(stopButton, title: "Stop", action: #selector(stopDownload))
        let footer = row([saveLabel, libraryPopup, footerSpacer, backgroundButton, stopButton, downloadButton], spacing: 8)
        let separator = NSBox()
        separator.boxType = .separator
        let stack = column([title, sourceRow, contentStack, statusStack, separator, footer], spacing: 16)
        layoutStack = stack
        stack.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: host.topAnchor, constant: 40),
            stack.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -24)
        ])
        for child in [title, sourceRow, contentStack!, statusStack!, separator, footer] {
            child.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
    }

    private func render() {
        fetchButton.title = NSLocalizedString(isLink ? (DownloadManager.shared.isPlaylistURL(input) ? "Load" : "Parse") : "Find", comment: "")
        sourceSymbol.image = NSImage(systemSymbolName: isLink || input.isEmpty ? "link" : "magnifyingglass", accessibilityDescription: nil)
        sourceField.isEnabled = !isDownloading
        fetchButton.isEnabled = !input.isEmpty && !isDownloading && loadID == nil
        libraryPopup.isEnabled = !isDownloading && !libraryManager.libraries.isEmpty
        formatPopup.isEnabled = !isDownloading
        selectAllButton.isEnabled = !isDownloading
        audioStack.isHidden = audioInfo == nil
        playlistHeader.isHidden = playlistInfo == nil
        scrollView.isHidden = playlistInfo == nil && searchResults.isEmpty
        nextPageButton.isHidden = nextPageToken == nil || audioInfo != nil || playlistInfo != nil
        nextPageButton.isEnabled = !isDownloading && loadID == nil
        contentStack.isHidden = audioInfo == nil && playlistInfo == nil && searchResults.isEmpty
        settingsButton.isHidden = isLink || ConfigManager.shared.isConfigValid || statusLabel.stringValue.isEmpty
        statusStack.isHidden = statusLabel.stringValue.isEmpty && loadID == nil && !isDownloading
        progressIndicator.isHidden = loadID == nil && !isDownloading
        if progressIndicator.isHidden { progressIndicator.stopAnimation(nil) } else { progressIndicator.startAnimation(nil) }
        backgroundButton.isHidden = !isDownloading
        stopButton.isHidden = !isDownloading
        stopButton.isEnabled = !isStopping
        downloadButton.isHidden = isDownloading
        downloadButton.title = playlistInfo == nil ? NSLocalizedString("Start Download", comment: "") :
            String(format: NSLocalizedString("Download Selected (%d)", comment: ""), selectedPlaylistRows.count)
        downloadButton.isEnabled = loadID == nil && destination != nil &&
            (audioInfo != nil || (playlistInfo != nil && !selectedPlaylistRows.isEmpty))
        if let playlistInfo {
            selectAllButton.state = selectedPlaylistRows.isEmpty ? .off :
                (selectedPlaylistRows.count == playlistInfo.items.count ? .on : .mixed)
            selectionLabel.stringValue = String(format: NSLocalizedString("Selected %d / %d", comment: ""), selectedPlaylistRows.count, playlistInfo.items.count)
        }
        tableView.reloadData()
        resizeWindow()
    }

    private func resizeWindow() {
        guard let window = view.window else { return }
        let rowCount = playlistInfo?.items.count ?? searchResults.count
        scrollHeight.constant = CGFloat(min(6, max(1, rowCount))) * 36
        view.layoutSubtreeIfNeeded()
        let height = ceil(layoutStack.fittingSize.height + 56)
        let oldTop = window.frame.maxY
        window.setContentSize(NSSize(width: 600, height: height))
        window.setFrameOrigin(NSPoint(x: window.frame.minX, y: oldTop - window.frame.height))
    }

    private func clearContent() {
        audioInfo = nil
        audioURL = nil
        playlistInfo = nil
        searchResults = []
        selectedPlaylistRows = []
        nextPageToken = nil
        formatPopup.removeAllItems()
        settingsButton.isHidden = true
        statusLabel.stringValue = ""
    }

    private func invalidateLoad() {
        loadID = nil
        loadTask?.cancel()
        loadTask = nil
    }

    func controlTextDidChange(_ obj: Notification) {
        guard !isDownloading else { return }
        invalidateLoad()
        clearContent()
        render()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            fetchSource()
            return true
        }
        return false
    }

    @objc private func configChanged() {
        guard !isDownloading, !isLink else { return }
        invalidateLoad()
        clearContent()
        render()
    }

    @objc private func librariesChanged() {
        guard !isDownloading else { return }
        updateLibraries()
        render()
    }

    private func updateLibraries() {
        libraryPopup.removeAllItems()
        for library in libraryManager.libraries {
            libraryPopup.addItem(withTitle: library.name)
            libraryPopup.lastItem?.representedObject = library.id
        }
        if let index = libraryManager.libraries.firstIndex(where: { $0.id == selectedDestinationID }) {
            libraryPopup.selectItem(at: index)
        } else {
            selectedDestinationID = libraryManager.libraries.first?.id
            libraryPopup.selectItem(at: 0)
        }
    }

    @objc private func selectLibrary() {
        guard !isDownloading else { return }
        selectedDestinationID = libraryPopup.selectedItem?.representedObject as? UUID
        render()
    }

    @objc private func fetchSource() {
        guard !input.isEmpty, !isDownloading, loadID == nil else { return }
        clearContent()
        if isLink {
            if DownloadManager.shared.isPlaylistURL(input) { loadPlaylist(url: input) }
            else { loadAudio(url: input) }
        } else {
            search(keyword: input)
        }
    }

    private func beginLoad(status: String) -> UUID {
        invalidateLoad()
        let id = UUID()
        loadID = id
        statusLabel.stringValue = NSLocalizedString(status, comment: "")
        statusLabel.textColor = .secondaryLabelColor
        render()
        return id
    }

    private func finishLoad(id: UUID, error: Error? = nil) {
        guard loadID == id else { return }
        loadID = nil
        loadTask = nil
        if let error {
            statusLabel.stringValue = error.localizedDescription
            statusLabel.textColor = .systemRed
        } else {
            statusLabel.stringValue = ""
        }
        render()
    }

    private func loadAudio(url: String) {
        let id = beginLoad(status: "Parsing...")
        loadTask = Task {
            do {
                let info = try await DownloadManager.shared.fetchAudioInfo(from: url)
                guard loadID == id, !Task.isCancelled else { return }
                audioInfo = info
                audioURL = url
                playlistInfo = nil
                searchResults = []
                nextPageToken = nil
                summaryLabel.stringValue = info.title
                summaryLabel.toolTip = info.title
                durationLabel.stringValue = info.duration
                formatPopup.removeAllItems()
                for format in info.formats {
                    formatPopup.addItem(withTitle: format.description)
                    formatPopup.lastItem?.representedObject = format.formatId
                }
                finishLoad(id: id)
            } catch {
                finishLoad(id: id, error: error)
            }
        }
    }

    private func loadPlaylist(url: String) {
        let id = beginLoad(status: "Loading playlist information...")
        loadTask = Task {
            do {
                let info = try await DownloadManager.shared.fetchPlaylistInfo(from: url)
                guard loadID == id, !Task.isCancelled else { return }
                playlistInfo = info
                selectedPlaylistRows = Set(info.items.indices)
                selectAllButton.title = info.title
                selectAllButton.toolTip = info.title
                finishLoad(id: id)
            } catch {
                finishLoad(id: id, error: error)
            }
        }
    }

    private func search(keyword: String, pageToken: String? = nil) {
        guard ConfigManager.shared.isConfigValid else {
            statusLabel.stringValue = NSLocalizedString("Please configure the search service API (API URL and API Key)", comment: "")
            statusLabel.textColor = .systemRed
            render()
            return
        }
        let id = beginLoad(status: "Searching...")
        YTSearchManager.shared.search(keyword: keyword, pageToken: pageToken) { [weak self] result in
            guard let self, self.loadID == id else { return }
            switch result {
            case .success(let result):
                self.searchResults.append(contentsOf: result.items)
                self.nextPageToken = result.nextPageToken.flatMap { $0.isEmpty ? nil : $0 }
                self.finishLoad(id: id)
                if self.searchResults.isEmpty {
                    self.statusLabel.stringValue = NSLocalizedString("No results found", comment: "")
                    self.render()
                }
            case .failure(let error):
                self.finishLoad(id: id, error: error)
            }
        }
    }

    @objc private func loadNextPage() {
        guard let nextPageToken, !isDownloading, loadID == nil else { return }
        search(keyword: input, pageToken: nextPageToken)
    }

    @objc private func chooseVideo(_ sender: NSButton) {
        guard !isDownloading, loadID == nil, searchResults.indices.contains(sender.tag) else { return }
        loadAudio(url: searchResults[sender.tag].videoUrl)
    }

    @objc private func toggleAll() {
        guard !isDownloading, let playlistInfo else { return }
        selectedPlaylistRows = selectAllButton.state == .off ? [] : Set(playlistInfo.items.indices)
        render()
    }

    @objc private func toggleItem(_ sender: NSButton) {
        guard !isDownloading, let playlistInfo, playlistInfo.items.indices.contains(sender.tag) else { return }
        if sender.state == .on { selectedPlaylistRows.insert(sender.tag) }
        else { selectedPlaylistRows.remove(sender.tag) }
        render()
    }

    @objc private func startDownload() {
        guard !input.isEmpty, !isDownloading, loadID == nil, let destination else { return }
        let items: [DownloadManager.PlaylistItem]
        let format: String
        if let playlistInfo {
            items = selectedPlaylistRows.sorted().compactMap { playlistInfo.items.indices.contains($0) ? playlistInfo.items[$0] : nil }
            format = "bestaudio"
        } else if let audioInfo, let audioURL, let selectedFormat = formatPopup.selectedItem?.representedObject as? String {
            items = [DownloadManager.PlaylistItem(title: audioInfo.title, url: audioURL, duration: audioInfo.duration)]
            format = selectedFormat
        } else { return }
        guard !items.isEmpty else { return }
        let isPlaylist = playlistInfo != nil
        let id = UUID()
        downloadID = id
        isDownloading = true
        isStopping = false
        statusLabel.stringValue = NSLocalizedString("Downloading", comment: "")
        statusLabel.textColor = .secondaryLabelColor
        render()
        notifyDownloadState()
        downloadTask = Task { [self] in
            do {
                if isPlaylist {
                    let result = try await DownloadManager.shared.downloadPlaylistItems(items, destination: destination) { [weak self] progress in
                        Task { @MainActor in
                            guard let self, self.downloadID == id, !self.isStopping else { return }
                            self.statusLabel.stringValue = String(
                                format: NSLocalizedString("Downloaded %d / %d · Failed %d · %@", comment: ""),
                                progress.completedCount, progress.totalCount, progress.failedCount, progress.currentTitle
                            )
                        }
                    }
                    try Task.checkCancellation()
                    let text = String(format: NSLocalizedString("Downloaded %d / %d · Failed %d", comment: ""), result.completedCount, items.count, result.failedCount)
                    finishDownload(id: id, message: text, failed: result.failedCount > 0)
                } else {
                    try await DownloadManager.shared.downloadAudio(
                        from: items[0].url, formatId: format, destination: destination, outputTitle: items[0].title
                    )
                    try Task.checkCancellation()
                    finishDownload(id: id, message: NSLocalizedString("Download completed", comment: ""))
                }
            } catch is CancellationError {
                finishDownload(id: id, message: NSLocalizedString("Download stopped", comment: ""))
            } catch {
                finishDownload(id: id, message: error.localizedDescription, failed: true)
            }
        }
    }

    private func finishDownload(id: UUID, message: String, failed: Bool = false) {
        guard downloadID == id else { return }
        downloadID = nil
        isDownloading = false
        isStopping = false
        downloadTask = nil
        statusLabel.stringValue = message
        statusLabel.textColor = failed ? .systemRed : .secondaryLabelColor
        updateLibraries()
        render()
        notifyDownloadState()
    }

    private func notifyDownloadState() {
        NotificationCenter.default.post(name: NSNotification.Name("DownloadStateChanged"), object: nil)
    }

    @objc private func stopDownload() {
        guard isDownloading, !isStopping else { return }
        isStopping = true
        statusLabel.stringValue = NSLocalizedString("Stopping download...", comment: "")
        downloadTask?.cancel()
        render()
    }

    @objc private func hideWindow() {
        view.window?.orderOut(nil)
    }

    @objc private func openSettings() {
        actionTarget?.showConfigWindow()
    }
}

extension DownloadViewController: NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        playlistInfo?.items.count ?? searchResults.count
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { false }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row index: Int) -> NSView? {
        let title: String
        let duration: String
        let leading: NSView
        if let playlistInfo {
            let item = playlistInfo.items[index]
            title = item.title
            duration = item.duration
            let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleItem(_:)))
            checkbox.tag = index
            checkbox.state = selectedPlaylistRows.contains(index) ? .on : .off
            checkbox.isEnabled = !isDownloading
            checkbox.setAccessibilityLabel(item.title)
            leading = checkbox
        } else {
            let item = searchResults[index]
            title = item.title
            duration = ""
            leading = NSView()
        }
        leading.setContentHuggingPriority(.required, for: .horizontal)
        let name = NSTextField(labelWithString: title)
        name.font = .systemFont(ofSize: 13)
        name.lineBreakMode = .byTruncatingTail
        name.toolTip = title
        name.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal)
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let time = NSTextField(labelWithString: duration)
        time.font = .systemFont(ofSize: 11)
        time.textColor = .secondaryLabelColor
        time.setContentHuggingPriority(.required, for: .horizontal)
        var views = [leading, name, time]
        if playlistInfo == nil {
            let choose = NSButton()
            configure(choose, title: "Use", action: #selector(chooseVideo(_:)))
            choose.tag = index
            choose.isEnabled = !isDownloading && loadID == nil
            views.append(choose)
        }
        let cell = row(views, spacing: 8)
        cell.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 4)
        return cell
    }
}
