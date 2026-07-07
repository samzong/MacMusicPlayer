import Cocoa
import Combine

private enum PanelCornerMetrics {
    static let panelRadius: CGFloat = 26
    static let selectionRadius: CGFloat = 8
}

private func applyContinuousPanelCorners(to view: NSView) {
    view.wantsLayer = true
    view.layer?.cornerRadius = PanelCornerMetrics.panelRadius
    view.layer?.cornerCurve = .continuous
    view.layer?.masksToBounds = true
}

private func fillRoundedRect(_ rect: NSRect, radius: CGFloat, color: NSColor) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    color.setFill()
    path.fill()
}

private final class PanelBorderView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        let insetRect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(
            roundedRect: insetRect,
            xRadius: PanelCornerMetrics.panelRadius,
            yRadius: PanelCornerMetrics.panelRadius
        )
        NSColor.white.withAlphaComponent(0.15).setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

private class PickerRowView: NSTableRowView {
    private var isHovering = false
    private let hoverLayer = CALayer()

    private var selectionRect: NSRect {
        bounds.insetBy(dx: 8, dy: 2)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        selectionHighlightStyle = .none
        hoverLayer.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor
        hoverLayer.isHidden = true
        wantsLayer = true
        layer?.addSublayer(hoverLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let rect = selectionRect
        hoverLayer.frame = rect
        hoverLayer.cornerRadius = PanelCornerMetrics.selectionRadius
        hoverLayer.cornerCurve = .continuous
    }

    override func draw(_ dirtyRect: NSRect) {
        if isSelected {
            fillRoundedRect(
                selectionRect,
                radius: PanelCornerMetrics.selectionRadius,
                color: .controlAccentColor
            )
        }
    }

    override func drawSelection(in dirtyRect: NSRect) {}

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }

        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovering = true
        updateHover(animated: true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovering = false
        updateHover(animated: true)
    }

    override var isSelected: Bool {
        didSet {
            updateHover(animated: true)
            needsDisplay = true
            updateCellAppearances()
        }
    }

    private func updateCellAppearances() {
        for subview in subviews {
            (subview as? PickerCellView)?.isRowSelected = isSelected
        }
    }

    private func updateHover(animated: Bool) {
        let shouldShow = isHovering && !isSelected

        if !animated {
            hoverLayer.isHidden = !shouldShow
            hoverLayer.opacity = shouldShow ? 1 : 0
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            if shouldShow {
                hoverLayer.isHidden = false
                hoverLayer.opacity = 1
            } else {
                hoverLayer.opacity = 0
            }
        } completionHandler: {
            if !shouldShow {
                self.hoverLayer.isHidden = true
            }
        }
    }
}

private class PickerCellView: NSTableCellView {
    var isCurrentTrack = false {
        didSet {
            updateTextAppearance()
        }
    }

    var isRowSelected = false {
        didSet {
            updateTextAppearance()
        }
    }

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
            updateTextAppearance()
        }
    }

    private func updateTextAppearance() {
        let isSelected = isRowSelected || backgroundStyle == .emphasized

        if isSelected {
            textField?.textColor = .alternateSelectedControlTextColor
            textField?.font = NSFont.systemFont(ofSize: 13, weight: isCurrentTrack ? .semibold : .regular)
        } else if isCurrentTrack {
            textField?.textColor = .controlAccentColor
            textField?.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        } else {
            textField?.textColor = .labelColor
            textField?.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        }
    }
}

class SimpleSongPickerWindow: NSPanel {
    private weak var playerManager: PlayerManager?
    private var searchField: NSTextField!
    private var tableView: NSTableView!
    private var statusLabel: NSTextField!
    private var contentHost: NSView!

    private var allTracks: [Track] = []
    private var filteredTracks: [Track] = []
    private var filterWorkItem: DispatchWorkItem?
    private var playlistCancellable: AnyCancellable?

    private let windowWidth: CGFloat = 600
    private let windowHeight: CGFloat = 400
    private let rowHeight: CGFloat = 36

