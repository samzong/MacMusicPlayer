import Cocoa
import Combine

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let playerManager: PlayerManager
    private let sleepManager: SleepManager
    private let launchManager: LaunchManager
    private let libraryManager: LibraryManager

    private var subscriptions = Set<AnyCancellable>()
    private let menu = NSMenu()
    private weak var mainMenu: NSMenu?
    private weak var statusItem: NSStatusItem?

    private weak var trackLabel: NSTextField?
    private weak var playPauseItem: NSMenuItem?
    private weak var libraryMenu: NSMenu?
    private weak var preventSleepItem: NSMenuItem?
    private weak var launchAtLoginItem: NSMenuItem?
    private weak var playModeMenu: NSMenu?
    private weak var feelingLuckyItem: NSMenuItem?
    private weak var actionTarget: AppDelegate?

    private let statusBarSymbolConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium, scale: .medium)

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

    func configureMenu(target: AppDelegate) {
        self.actionTarget = target
        menu.minimumWidth = 200

        addTrackInfoSection(to: menu)
        menu.addItem(NSMenuItem.separator())
        feelingLuckyItem = addActionItem(to: menu, title: NSLocalizedString("Feeling Lucky", comment: "Menu item for randomly playing a song"), action: #selector(AppDelegate.feelingLucky), key: "l")
        playPauseItem = addActionItem(to: menu, title: NSLocalizedString("Play", comment: ""), action: #selector(AppDelegate.togglePlayPause))
        addActionItem(to: menu, title: NSLocalizedString("Previous", comment: ""), action: #selector(AppDelegate.playPrevious))
        addActionItem(to: menu, title: NSLocalizedString("Next", comment: ""), action: #selector(AppDelegate.playNext))
        menu.addItem(NSMenuItem.separator())
        addActionItem(to: menu, title: NSLocalizedString("Browse Songs", comment: "Menu item for browsing and selecting songs"), action: #selector(AppDelegate.showSongPickerWindow), key: "f")

        let playModeMenu = NSMenu()
        for mode in PlayMode.allCases {
            addActionItem(to: playModeMenu, title: mode.localizedString, action: #selector(AppDelegate.setPlayMode(_:))).representedObject = mode
        }
        menu.addItem(withTitle: NSLocalizedString("Playback Mode", comment: ""), action: nil, keyEquivalent: "").submenu = playModeMenu
        self.playModeMenu = playModeMenu

        let libraryMenu = NSMenu()
        menu.addItem(withTitle: NSLocalizedString("Music Libraries", comment: "Menu item for music libraries"), action: nil, keyEquivalent: "").submenu = libraryMenu
        self.libraryMenu = libraryMenu

        addActionItem(to: menu, title: NSLocalizedString("Download Music", comment: ""), action: #selector(AppDelegate.showDownloadWindow), key: "d")
        preventSleepItem = addActionItem(to: menu, title: NSLocalizedString("Prevent Mac Sleep", comment: ""), action: #selector(AppDelegate.togglePreventSleep))
        launchAtLoginItem = addActionItem(to: menu, title: NSLocalizedString("Launch at Login", comment: ""), action: #selector(AppDelegate.toggleLaunchAtLogin))
        addActionItem(to: menu, title: NSLocalizedString("Settings", comment: ""), action: #selector(AppDelegate.showConfigWindow), key: "s")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: getVersionString(), action: nil, keyEquivalent: "").isEnabled = false
        addActionItem(to: menu, title: NSLocalizedString("Quit", comment: ""), action: #selector(AppDelegate.quit))

        menu.delegate = self
        for name in ["TrackChanged", "PlaybackStateChanged", "PlaylistUpdated", "PlayModeChanged", "LibrariesChanged"] {
            NotificationCenter.default.publisher(for: NSNotification.Name(name))
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.refresh() }
                .store(in: &subscriptions)
        }
        refresh()
    }

    func configureStatusItem(_ statusItem: NSStatusItem) {
        self.statusItem = statusItem
        statusItem.menu = menu
        updateStatusBarIcon()
    }

    func configureMainMenu(_ mainMenu: NSMenu) {
        self.mainMenu = mainMenu
        mainMenu.delegate = self
        refresh()
    }

    @objc
    func refresh() {
        updateTrackInfo()
        updatePlayPauseTitle()
        updateFeelingLuckyState()
        rebuildLibraryMenu()
        updateToggleStates()
        updateStatusBarIcon()
        updatePlayModeSelection()
        if let mainMenu {
            mainMenu.removeAllItems()
            for item in menu.items {
                if item.view != nil {
                    let trackItem = NSMenuItem(
                        title: playerManager.currentTrack?.title ?? NSLocalizedString("No Music Source", comment: ""),
                        action: nil,
                        keyEquivalent: ""
                    )
                    trackItem.isEnabled = false
                    mainMenu.addItem(trackItem)
                } else {
                    mainMenu.addItem(item.copy() as! NSMenuItem)
                }
            }
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refresh()
    }

    @discardableResult
    private func addActionItem(to menu: NSMenu, title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
        item.target = actionTarget
        return item
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

    private func updateTrackInfo() {
        trackLabel?.stringValue = playerManager.currentTrack?.title ?? NSLocalizedString("No Music Source", comment: "")
    }

    private func updatePlayPauseTitle() {
        playPauseItem?.title = playerManager.isPlaying ? NSLocalizedString("Pause", comment: "") : NSLocalizedString("Play", comment: "")
    }

    private func updateFeelingLuckyState() {
        feelingLuckyItem?.isEnabled = playerManager.hasPlaylist
    }

    private func rebuildLibraryMenu() {
        guard let libraryMenu = libraryMenu else { return }
        libraryMenu.removeAllItems()

        for library in libraryManager.libraries {
            let item = addActionItem(to: libraryMenu, title: library.name, action: #selector(AppDelegate.switchLibrary(_:)))
            item.representedObject = library.id
            item.state = libraryManager.currentLibrary?.id == library.id ? .on : .off
        }

        libraryMenu.addItem(NSMenuItem.separator())
        addActionItem(to: libraryMenu, title: NSLocalizedString("Refresh Current Library", comment: "Menu item for refreshing current music library"), action: #selector(AppDelegate.refreshCurrentLibrary), key: "r")
        addActionItem(to: libraryMenu, title: NSLocalizedString("Add New Library", comment: "Menu item for adding a new music library"), action: #selector(AppDelegate.addNewLibrary))
        if libraryManager.libraries.count > 1 {
            addActionItem(to: libraryMenu, title: NSLocalizedString("Delete Current Library", comment: "Menu item for deleting current music library"), action: #selector(AppDelegate.removeCurrentLibrary))
        }
        addActionItem(to: libraryMenu, title: NSLocalizedString("Rename Current Library", comment: "Menu item for renaming current music library"), action: #selector(AppDelegate.renameCurrentLibrary))
    }

    private func updateToggleStates() {
        preventSleepItem?.state = sleepManager.preventSleep ? .on : .off
        launchAtLoginItem?.state = launchManager.launchAtLogin ? .on : .off
    }

    func updateStatusBarIcon() {
        setStatusBarIcon(playerManager.isPlaying ? "headphones.circle.fill" : "headphones.circle", accessibilityDescription: "Music")
    }

    func showTemporaryRefreshingIcon() {
        setStatusBarIcon("arrow.clockwise", accessibilityDescription: "Refreshing")
    }

    private func setStatusBarIcon(_ symbolName: String, accessibilityDescription: String) {
        guard let button = statusItem?.button else { return }
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)?.withSymbolConfiguration(statusBarSymbolConfiguration)
        image?.isTemplate = true
        button.image = image
        button.imageScaling = .scaleProportionallyDown
    }

    private func updatePlayModeSelection() {
        for item in playModeMenu?.items ?? [] {
            item.state = item.representedObject as? PlayMode == playerManager.playMode ? .on : .off
        }
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
}
