import Cocoa
import Combine

private enum PanelCornerMetrics {
    static let panelRadius: CGFloat = 20
    static let selectionRadius: CGFloat = 10
}

private func applyContinuousPanelCorners(to view: NSView) {
    view.wantsLayer = true
    view.layer?.cornerRadius = PanelCornerMetrics.panelRadius
    view.layer?.cornerCurve = .continuous
    view.layer?.masksToBounds = true
}

private final class PanelBorderView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
            xRadius: PanelCornerMetrics.panelRadius,
            yRadius: PanelCornerMetrics.panelRadius
        )
        NSColor.white.withAlphaComponent(0.15).setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

private final class PickerButton: NSButton {
    private var hovering = false

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) {
        hovering = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hovering = false
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        if isEnabled && (hovering || cell?.isHighlighted == true) {
            NSColor.labelColor.withAlphaComponent(cell?.isHighlighted == true ? 0.12 : 0.06).setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()
        }
        super.draw(dirtyRect)
    }
}

private final class PickerRowView: NSTableRowView {
    private var hovering = false

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) {
        hovering = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hovering = false
        needsDisplay = true
    }

    override var isSelected: Bool {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        if isSelected || hovering {
            NSColor.labelColor.withAlphaComponent(isSelected ? 0.08 : 0.05).setFill()
            NSBezierPath(
                roundedRect: bounds.insetBy(dx: 0, dy: 2),
                xRadius: PanelCornerMetrics.selectionRadius,
                yRadius: PanelCornerMetrics.selectionRadius
            ).fill()
        }
    }

    override func drawSelection(in dirtyRect: NSRect) {}
}

private final class PickerTableView: NSTableView {
    override func keyDown(with event: NSEvent) {
        if [36, 76, 53, 49].contains(event.keyCode) {
            window?.keyDown(with: event)
        } else {
            super.keyDown(with: event)
        }
    }
}

class SimpleSongPickerWindow: NSPanel {
    private let playerManager: PlayerManager
    private let libraryManager: LibraryManager
    private weak var actionTarget: AppDelegate?
    private var searchField: NSTextField!
    private var tableView: NSTableView!
    private var contentHost: NSView!
    private var libraryButton: PickerButton!
    private var luckyButton: PickerButton!
    private var previousButton: PickerButton!
    private var playButton: PickerButton!
    private var nextButton: PickerButton!
    private var modeButton: PickerButton!
    private var moreButton: PickerButton!
    private var emptyLabel: NSTextField!
    private var filteredTracks: [Track] = []
    private var displayedLibraryID: UUID?
    private var subscriptions = Set<AnyCancellable>()