    init(playerManager: PlayerManager) {
        self.playerManager = playerManager

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        setupWindow()
        setupViews()
        loadTracks()

        if let playerManager = self.playerManager {
            playlistCancellable = playerManager.$playlist
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.loadTracks()
                }
        }
    }

    override var canBecomeKey: Bool { true }

    deinit {
        filterWorkItem?.cancel()
        playlistCancellable?.cancel()
    }

    private func setupWindow() {
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        isReleasedWhenClosed = false
        hasShadow = true
        center()
    }

    private func setupBackground(in contentView: NSView) -> NSView {
        if #available(macOS 26.0, *) {
            let glassView = NSGlassEffectView()
            glassView.cornerRadius = PanelCornerMetrics.panelRadius
            glassView.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(glassView)

            NSLayoutConstraint.activate([
                glassView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                glassView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                glassView.topAnchor.constraint(equalTo: contentView.topAnchor),
                glassView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])

            let host = NSView()
            host.translatesAutoresizingMaskIntoConstraints = false
            applyContinuousPanelCorners(to: host)
            glassView.contentView = host
            NSLayoutConstraint.activate([
                host.leadingAnchor.constraint(equalTo: glassView.leadingAnchor),
                host.trailingAnchor.constraint(equalTo: glassView.trailingAnchor),
                host.topAnchor.constraint(equalTo: glassView.topAnchor),
                host.bottomAnchor.constraint(equalTo: glassView.bottomAnchor)
            ])
            return host
        } else {
            let visualEffect = NSVisualEffectView()
            visualEffect.material = .hudWindow
            visualEffect.blendingMode = .behindWindow
            visualEffect.state = .active
            applyContinuousPanelCorners(to: visualEffect)
            visualEffect.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(visualEffect)

            NSLayoutConstraint.activate([
                visualEffect.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                visualEffect.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                visualEffect.topAnchor.constraint(equalTo: contentView.topAnchor),
                visualEffect.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])

            return visualEffect
        }
    }

    private func setupViews() {
        guard let contentView = contentView else { return }

        applyContinuousPanelCorners(to: contentView)
        contentHost = setupBackground(in: contentView)

        let headerArea = NSView()
        headerArea.translatesAutoresizingMaskIntoConstraints = false
        contentHost.addSubview(headerArea)

        let searchIcon = NSImageView()
        searchIcon.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        searchIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        searchIcon.contentTintColor = .secondaryLabelColor
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        headerArea.addSubview(searchIcon)

        searchField = NSTextField()
        searchField.placeholderString = NSLocalizedString(
            "search_songs_placeholder",
            comment: "Placeholder text for the song search field"
        )
        searchField.isBezeled = false
        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.focusRingType = .none
        searchField.font = NSFont.systemFont(ofSize: 17, weight: .regular)
        searchField.textColor = .labelColor
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        headerArea.addSubview(searchField)

        let headerHairline = NSView()
        headerHairline.wantsLayer = true
        headerHairline.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
        headerHairline.translatesAutoresizingMaskIntoConstraints = false
        contentHost.addSubview(headerHairline)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.clipsToBounds = true
        contentHost.addSubview(scrollView)

        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.rowSizeStyle = .custom
        tableView.target = self
        tableView.doubleAction = #selector(playSelectedTrack)
        tableView.backgroundColor = .clear
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.gridStyleMask = []

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("track"))
        column.title = "Track"
        tableView.addTableColumn(column)

        scrollView.documentView = tableView

        let statusHairline = NSView()
        statusHairline.wantsLayer = true
        statusHairline.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
        statusHairline.translatesAutoresizingMaskIntoConstraints = false
        contentHost.addSubview(statusHairline)

        statusLabel = NSTextField(labelWithString: "Press Enter to play, Esc to Close")
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        contentHost.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            headerArea.topAnchor.constraint(equalTo: contentHost.topAnchor),
            headerArea.leadingAnchor.constraint(equalTo: contentHost.leadingAnchor),
            headerArea.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor),
            headerArea.heightAnchor.constraint(equalToConstant: 52),

            searchIcon.leadingAnchor.constraint(equalTo: headerArea.leadingAnchor, constant: 20),
            searchIcon.centerYAnchor.constraint(equalTo: headerArea.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 16),
            searchIcon.heightAnchor.constraint(equalToConstant: 16),

            searchField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 8),
            searchField.trailingAnchor.constraint(equalTo: headerArea.trailingAnchor, constant: -20),
            searchField.centerYAnchor.constraint(equalTo: headerArea.centerYAnchor),

            headerHairline.topAnchor.constraint(equalTo: headerArea.bottomAnchor),
            headerHairline.leadingAnchor.constraint(equalTo: contentHost.leadingAnchor),
            headerHairline.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor),
            headerHairline.heightAnchor.constraint(equalToConstant: 1),

            scrollView.topAnchor.constraint(equalTo: headerHairline.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: contentHost.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: statusHairline.topAnchor, constant: -8),

            statusHairline.leadingAnchor.constraint(equalTo: contentHost.leadingAnchor),
            statusHairline.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor),
            statusHairline.heightAnchor.constraint(equalToConstant: 1),

            statusLabel.leadingAnchor.constraint(equalTo: contentHost.leadingAnchor, constant: 20),
            statusLabel.topAnchor.constraint(equalTo: statusHairline.bottomAnchor, constant: 8),
            statusLabel.bottomAnchor.constraint(equalTo: contentHost.bottomAnchor, constant: -12)
        ])

        let borderOverlay = PanelBorderView()
        borderOverlay.translatesAutoresizingMaskIntoConstraints = false
        contentHost.addSubview(borderOverlay)

        NSLayoutConstraint.activate([
            borderOverlay.leadingAnchor.constraint(equalTo: contentHost.leadingAnchor),
            borderOverlay.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor),
            borderOverlay.topAnchor.constraint(equalTo: contentHost.topAnchor),
            borderOverlay.bottomAnchor.constraint(equalTo: contentHost.bottomAnchor)
        ])
    }

    override func makeKeyAndOrderFront(_ sender: Any?) {
        super.makeKeyAndOrderFront(sender)
        loadTracks()

        searchField.becomeFirstResponder()
        updateStatus()
    }

    override func close() {
        filterWorkItem?.cancel()
        super.close()
    }

    private func loadTracks() {
        guard let playerManager = playerManager else { return }
        allTracks = playerManager.playlist
        filterTracks()
    }

    private func filterTracks() {
        filterWorkItem?.cancel()

        let searchText = searchField.stringValue.lowercased()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            let filtered: [Track]
            if searchText.isEmpty {
                filtered = self.allTracks
            } else {
                filtered = self.allTracks.filter { track in
                    let filename = track.url.deletingPathExtension().lastPathComponent.lowercased()
                    return filename.contains(searchText)
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.filterWorkItem?.isCancelled == false else { return }

                self.filteredTracks = filtered
                self.tableView.reloadData()
                self.selectFirstRow()
                self.updateStatus()

                if filtered.isEmpty && !self.searchField.stringValue.isEmpty {
                    self.searchField.becomeFirstResponder()
                }
            }
        }

        filterWorkItem = workItem

        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }

    private func selectFirstRow() {
        guard !filteredTracks.isEmpty else { return }
        tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        tableView.scrollRowToVisible(0)
    }

    private func restoreSelection(for row: Int) {
        guard row >= 0, row < filteredTracks.count else { return }
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
    }

    private func updateStatus() {
        let count = filteredTracks.count
        if count == 0 {
            statusLabel.stringValue = NSLocalizedString("No results found", comment: "Status when no search results")
        } else {
            let songCountText = String.localizedStringWithFormat(
                NSLocalizedString("song_count_format", comment: "Format for song count"),
                count
            )
            let hintsText = NSLocalizedString("operation_hints", comment: "Keyboard operation hints")
            statusLabel.stringValue = "\(songCountText), \(hintsText)"
        }
    }

    private func findAllTrackIndex(for selectedRow: Int) -> Int? {
        guard selectedRow >= 0, selectedRow < filteredTracks.count else { return nil }
        let selectedTrack = filteredTracks[selectedRow]
        return allTracks.firstIndex(where: { $0.id == selectedTrack.id })
    }

    @objc private func playSelectedTrack() {
        guard let playerManager = playerManager,
              let allTrackIndex = findAllTrackIndex(for: tableView.selectedRow) else { return }

        playerManager.playTrack(at: allTrackIndex)
        close()
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76:
            playSelectedTrack()

        case 53:
            close()

        case 49:
            if searchField.currentEditor() == nil {
                guard let playerManager = playerManager,
                      let selectedRow = tableView.selectedRow >= 0 ? tableView.selectedRow : nil,
                      selectedRow < filteredTracks.count else { break }

                let track = filteredTracks[selectedRow]
                if playerManager.currentTrack?.id == track.id {
                    if playerManager.isPlaying {
                        playerManager.pause()
                    } else {
                        playerManager.play()
                    }
                } else {
                    if let allTrackIndex = findAllTrackIndex(for: selectedRow) {
                        playerManager.playTrack(at: allTrackIndex)
                        tableView.reloadData()
                        restoreSelection(for: selectedRow)
                    }
                }
            } else {
                super.keyDown(with: event)
            }

        default:
            if let characters = event.characters, !characters.isEmpty,
               characters.rangeOfCharacter(from: .alphanumerics) != nil {
                searchField.becomeFirstResponder()
                searchField.keyDown(with: event)
            } else {
                super.keyDown(with: event)
            }
        }
    }
}

