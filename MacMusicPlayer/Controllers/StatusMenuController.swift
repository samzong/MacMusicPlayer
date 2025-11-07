import Cocoa

@MainActor
final class StatusMenuController: NSObject {
    private let playerManager: PlayerManager
    private let sleepManager: SleepManager
    private let launchManager: LaunchManager
    private let libraryManager: LibraryManager

    private weak var statusItem: NSStatusItem?

    private weak var trackLabel: NSTextField?
    private weak var playPauseItem: NSMenuItem?
    private weak var libraryMenu: NSMenu?
    private weak var preventSleepItem: NSMenuItem?
    private weak var launchAtLoginItem: NSMenuItem?
    private weak var playModeMenu: NSMenu?
    private weak var actionTarget: AppDelegate?

    private let statusBarSymbolConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium, scale: .medium)
    private var observersRegistered = false

    init(playerManager: PlayerManager,
         sleepManager: SleepManager,
         launchManager: LaunchManager,
         libraryManager: LibraryManager) {
        self.playerManager = playerManager
        self.sleepManager = sleepManager
        self.launchManager = launchManager
        self.libraryManager = libraryManager
        super.init()
    }

    func configureStatusItem(_ statusItem: NSStatusItem, target: AppDelegate) {
        self.statusItem = statusItem
        self.actionTarget = target

        let menu = NSMenu()
        menu.minimumWidth = 200

        addTrackInfoSection(to: menu)
        menu.addItem(NSMenuItem.separator())
        addPlaybackSection(to: menu)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeBrowseItem())
        menu.addItem(makePlaybackModeSection())
        menu.addItem(makeLibrarySection())
        menu.addItem(makeDownloadItem())
        menu.addItem(makePreventSleepItem())
        menu.addItem(makeLaunchAtLoginItem())
        menu.addItem(makeSettingsItem())
        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeVersionItem())
        menu.addItem(makeQuitItem())

        statusItem.menu = menu
        registerNotifications()
        refresh()
    }

    @objc
    func refresh() {
        updateTrackInfo()
        updatePlayPauseTitle()
        rebuildLibraryMenu()
        updateToggleStates()
        updateStatusBarIcon()
        updatePlayModeSelection()
    }

    private func addTrackInfoSection(to menu: NSMenu) {
        let trackInfoItem = NSMenuItem(title: NSLocalizedString("No Music Source", comment: ""), action: nil, keyEquivalent: "")
        trackInfoItem.isEnabled = false
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 180, height: 20))
        let label = NSTextField(frame: NSRect(x: 10, y: 0, width: 160, height: 20))
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.lineBreakMode = .byTruncatingTail
        containerView.addSubview(label)
        trackInfoItem.view = containerView
        menu.addItem(trackInfoItem)
        trackLabel = label
    }

    private func addPlaybackSection(to menu: NSMenu) {
        let playPauseTitle = playerManager.isPlaying ? NSLocalizedString("Pause", comment: "") : NSLocalizedString("Play", comment: "")
        let playPauseItem = NSMenuItem(title: playPauseTitle, action: #selector(AppDelegate.togglePlayPause), keyEquivalent: "")
        playPauseItem.target = actionTarget
        menu.addItem(playPauseItem)
        self.playPauseItem = playPauseItem

        let previousItem = NSMenuItem(title: NSLocalizedString("Previous", comment: ""), action: #selector(AppDelegate.playPrevious), keyEquivalent: "")
        previousItem.target = actionTarget
        menu.addItem(previousItem)

        let nextItem = NSMenuItem(title: NSLocalizedString("Next", comment: ""), action: #selector(AppDelegate.playNext), keyEquivalent: "")
        nextItem.target = actionTarget
        menu.addItem(nextItem)
    }

    private func makeBrowseItem() -> NSMenuItem {
        let item = NSMenuItem(title: NSLocalizedString("Browse Songs", comment: "Menu item for browsing and selecting songs"), action: #selector(AppDelegate.showSongPickerWindow), keyEquivalent: "f")
        item.target = actionTarget
        return item
    }

    private func makePlaybackModeSection() -> NSMenuItem {
        let playModeMenu = NSMenu()
        let playModeItem = NSMenuItem(title: NSLocalizedString("Playback Mode", comment: ""), action: nil, keyEquivalent: "")

        let sequentialItem = NSMenuItem(title: PlayMode.sequential.localizedString, action: #selector(AppDelegate.setPlayMode(_:)), keyEquivalent: "")
        sequentialItem.tag = 0
        sequentialItem.target = actionTarget

        let singleLoopItem = NSMenuItem(title: PlayMode.singleLoop.localizedString, action: #selector(AppDelegate.setPlayMode(_:)), keyEquivalent: "")
        singleLoopItem.tag = 1
        singleLoopItem.target = actionTarget

        let randomItem = NSMenuItem(title: PlayMode.random.localizedString, action: #selector(AppDelegate.setPlayMode(_:)), keyEquivalent: "")
        randomItem.tag = 2
        randomItem.target = actionTarget

        playModeMenu.addItem(sequentialItem)
        playModeMenu.addItem(singleLoopItem)
        playModeMenu.addItem(randomItem)

        playModeItem.submenu = playModeMenu
        self.playModeMenu = playModeMenu

        return playModeItem
    }

    private func makeLibrarySection() -> NSMenuItem {
        let libraryMenu = NSMenu()
        let libraryMenuItem = NSMenuItem(title: NSLocalizedString("Music Libraries", comment: "Menu item for music libraries"), action: nil, keyEquivalent: "")
        libraryMenuItem.submenu = libraryMenu
        self.libraryMenu = libraryMenu
        return libraryMenuItem
    }

    private func makeDownloadItem() -> NSMenuItem {
        let item = NSMenuItem(title: NSLocalizedString("Download Music", comment: ""), action: #selector(AppDelegate.showDownloadWindow), keyEquivalent: "d")
        item.target = actionTarget
        return item
    }

    private func makePreventSleepItem() -> NSMenuItem {
        let item = NSMenuItem(title: NSLocalizedString("Prevent Mac Sleep", comment: ""), action: #selector(AppDelegate.togglePreventSleep), keyEquivalent: "")
        item.target = actionTarget
        item.state = sleepManager.preventSleep ? .on : .off
        preventSleepItem = item
        return item
    }

    private func makeLaunchAtLoginItem() -> NSMenuItem {
        let item = NSMenuItem(title: NSLocalizedString("Launch at Login", comment: ""), action: #selector(AppDelegate.toggleLaunchAtLogin), keyEquivalent: "")
        item.target = actionTarget
        item.state = launchManager.launchAtLogin ? .on : .off
        launchAtLoginItem = item
        return item
    }

    private func makeSettingsItem() -> NSMenuItem {
        let item = NSMenuItem(title: NSLocalizedString("Settings", comment: ""), action: #selector(AppDelegate.showConfigWindow), keyEquivalent: "s")
        item.target = actionTarget
        return item
    }

    private func makeVersionItem() -> NSMenuItem {
        let versionItem = NSMenuItem(title: getVersionString(), action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        return versionItem
    }

    private func makeQuitItem() -> NSMenuItem {
        let item = NSMenuItem(title: NSLocalizedString("Quit", comment: ""), action: #selector(AppDelegate.quit), keyEquivalent: "")
        item.target = actionTarget
        return item
    }

    private func updateTrackInfo() {
        trackLabel?.stringValue = playerManager.currentTrack?.title ?? NSLocalizedString("No Music Source", comment: "")
    }

    private func updatePlayPauseTitle() {
        playPauseItem?.title = playerManager.isPlaying ? NSLocalizedString("Pause", comment: "") : NSLocalizedString("Play", comment: "")
    }

    private func rebuildLibraryMenu() {
        guard let libraryMenu = libraryMenu else { return }
        libraryMenu.removeAllItems()

        for library in libraryManager.libraries {
            let item = NSMenuItem(title: library.name, action: #selector(AppDelegate.switchLibrary(_:)), keyEquivalent: "")
            item.representedObject = library.id
            item.state = libraryManager.currentLibrary?.id == library.id ? .on : .off
            item.target = actionTarget
            libraryMenu.addItem(item)
        }

        libraryMenu.addItem(NSMenuItem.separator())

        let refreshItem = NSMenuItem(title: NSLocalizedString("Refresh Current Library", comment: "Menu item for refreshing current music library"), action: #selector(AppDelegate.refreshCurrentLibrary), keyEquivalent: "r")
        refreshItem.target = actionTarget
        libraryMenu.addItem(refreshItem)

        let addItem = NSMenuItem(title: NSLocalizedString("Add New Library", comment: "Menu item for adding a new music library"), action: #selector(AppDelegate.addNewLibrary), keyEquivalent: "")
        addItem.target = actionTarget
        libraryMenu.addItem(addItem)

        if libraryManager.libraries.count > 1 {
            let deleteItem = NSMenuItem(title: NSLocalizedString("Delete Current Library", comment: "Menu item for deleting current music library"), action: #selector(AppDelegate.removeCurrentLibrary), keyEquivalent: "")
            deleteItem.target = actionTarget
            libraryMenu.addItem(deleteItem)
        }

        let renameItem = NSMenuItem(title: NSLocalizedString("Rename Current Library", comment: "Menu item for renaming current music library"), action: #selector(AppDelegate.renameCurrentLibrary), keyEquivalent: "")
        renameItem.target = actionTarget
        libraryMenu.addItem(renameItem)
    }

    private func updateToggleStates() {
        preventSleepItem?.state = sleepManager.preventSleep ? .on : .off
        launchAtLoginItem?.state = launchManager.launchAtLogin ? .on : .off
    }

    func updateStatusBarIcon() {
        guard let button = statusItem?.button else { return }
        let symbolName = playerManager.isPlaying ? "headphones.circle.fill" : "headphones.circle"
        guard let icon = makeStatusBarImage(symbolName: symbolName, accessibilityDescription: "Music") else {
            button.image = nil
            return
        }

        button.image = icon
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = nil
    }

    func showTemporaryRefreshingIcon() {
        guard let button = statusItem?.button else { return }
        guard let icon = makeStatusBarImage(symbolName: "arrow.clockwise", accessibilityDescription: "Refreshing") else {
            return
        }

        button.image = icon
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = nil
    }

    private func updatePlayModeSelection() {
        guard let playModeMenu = playModeMenu else { return }
        for item in playModeMenu.items {
            item.state = item.tag == playerManager.playMode.tag ? .on : .off
        }
    }

    private func makeStatusBarImage(symbolName: String, accessibilityDescription: String) -> NSImage? {
        guard let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)?.withSymbolConfiguration(statusBarSymbolConfiguration) else {
            return nil
        }

        image.isTemplate = true
        return image
    }

    private func registerNotifications() {
        guard !observersRegistered else { return }
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: NSNotification.Name("TrackChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: NSNotification.Name("PlaybackStateChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: NSNotification.Name("PlaylistUpdated"), object: nil)
        observersRegistered = true
    }

    private func getVersionString() -> String {
        #if DEBUG
            let gitCommit = Bundle.main.object(forInfoDictionaryKey: "GitCommit") as? String ?? "unknown"
            return String(format: NSLocalizedString("Dev: %@", comment: ""), gitCommit)
        #else
            let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
            return String(format: NSLocalizedString("Version %@", comment: ""), appVersion)
        #endif
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