    init(playerManager: PlayerManager, libraryManager: LibraryManager, actionTarget: AppDelegate) {
        self.playerManager = playerManager
        self.libraryManager = libraryManager
        self.actionTarget = actionTarget
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        isReleasedWhenClosed = false
        hasShadow = true
        center()
        setupViews()
        playerManager.$playlist.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.synchronizeLibrary()
        }.store(in: &subscriptions)
        for name in ["TrackChanged", "PlaybackStateChanged", "PlayModeChanged", "LibrariesChanged", "PlaylistUpdated"] {
            NotificationCenter.default.publisher(for: NSNotification.Name(name))
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.synchronizeLibrary() }
                .store(in: &subscriptions)
        }
        synchronizeLibrary()
    }

    override var canBecomeKey: Bool { true }

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
        guard let contentView else { return }
        applyContinuousPanelCorners(to: contentView)
        contentHost = setupBackground(in: contentView)

        let header = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false
        contentHost.addSubview(header)
        let searchIcon = NSImageView()
        searchIcon.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        searchIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        searchIcon.contentTintColor = .secondaryLabelColor
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(searchIcon)
        searchField = NSTextField()
        searchField.placeholderString = NSLocalizedString("search_songs_placeholder", comment: "")
        searchField.setAccessibilityLabel(NSLocalizedString("Search", comment: ""))
        searchField.isBezeled = false
        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.focusRingType = .none
        searchField.font = .systemFont(ofSize: 17)
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(searchField)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        contentHost.addSubview(scroll)
        tableView = PickerTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.rowSizeStyle = .custom
        tableView.rowHeight = 36
        tableView.intercellSpacing = .zero
        tableView.target = self
        tableView.doubleAction = #selector(playSelectedTrack)
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .none
        tableView.focusRingType = .none
        tableView.gridStyleMask = []
        tableView.setAccessibilityLabel(NSLocalizedString("Browse Songs", comment: ""))
        tableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("track")))
        scroll.documentView = tableView

        emptyLabel = NSTextField(labelWithString: "")
        emptyLabel.font = .systemFont(ofSize: 13)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        contentHost.addSubview(emptyLabel)
        let footer = NSView()
        footer.translatesAutoresizingMaskIntoConstraints = false
        contentHost.addSubview(footer)
        for area in [header, footer] {
            let line = NSBox()
            line.boxType = .separator
            line.translatesAutoresizingMaskIntoConstraints = false
            contentHost.addSubview(line)
            NSLayoutConstraint.activate([
                line.leadingAnchor.constraint(equalTo: contentHost.leadingAnchor),
                line.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor),
                line.heightAnchor.constraint(equalToConstant: 1),
                line.topAnchor.constraint(equalTo: area == header ? header.bottomAnchor : footer.topAnchor)
            ])
        }
        libraryButton = makeButton(symbol: "folder", title: "Music Libraries", action: #selector(showLibraries), size: 32)
        libraryButton.imagePosition = .imageLeading
        libraryButton.alignment = .center
        libraryButton.font = .systemFont(ofSize: 12)
        libraryButton.cell?.lineBreakMode = .byTruncatingTail
        luckyButton = makeButton(symbol: "wand.and.stars", title: "Feeling Lucky", action: #selector(feelingLucky), size: 32)
        previousButton = makeButton(symbol: "backward.end.fill", title: "Previous", action: #selector(playPrevious), size: 32)
        playButton = makeButton(symbol: "play.fill", title: "Play", action: #selector(togglePlayback), size: 32)
        nextButton = makeButton(symbol: "forward.end.fill", title: "Next", action: #selector(playNext), size: 32)
        modeButton = makeButton(symbol: "repeat", title: "Playback Mode", action: #selector(showModes), size: 28)
        moreButton = makeButton(symbol: "ellipsis", title: "More", action: #selector(showMore), size: 28)
        let transport = NSStackView(views: [luckyButton, previousButton, playButton, nextButton, modeButton])
        transport.orientation = .horizontal
        transport.alignment = .centerY
        transport.spacing = 10
        transport.setCustomSpacing(18, after: luckyButton)
        transport.setCustomSpacing(18, after: nextButton)
        transport.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(transport)
        footer.addSubview(libraryButton)
        footer.addSubview(moreButton)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: contentHost.topAnchor),
            header.leadingAnchor.constraint(equalTo: contentHost.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 52),
            searchIcon.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            searchIcon.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 17),
            searchIcon.heightAnchor.constraint(equalToConstant: 17),
            searchField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 10),
            searchField.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -20),
            searchField.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: contentHost.leadingAnchor, constant: 8),
            scroll.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor, constant: -8),
            scroll.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -8),
            footer.leadingAnchor.constraint(equalTo: contentHost.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: contentHost.bottomAnchor),
            footer.heightAnchor.constraint(equalToConstant: 52),
            libraryButton.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 16),
            libraryButton.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
            libraryButton.widthAnchor.constraint(lessThanOrEqualToConstant: 164),
            libraryButton.trailingAnchor.constraint(lessThanOrEqualTo: transport.leadingAnchor, constant: -14),
            transport.centerXAnchor.constraint(equalTo: footer.centerXAnchor),
            transport.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
            moreButton.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -16),
            moreButton.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
            emptyLabel.centerXAnchor.constraint(equalTo: scroll.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scroll.centerYAnchor)
        ])
        let border = PanelBorderView()
        border.translatesAutoresizingMaskIntoConstraints = false
        contentHost.addSubview(border)
        NSLayoutConstraint.activate([
            border.leadingAnchor.constraint(equalTo: contentHost.leadingAnchor),
            border.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor),
            border.topAnchor.constraint(equalTo: contentHost.topAnchor),
            border.bottomAnchor.constraint(equalTo: contentHost.bottomAnchor)
        ])
    }

    private func makeButton(symbol: String, title: String, action: Selector, size: CGFloat) -> PickerButton {
        let button = PickerButton()
        button.title = ""
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: size == 32 ? 15 : 13, weight: .regular))
        button.imagePosition = .imageOnly
        button.isBordered = false
        button.setButtonType(.momentaryChange)
        button.contentTintColor = .labelColor
        button.toolTip = NSLocalizedString(title, comment: "")
        button.setAccessibilityLabel(button.toolTip)
        button.target = self
        button.action = action
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: size).isActive = true
        if title != "Music Libraries" {
            button.widthAnchor.constraint(equalToConstant: size).isActive = true
        }
        return button
    }

    override func makeKeyAndOrderFront(_ sender: Any?) {
        synchronizeLibrary()
        super.makeKeyAndOrderFront(sender)
        makeFirstResponder(searchField)
    }

    private var selectedTrackID: UUID? {
        guard filteredTracks.indices.contains(tableView.selectedRow) else { return nil }
        return filteredTracks[tableView.selectedRow].id
    }

    private func synchronizeLibrary() {
        let libraryID = libraryManager.currentLibrary?.id
        let libraryChanged = displayedLibraryID != libraryID
        if libraryChanged {
            displayedLibraryID = libraryID
            searchField.stringValue = ""
            filteredTracks = []
        }
        filterTracks(preservingSelection: !libraryChanged)
        updateControls()
    }

    private func filterTracks(preservingSelection: Bool) {
        let selectedID = preservingSelection ? selectedTrackID : nil
        let query = searchField.stringValue
        filteredTracks = playerManager.playlist.filter {
            query.isEmpty || $0.url.deletingPathExtension().lastPathComponent.localizedCaseInsensitiveContains(query)
        }
        tableView.reloadData()
        tableView.deselectAll(nil)
        let preferredID = selectedID ?? (query.isEmpty ? playerManager.currentTrack?.id : nil)
        let row = preferredID.flatMap { id in filteredTracks.firstIndex { $0.id == id } } ?? 0
        selectRow(row, scrollIntoView: !preservingSelection || selectedID == nil)
        emptyLabel.isHidden = !filteredTracks.isEmpty
        emptyLabel.stringValue = NSLocalizedString(query.isEmpty ? "No Music Source" : "No results found", comment: "")
    }

    private func selectRow(_ row: Int, scrollIntoView: Bool = true) {
        guard filteredTracks.indices.contains(row) else { return }
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        if scrollIntoView {
            tableView.scrollRowToVisible(row)
        }
    }

    private func updateControls() {
        let name = libraryManager.currentLibrary?.name ?? NSLocalizedString("Music Libraries", comment: "")
        libraryButton.title = name
        libraryButton.toolTip = name
        libraryButton.setAccessibilityLabel(NSLocalizedString("Music Libraries", comment: "") + ": " + name)
        libraryButton.isEnabled = !libraryManager.libraries.isEmpty
        let hasTracks = !playerManager.playlist.isEmpty
        luckyButton.isEnabled = hasTracks
        previousButton.isEnabled = hasTracks
        nextButton.isEnabled = hasTracks
        playButton.isEnabled = hasTracks && playerManager.currentTrack != nil
        let playTitle = NSLocalizedString(playerManager.isPlaying ? "Pause" : "Play", comment: "")
        playButton.toolTip = playTitle
        playButton.setAccessibilityLabel(playTitle)
        playButton.image = NSImage(systemSymbolName: playerManager.isPlaying ? "pause.fill" : "play.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 15, weight: .regular))
        let modeTitle = NSLocalizedString("Playback Mode", comment: "") + ": " + playerManager.playMode.localizedString
        modeButton.toolTip = modeTitle
        modeButton.setAccessibilityLabel(modeTitle)
        let symbol: String
        switch playerManager.playMode {
        case .sequential: symbol = "repeat"
        case .singleLoop: symbol = "repeat.1"
        case .random: symbol = "shuffle"
        }
        modeButton.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .regular))
    }

    private func popUp(_ menu: NSMenu, above button: NSButton) {
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY + 6), in: button)
    }

    @objc private func showLibraries() {
        let menu = NSMenu()
        for library in libraryManager.libraries {
            let item = NSMenuItem(title: library.name, action: #selector(switchLibrary(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = library.id
            item.state = library.id == libraryManager.currentLibrary?.id ? .on : .off
            menu.addItem(item)
        }
        popUp(menu, above: libraryButton)
    }

    @objc private func switchLibrary(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        libraryManager.switchLibrary(id: id)
        synchronizeLibrary()
    }

    @objc private func showModes() {
        let menu = NSMenu()
        for mode in PlayMode.allCases {
            let item = NSMenuItem(title: mode.localizedString, action: #selector(setMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode
            item.state = mode == playerManager.playMode ? .on : .off
            menu.addItem(item)
        }
        popUp(menu, above: modeButton)
    }

    @objc private func setMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? PlayMode else { return }
        playerManager.playMode = mode
        updateControls()
    }

    @objc private func showMore() {
        let menu = NSMenu()
        for (title, symbol, action) in [
            ("Download Music", "square.and.arrow.down", #selector(showDownloads)),
            ("Settings", "gearshape", #selector(showSettings))
        ] {
            let item = NSMenuItem(title: NSLocalizedString(title, comment: ""), action: action, keyEquivalent: "")
            item.target = self
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            menu.addItem(item)
        }
        let menuTop = moreButton.isFlipped ? -menu.size.height - 6 : moreButton.bounds.maxY + menu.size.height + 6
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: menuTop), in: moreButton)
    }

    @objc private func showDownloads() {
        close()
        actionTarget?.showDownloadWindow()
    }

    @objc private func showSettings() { actionTarget?.showConfigWindow() }
    @objc private func feelingLucky() { playerManager.feelingLucky() }
    @objc private func playPrevious() { playerManager.playPrevious() }
    @objc private func playNext() { playerManager.playNext() }

    @objc private func togglePlayback() {
        if playerManager.isPlaying { playerManager.pause() } else { playerManager.play() }
    }

    @objc private func playSelectedTrack() {
        guard let id = selectedTrackID,
              let index = playerManager.playlist.firstIndex(where: { $0.id == id }) else { return }
        playerManager.playTrack(at: index)
        close()
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76: playSelectedTrack()
        case 53: close()
        case 49:
            guard let id = selectedTrackID else { return }
            if playerManager.currentTrack?.id == id { togglePlayback() } else { playSelectedTrack() }
        default:
            if !event.modifierFlags.contains(.command), !event.modifierFlags.contains(.control),
               let characters = event.characters, characters.rangeOfCharacter(from: .alphanumerics) != nil {
                makeFirstResponder(searchField)
                searchField.currentEditor()?.keyDown(with: event)
            } else {
                super.keyDown(with: event)
            }
        }
    }
}

