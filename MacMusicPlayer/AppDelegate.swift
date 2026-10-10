import Cocoa
import MediaPlayer


@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var playerManager: PlayerManager!
    var sleepManager: SleepManager!
    var launchManager: LaunchManager!
    var libraryManager: LibraryManager!
    var statusMenuController: StatusMenuController!

    private var downloadWindow: NSWindow?
    private var configWindow: NSWindow?
    private var returnToPickerAfterConfig = false
    private var songPickerWindow: SimpleSongPickerWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        libraryManager = LibraryManager()
        playerManager = PlayerManager(libraryManager: libraryManager)
        sleepManager = SleepManager()
        launchManager = LaunchManager()

        if let currentLibrary = libraryManager.currentLibrary {
            playerManager.loadLibrary(currentLibrary)
        } else {
            playerManager.requestMusicFolderAccess()
        }

        statusMenuController = StatusMenuController(
            playerManager: playerManager,
            sleepManager: sleepManager,
            launchManager: launchManager,
            libraryManager: libraryManager
        )

        statusMenuController.configureMenu(target: self)
        configureMainMenu()
        updateStatusItemVisibility()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateStatusItemVisibility),
            name: NSNotification.Name("ConfigUpdated"),
            object: nil
        )
        setupRemoteCommandCenter()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAddNewLibrary(_:)),
            name: NSNotification.Name("AddNewLibrary"),
            object: nil
        )

        DispatchQueue.main.async { [weak self] in
            self?.showSongPickerWindow()
        }
    }

    func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.playerManager.play()
            }
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.playerManager.pause()
            }
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.togglePlayPause()
            }
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.playerManager.playNext()
            }
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.playerManager.playPrevious()
            }
            return .success
        }
    }

    @objc func togglePlayPause() {
        if playerManager.isPlaying {
            playerManager.pause()
        } else {
            playerManager.play()
        }
    }

    @objc func playPrevious() {
        playerManager.playPrevious()
    }

    @objc func playNext() {
        playerManager.playNext()
    }

    @objc func feelingLucky() {
        playerManager.feelingLucky()
    }

    @objc func quit() {
        NSApplication.shared.terminate(self)
    }
    @objc func togglePreventSleep() {
        sleepManager.preventSleep.toggle()
        statusMenuController.refresh()
    }

    @objc func setPlayMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? PlayMode else { return }
        playerManager.playMode = mode
        statusMenuController.refresh()
    }

    @objc func toggleLaunchAtLogin() {
        launchManager.launchAtLogin.toggle()
        statusMenuController.refresh()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSongPickerWindow()
        return false
    }

    var isDownloading: Bool {
        (downloadWindow?.contentViewController as? DownloadViewController)?.isDownloading ?? false
    }

    @objc func showDownloadWindow() {
        if let existingWindow = self.downloadWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let downloadVC = DownloadViewController(libraryManager: libraryManager, actionTarget: self)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 218),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = downloadVC
        window.title = NSLocalizedString("Download Music", comment: "")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .clear
        window.level = .floating
        window.center()

        window.isReleasedWhenClosed = false
        window.delegate = self

        self.downloadWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func handleAddNewLibrary(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let name = userInfo["name"] as? String,
              let path = userInfo["path"] as? String else {
            return
        }

        libraryManager.addLibrary(name: name, path: path)

        statusMenuController.refresh()
    }

    @objc func switchLibrary(_ sender: NSMenuItem) {
        guard let libraryId = sender.representedObject as? UUID else { return }

        libraryManager.switchLibrary(id: libraryId)

        statusMenuController.refresh()
    }

    @objc func addNewLibrary() {
        playerManager.requestMusicFolderAccess()
    }

    @objc func removeCurrentLibrary() {
        guard libraryManager.libraries.count > 1,
              let currentId = libraryManager.currentLibrary?.id else {
            return
        }

        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Confirm Deletion", comment: "Alert title when deleting a music library")
        alert.informativeText = NSLocalizedString("This operation will not delete music files on disk, it only removes this library from the app.", comment: "Alert description when deleting a music library")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("Delete", comment: "Button title for confirming deletion"))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Button title for cancelling deletion"))

        if alert.runModal() == .alertFirstButtonReturn {
            libraryManager.removeLibrary(id: currentId)

            statusMenuController.refresh()
        }
    }

    @objc func refreshCurrentLibrary() {
        guard libraryManager.currentLibrary != nil else { return }

        playerManager.refreshMusicLibrary()
        statusMenuController.showTemporaryRefreshingIcon()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.statusMenuController.updateStatusBarIcon()
        }
    }

    @objc func renameCurrentLibrary() {
        guard let currentLibrary = libraryManager.currentLibrary else { return }

        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Rename Library", comment: "Alert title when renaming a music library")
        alert.informativeText = NSLocalizedString("Please enter a new name for the library:", comment: "Alert description when renaming a music library")
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("OK", comment: "Button title for confirming rename"))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Button title for cancelling rename"))

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        textField.stringValue = currentLibrary.name
        alert.accessoryView = textField

        if alert.runModal() == .alertFirstButtonReturn {
            let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newName.isEmpty {
                libraryManager.renameLibrary(id: currentLibrary.id, newName: newName)

                statusMenuController.refresh()
            }
        }
    }

    @objc func showConfigWindow() {
        returnToPickerAfterConfig = returnToPickerAfterConfig || songPickerWindow?.isVisible == true
        songPickerWindow?.orderOut(nil)
        if let existingWindow = self.configWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let configVC = ConfigViewController()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 280),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = configVC
        window.title = NSLocalizedString("Settings", comment: "")
        window.center()

        window.isReleasedWhenClosed = false
        window.delegate = self

        self.configWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showSongPickerWindow() {
        if let configWindow, configWindow.isVisible {
            returnToPickerAfterConfig = true
            configWindow.performClose(nil)
            return
        }
        if let existingWindow = self.songPickerWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let songPickerWindow = SimpleSongPickerWindow(playerManager: playerManager, libraryManager: libraryManager, actionTarget: self)
        songPickerWindow.delegate = self

        self.songPickerWindow = songPickerWindow

        songPickerWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem(title: "MacMusicPlayer", action: nil, keyEquivalent: "")
        let appMenu = NSMenu()
        let settingsItem = NSMenuItem(
            title: NSLocalizedString("Settings", comment: ""),
            action: #selector(showConfigWindow),
            keyEquivalent: ""
        )
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        let hideItem = appMenu.addItem(withTitle: NSLocalizedString("Hide MacMusicPlayer", comment: ""), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        hideItem.target = NSApp
        let quitItem = NSMenuItem(title: NSLocalizedString("Quit", comment: ""), action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        appMenu.addItem(quitItem)
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)
        let editItem = NSMenuItem(title: NSLocalizedString("Edit", comment: ""), action: nil, keyEquivalent: "")
        let editMenu = NSMenu()
        editMenu.addItem(withTitle: NSLocalizedString("Undo", comment: ""), action: Selector(("undo:")), keyEquivalent: "z")
        let redoItem = editMenu.addItem(withTitle: NSLocalizedString("Redo", comment: ""), action: Selector(("redo:")), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        for (title, action, key) in [
            ("Cut", #selector(NSText.cut(_:)), "x"),
            ("Copy", #selector(NSText.copy(_:)), "c"),
            ("Paste", #selector(NSText.paste(_:)), "v"),
            ("Select All", #selector(NSText.selectAll(_:)), "a")
        ] {
            editMenu.addItem(withTitle: NSLocalizedString(title, comment: ""), action: action, keyEquivalent: key)
        }
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)
        let windowItem = NSMenuItem(title: NSLocalizedString("Window", comment: ""), action: nil, keyEquivalent: "")
        let windowMenu = NSMenu(title: NSLocalizedString("Window", comment: ""))
        windowMenu.addItem(withTitle: NSLocalizedString("Close", comment: ""), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: NSLocalizedString("Minimize", comment: ""), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        let bringToFront = windowMenu.addItem(
            withTitle: NSLocalizedString("Bring All to Front", comment: ""),
            action: #selector(NSApplication.arrangeInFront(_:)),
            keyEquivalent: ""
        )
        bringToFront.target = NSApp
        windowItem.submenu = windowMenu
        mainMenu.addItem(windowItem)
        NSApp.windowsMenu = windowMenu
        NSApp.mainMenu = mainMenu
    }

    @objc private func updateStatusItemVisibility() {
        NSApp.setActivationPolicy(.accessory)
        if ConfigManager.shared.showMenubarIcon {
            if statusItem == nil {
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
                statusItem = item
                statusMenuController.configureStatusItem(item)
            }
        } else {
            if let statusItem {
                statusItem.menu = nil
                NSStatusBar.system.removeStatusItem(statusItem)
                self.statusItem = nil
            }
        }
    }


}

extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender == downloadWindow {
            sender.orderOut(nil)
            return false
        }
        return true
    }

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            if window == configWindow {
                configWindow = nil
                if returnToPickerAfterConfig {
                    returnToPickerAfterConfig = false
                    DispatchQueue.main.async { [weak self] in
                        self?.showSongPickerWindow()
                    }
                }
            } else if window == songPickerWindow {
                songPickerWindow = nil
            }
        }
    }
}