extension SimpleSongPickerWindow: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredTracks.count
    }
}

extension SimpleSongPickerWindow: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return PickerRowView()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("TrackCell")

        var cellView = tableView.makeView(withIdentifier: identifier, owner: self) as? PickerCellView
        if cellView == nil {
            cellView = PickerCellView()
            cellView?.identifier = identifier

            let textField = NSTextField()
            textField.isBordered = false
            textField.isEditable = false
            textField.backgroundColor = .clear
            textField.lineBreakMode = .byTruncatingTail
            textField.usesSingleLineMode = true
            textField.maximumNumberOfLines = 1
            textField.translatesAutoresizingMaskIntoConstraints = false
            cellView?.addSubview(textField)
            cellView?.textField = textField

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 12),
                textField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -12),
                textField.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor)
            ])
        }

        if row < filteredTracks.count {
            let track = filteredTracks[row]
            let filename = track.url.deletingPathExtension().lastPathComponent
            let isCurrentTrack = track.id == playerManager?.currentTrack?.id

            cellView?.textField?.stringValue = filename
            cellView?.isCurrentTrack = isCurrentTrack
            cellView?.isRowSelected = tableView.selectedRow == row
        }

        return cellView
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return rowHeight
    }

    func tableView(_ tableView: NSTableView,
                   shouldTypeSelectFor event: NSEvent,
                   withCurrentSearch searchString: String?) -> Bool {
        return false
    }

}

extension SimpleSongPickerWindow: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        filterTracks()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            close()
            return true
        }

        if commandSelector == #selector(NSResponder.moveUp(_:)) {
            let currentRow = tableView.selectedRow
            if currentRow > 0 {
                let newRow = currentRow - 1
                tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
                tableView.scrollRowToVisible(newRow)
            } else if currentRow < 0, !filteredTracks.isEmpty {
                selectFirstRow()
            }
            return true
        }

        if commandSelector == #selector(NSResponder.moveDown(_:)) {
            let currentRow = tableView.selectedRow
            if currentRow < filteredTracks.count - 1 {
                let newRow = currentRow + 1
                tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
                tableView.scrollRowToVisible(newRow)
            } else if currentRow < 0, !filteredTracks.isEmpty {
                selectFirstRow()
            }
            return true
        }

        return false
    }
}