extension SimpleSongPickerWindow: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int { filteredTracks.count }
}

extension SimpleSongPickerWindow: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { PickerRowView() }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard filteredTracks.indices.contains(row) else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("TrackCell")
        let cell = (tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView) ?? NSTableCellView()
        if cell.textField == nil {
            cell.identifier = identifier
            let text = NSTextField(labelWithString: "")
            text.font = .systemFont(ofSize: 13)
            text.textColor = .labelColor
            text.lineBreakMode = .byTruncatingTail
            text.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(text)
            cell.textField = text
            NSLayoutConstraint.activate([
                text.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 12),
                text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -12),
                text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }
        let track = filteredTracks[row]
        let current = track.id == playerManager.currentTrack?.id
        cell.textField?.stringValue = track.url.deletingPathExtension().lastPathComponent
        cell.textField?.textColor = current ? .controlAccentColor : .labelColor
        cell.textField?.font = .systemFont(ofSize: 13, weight: current ? .semibold : .regular)
        let state = current ? ", " + NSLocalizedString(playerManager.isPlaying ? "Play" : "Pause", comment: "") : ""
        cell.setAccessibilityLabel((cell.textField?.stringValue ?? "") + state)
        return cell
    }

    func tableView(_ tableView: NSTableView, shouldTypeSelectFor event: NSEvent, withCurrentSearch searchString: String?) -> Bool { false }
}

extension SimpleSongPickerWindow: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) { filterTracks(preservingSelection: false) }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)): playSelectedTrack()
        case #selector(NSResponder.cancelOperation(_:)): close()
        case #selector(NSResponder.moveUp(_:)): selectRow(max(0, tableView.selectedRow - 1))
        case #selector(NSResponder.moveDown(_:)): selectRow(tableView.selectedRow + 1)
        default: return false
        }
        return true
    }
}
