//
//  SimpleSongPickerWindow.swift
//  MacMusicPlayer
//
//  Created by X on 2024/09/24.
//

import Cocoa

class SimpleSongPickerWindow: NSPanel {
    private weak var playerManager: PlayerManager?
    private var searchField: NSSearchField!
    private var tableView: NSTableView!
    private var statusLabel: NSTextField!
    private var backgroundView: NSVisualEffectView!

    private var allTracks: [Track] = []
    private var filteredTracks: [Track] = []
    private var filterWorkItem: DispatchWorkItem?

    private let windowWidth: CGFloat = 600
    private let windowHeight: CGFloat = 400
    private let rowHeight: CGFloat = 24

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
        
        // Listen for music library refresh notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRefreshMusicLibrary),
            name: NSNotification.Name("RefreshMusicLibrary"),
            object: nil
        )
    }

    override var canBecomeKey: Bool { true }

    deinit {
        filterWorkItem?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleRefreshMusicLibrary() {
        // Reload tracks when music library is refreshed
        loadTracks()
    }

    private func setupWindow() {
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        isReleasedWhenClosed = false
        hasShadow = true
        center()
    }

    private func setupViews() {
        guard let contentView = contentView else { return }

        // Background view with rounded corners and visual effect for dark mode support
        backgroundView = NSVisualEffectView()
        backgroundView.material = .sidebar
        backgroundView.blendingMode = .behindWindow
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 20
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(backgroundView)

        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: contentView.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        // Search field
        searchField = NSSearchField()
        searchField.placeholderString = NSLocalizedString(
            "search_songs_placeholder",
            comment: "Placeholder text for the song search field"
        )
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(searchField)

        // Table view in scroll view
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        backgroundView.addSubview(scrollView)

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

        // Status label
        statusLabel = NSTextField(labelWithString: "Press Enter to play, Esc to Close")
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(statusLabel)

        // Layout
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: backgroundView.topAnchor, constant: 20),
            searchField.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 20),
            searchField.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -10),

            statusLabel.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -20),
            statusLabel.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor, constant: -10)
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
        // Cancel any pending filter operation
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

            // Update UI on main thread
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

        // Debounce: wait 150ms before filtering to avoid filtering on every keystroke
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
        case 36, 76: // Return or Enter
            playSelectedTrack()

        case 53: // Escape
            close()

        case 49: // Space
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
                    // Play the selected track without closing the window
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

// MARK: - NSTableViewDataSource
extension SimpleSongPickerWindow: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredTracks.count
    }
}

// MARK: - NSTableViewDelegate
extension SimpleSongPickerWindow: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("TrackCell")

        var cellView = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
        if cellView == nil {
            cellView = NSTableCellView()
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
                textField.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor)
            ])
        }

        if row < filteredTracks.count {
            let track = filteredTracks[row]
            let filename = track.url.deletingPathExtension().lastPathComponent
            let isCurrentTrack = track.id == playerManager?.currentTrack?.id

            cellView?.textField?.stringValue = filename
            cellView?.textField?.font = NSFont.systemFont(ofSize: 13, weight: isCurrentTrack ? .semibold : .regular)
            cellView?.textField?.textColor = isCurrentTrack ? .controlAccentColor : .labelColor
        }

        return cellView
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return rowHeight
    }

    func tableView(_ tableView: NSTableView,
                   shouldTypeSelectFor event: NSEvent,
                   withCurrentSearch searchString: String?) -> Bool {
        // Disable AppKit type-select to avoid scanning the full playlist and keep text input in the search field.
        return false
    }

}

// MARK: - NSSearchFieldDelegate
extension SimpleSongPickerWindow: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        filterTracks()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            close()
            return true
        }
        return false
    }
}
