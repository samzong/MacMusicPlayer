//
//  AppDelegate.swift
//  MacMusicPlayer
//
//  Created by samzong<samzong.lu@gmail.com> on 2024/09/18.
//

import Cocoa
import MediaPlayer
import SwiftUI
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var playerManager: PlayerManager!
    var sleepManager: SleepManager!
    var launchManager: LaunchManager!
    var libraryManager: LibraryManager!
    var menu: NSMenu!
    
    // Strong reference to the window
    private var downloadWindow: NSWindow?
    private var configWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        playerManager = PlayerManager()
        sleepManager = SleepManager()
        launchManager = LaunchManager()
        libraryManager = LibraryManager()
        
        if let currentLibrary = libraryManager.currentLibrary {
            playerManager.loadLibrary(currentLibrary)
        } else {
            playerManager.requestMusicFolderAccess()
        }
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.target = self
            button.action = #selector(toggleMenu)
            button.imagePosition = .imageLeft
            updateStatusBarIcon()
        }
        
        setupMenu()
        setupRemoteCommandCenter()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAddNewLibrary(_:)),
            name: NSNotification.Name("AddNewLibrary"),
            object: nil
        )
    }
    
    func setupMenu() {
        let oldMenu = menu
        
        menu = NSMenu()
        menu.minimumWidth = 200
        
        let trackInfoItem = NSMenuItem(title: NSLocalizedString("No Music Source", comment: ""), action: nil, keyEquivalent: "")
        trackInfoItem.isEnabled = false
        trackInfoItem.view = NSView(frame: NSRect(x: 0, y: 0, width: 180, height: 20))
        let trackLabel = NSTextField(frame: NSRect(x: 10, y: 0, width: 160, height: 20))
        trackLabel.isEditable = false
        trackLabel.isBordered = false
        trackLabel.backgroundColor = .clear
        trackLabel.lineBreakMode = .byTruncatingTail
        trackInfoItem.view?.addSubview(trackLabel)
        
        if let oldMenu = oldMenu,
           let oldTrackItem = oldMenu.item(at: 0),
           let oldTrackLabel = oldTrackItem.view?.subviews.first as? NSTextField {
            trackLabel.stringValue = oldTrackLabel.stringValue
        } else if let currentTrack = playerManager.currentTrack {
            trackLabel.stringValue = currentTrack.title
        }
        
        menu.addItem(trackInfoItem)
        menu.addItem(NSMenuItem.separator())
        
        let playPauseTitle = playerManager.isPlaying ? NSLocalizedString("Pause", comment: "") : NSLocalizedString("Play", comment: "")
        let playPauseItem = NSMenuItem(title: playPauseTitle, action: #selector(togglePlayPause), keyEquivalent: "")
        menu.addItem(playPauseItem)
        
        menu.addItem(NSMenuItem(title: NSLocalizedString("Previous", comment: ""), action: #selector(playPrevious), keyEquivalent: ""))        
        menu.addItem(NSMenuItem(title: NSLocalizedString("Next", comment: ""), action: #selector(playNext), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        let playModeMenu = NSMenu()
        let playModeItem = NSMenuItem(title: NSLocalizedString("Playback Mode", comment: ""), action: nil, keyEquivalent: "")
        
        let sequentialItem = NSMenuItem(title: PlayerManager.PlayMode.sequential.localizedString, action: #selector(setPlayMode(_:)), keyEquivalent: "")
        sequentialItem.tag = 0
        let singleLoopItem = NSMenuItem(title: PlayerManager.PlayMode.singleLoop.localizedString, action: #selector(setPlayMode(_:)), keyEquivalent: "")
        singleLoopItem.tag = 1
        let randomItem = NSMenuItem(title: PlayerManager.PlayMode.random.localizedString, action: #selector(setPlayMode(_:)), keyEquivalent: "")
        randomItem.tag = 2
        
        playModeMenu.addItem(sequentialItem)
        playModeMenu.addItem(singleLoopItem)
        playModeMenu.addItem(randomItem)
        
        playModeItem.submenu = playModeMenu
        menu.addItem(playModeItem)
        
        let equalizerMenu = NSMenu()
        let equalizerItem = NSMenuItem(title: NSLocalizedString("Equalizer", comment: ""), action: nil, keyEquivalent: "")
        
        let enableEqualizerItem = NSMenuItem(title: NSLocalizedString("Enable Equalizer", comment: ""), action: #selector(toggleEqualizer), keyEquivalent: "")
        enableEqualizerItem.state = playerManager.equalizerEnabled ? .on : .off
        equalizerMenu.addItem(enableEqualizerItem)
        
        equalizerMenu.addItem(NSMenuItem.separator())
        
        let presetsMenu = NSMenu()
        let presetsItem = NSMenuItem(title: NSLocalizedString("Presets", comment: ""), action: nil, keyEquivalent: "")
        
        for preset in PlayerManager.EqualizerPreset.allCases {
            let presetItem = NSMenuItem(title: preset.localizedString, action: #selector(selectEqualizerPreset(_:)), keyEquivalent: "")
            presetItem.representedObject = preset.rawValue
            presetItem.state = playerManager.currentPreset == preset ? .on : .off
            presetsMenu.addItem(presetItem)
        }
        
        presetsItem.submenu = presetsMenu
        equalizerMenu.addItem(presetsItem)
        
        equalizerMenu.addItem(NSMenuItem.separator())
        
        let bassItem = NSMenuItem(title: NSLocalizedString("Bass", comment: ""), action: nil, keyEquivalent: "")
        bassItem.view = createSliderView(title: NSLocalizedString("Bass", comment: ""), value: playerManager.bassGain, action: #selector(bassSliderChanged(_:)))
        equalizerMenu.addItem(bassItem)
        
        let midItem = NSMenuItem(title: NSLocalizedString("Mid", comment: ""), action: nil, keyEquivalent: "")
        midItem.view = createSliderView(title: NSLocalizedString("Mid", comment: ""), value: playerManager.midGain, action: #selector(midSliderChanged(_:)))
        equalizerMenu.addItem(midItem)
        
        let trebleItem = NSMenuItem(title: NSLocalizedString("Treble", comment: ""), action: nil, keyEquivalent: "")
        trebleItem.view = createSliderView(title: NSLocalizedString("Treble", comment: ""), value: playerManager.trebleGain, action: #selector(trebleSliderChanged(_:)))
        equalizerMenu.addItem(trebleItem)
        
        equalizerMenu.addItem(NSMenuItem.separator())
        equalizerMenu.addItem(NSMenuItem(title: NSLocalizedString("Reset Equalizer", comment: ""), action: #selector(resetEqualizer), keyEquivalent: ""))
        
        equalizerItem.submenu = equalizerMenu
        menu.addItem(equalizerItem)
        
        let libraryMenu = NSMenu()
        let libraryMenuItem = NSMenuItem(title: NSLocalizedString("Music Libraries", comment: "Menu item for music libraries"), action: nil, keyEquivalent: "")
        
        for library in libraryManager.libraries {
            let item = NSMenuItem(title: library.name, action: #selector(switchLibrary(_:)), keyEquivalent: "")
            item.representedObject = library.id
            item.state = libraryManager.currentLibrary?.id == library.id ? .on : .off
            libraryMenu.addItem(item)
        }
        
        libraryMenu.addItem(NSMenuItem.separator())
        libraryMenu.addItem(NSMenuItem(title: NSLocalizedString("Refresh Current Library", comment: "Menu item for refreshing current music library"), action: #selector(refreshCurrentLibrary), keyEquivalent: "r"))
        libraryMenu.addItem(NSMenuItem(title: NSLocalizedString("Add New Library", comment: "Menu item for adding a new music library"), action: #selector(addNewLibrary), keyEquivalent: ""))
        
        if libraryManager.libraries.count > 1 {
            libraryMenu.addItem(NSMenuItem(title: NSLocalizedString("Delete Current Library", comment: "Menu item for deleting current music library"), action: #selector(removeCurrentLibrary), keyEquivalent: ""))
        }
        
        libraryMenu.addItem(NSMenuItem(title: NSLocalizedString("Rename Current Library", comment: "Menu item for renaming current music library"), action: #selector(renameCurrentLibrary), keyEquivalent: ""))
        
        libraryMenuItem.submenu = libraryMenu
        menu.addItem(libraryMenuItem)
        
        menu.addItem(NSMenuItem(title: NSLocalizedString("Download Music", comment: ""), action: #selector(showDownloadWindow), keyEquivalent: "d"))
        
        let preventSleepItem = NSMenuItem(title: NSLocalizedString("Prevent Mac Sleep", comment: ""), action: #selector(togglePreventSleep), keyEquivalent: "")
        preventSleepItem.state = sleepManager.preventSleep ? .on : .off
        menu.addItem(preventSleepItem)
        
        let launchAtLoginItem = NSMenuItem(title: NSLocalizedString("Launch at Login", comment: ""), action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.state = launchManager.launchAtLogin ? .on : .off
        menu.addItem(launchAtLoginItem)
        
        menu.addItem(NSMenuItem(title: NSLocalizedString("Settings", comment: ""), action: #selector(showConfigWindow), keyEquivalent: "s"))
        
        menu.addItem(NSMenuItem.separator())
        
        let versionString = getVersionString()
        let versionItem = NSMenuItem(title: versionString, action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        
        menu.addItem(NSMenuItem(title: NSLocalizedString("Quit", comment: ""), action: #selector(quit), keyEquivalent: ""))
        
        if oldMenu == nil {
            NotificationCenter.default.addObserver(self, selector: #selector(updateMenuItems), name: NSNotification.Name("TrackChanged"), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(updateMenuItems), name: NSNotification.Name("PlaybackStateChanged"), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(updateMenuItems), name: NSNotification.Name("RefreshMusicLibrary"), object: nil)
        }
        
        statusItem?.menu = menu
    }
    
    private func createSliderView(title: String, value: Float, action: Selector) -> NSView {
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 180, height: 40))
        
        let titleLabel = NSTextField(frame: NSRect(x: 10, y: 20, width: 160, height: 16))
        titleLabel.stringValue = title
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.backgroundColor = .clear
        titleLabel.font = NSFont.systemFont(ofSize: 12)
        
        let slider = NSSlider(frame: NSRect(x: 10, y: 0, width: 160, height: 20))
        slider.minValue = -12.0
        slider.maxValue = 12.0
        slider.doubleValue = Double(value)
        slider.target = self
        slider.action = action
        slider.isContinuous = true
        
        containerView.addSubview(titleLabel)
        containerView.addSubview(slider)
        
        return containerView
    }
    
    func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.playerManager.play()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.playerManager.pause()
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            if let isPlaying = self?.playerManager.isPlaying {
                if isPlaying {
                    self?.playerManager.pause()
                } else {
                    self?.playerManager.play()
                }
            }
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.playerManager.playNext()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.playerManager.playPrevious()
            return .success
        }
    }
    
    @objc func toggleMenu() {
        updateMenuItems()
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
    }
    
    @objc func updateMenuItems() {
        if let trackInfoItem = menu.item(at: 0),
           let trackLabel = trackInfoItem.view?.subviews.first as? NSTextField {
            trackLabel.stringValue = playerManager.currentTrack?.title ?? NSLocalizedString("No Music Source", comment: "")
        }
        
        if let playPauseItem = menu.item(at: 2) {
            playPauseItem.title = playerManager.isPlaying ? NSLocalizedString("Pause", comment: "") : NSLocalizedString("Play", comment: "")
        }
        
        for i in 0..<menu.items.count {
            let item = menu.item(at: i)
            if let itemTitle = item?.title, itemTitle == NSLocalizedString("Music Libraries", comment: "Menu item for music libraries") {
                if let submenu = item?.submenu {
                    while !submenu.items.isEmpty && submenu.items[0].action != nil && 
                          submenu.items[0].title != NSLocalizedString("Add New Library", comment: "Menu item for adding a new music library") {
                        submenu.removeItem(at: 0)
                    }
                    
                    var separatorIndex = -1
                    for j in 0..<submenu.items.count {
                        if submenu.items[j].isSeparatorItem {
                            separatorIndex = j
                            break
                        }
                    }
                    
                    for (_, library) in libraryManager.libraries.enumerated().reversed() {
                        let newItem = NSMenuItem(title: library.name, action: #selector(switchLibrary(_:)), keyEquivalent: "")
                        newItem.representedObject = library.id
                        newItem.state = libraryManager.currentLibrary?.id == library.id ? .on : .off
                        if separatorIndex >= 0 {
                            submenu.insertItem(newItem, at: 0)
                        } else {
                            submenu.addItem(newItem)
                        }
                    }
                    
                    let refreshItemIndex = submenu.items.firstIndex { $0.title == NSLocalizedString("Refresh Current Library", comment: "Menu item for refreshing current music library") }
                    if refreshItemIndex == nil && separatorIndex >= 0 {
                        let refreshItem = NSMenuItem(title: NSLocalizedString("Refresh Current Library", comment: "Menu item for refreshing current music library"), action: #selector(refreshCurrentLibrary), keyEquivalent: "")
                        submenu.insertItem(refreshItem, at: separatorIndex + 1)
                    }
                    
                    let deleteItemIndex = submenu.items.firstIndex { $0.title == NSLocalizedString("Delete Current Library", comment: "Menu item for deleting current music library") }
                    if libraryManager.libraries.count > 1 {
                        if deleteItemIndex == nil {
                            let renameItemIndex = submenu.items.firstIndex { $0.title == NSLocalizedString("Rename Current Library", comment: "Menu item for renaming current music library") }
                            if let index = renameItemIndex {
                                let deleteItem = NSMenuItem(title: NSLocalizedString("Delete Current Library", comment: "Menu item for deleting current music library"), action: #selector(removeCurrentLibrary), keyEquivalent: "")
                                submenu.insertItem(deleteItem, at: index)
                            }
                        }
                    } else if let index = deleteItemIndex {
                        submenu.removeItem(at: index)
                    }
                }
                break
            }
        }
        
        updateStatusBarIcon()
        updatePlayModeMenuItems()
    }
    
    private func updateStatusBarIcon() {
        if let button = statusItem?.button {
            let configuration = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            let symbolName = playerManager.isPlaying ? "headphones.circle.fill" : "headphones.circle"
            let icon = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Music")?.withSymbolConfiguration(configuration)
            button.image = icon
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
    
    @objc func reconfigureFolder() {
        addNewLibrary()
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(self)
    }
    @objc func togglePreventSleep() {
        sleepManager.preventSleep.toggle()
        if let preventSleepItem = menu.items.first(where: { $0.title == NSLocalizedString("Prevent Mac Sleep", comment: "") }) {
            preventSleepItem.state = sleepManager.preventSleep ? .on : .off
        }
    }
    
    @objc func setPlayMode(_ sender: NSMenuItem) {
        let mode: PlayerManager.PlayMode
        switch sender.tag {
        case 0:
            mode = .sequential
        case 1:
            mode = .singleLoop
        case 2:
            mode = .random
        default:
            return
        }
        playerManager.playMode = mode
        updatePlayModeMenuItems()
    }
    
    func updatePlayModeMenuItems() {
        if let playModeItem = menu.items.first(where: { $0.title == NSLocalizedString("Playback Mode", comment: "") }),
           let playModeMenu = playModeItem.submenu {
            for item in playModeMenu.items {
                item.state = item.tag == playerManager.playMode.tag ? .on : .off
            }
        }
    }
    
    @objc func toggleLaunchAtLogin() {
        launchManager.launchAtLogin.toggle()
        if let launchAtLoginItem = menu.items.first(where: { $0.title == NSLocalizedString("Launch at Login", comment: "") }) {
            launchAtLoginItem.state = launchManager.launchAtLogin ? .on : .off
        }
    }
    
    @objc func toggleEqualizer() {
        playerManager.equalizerEnabled.toggle()
        if let equalizerItem = menu.items.first(where: { $0.title == NSLocalizedString("Equalizer", comment: "") }),
           let submenu = equalizerItem.submenu,
           let enableItem = submenu.items.first(where: { $0.title == NSLocalizedString("Enable Equalizer", comment: "") }) {
            enableItem.state = playerManager.equalizerEnabled ? .on : .off
        }
    }
    
    @objc func bassSliderChanged(_ sender: NSSlider) {
        playerManager.bassGain = Float(sender.doubleValue)
    }
    
    @objc func midSliderChanged(_ sender: NSSlider) {
        playerManager.midGain = Float(sender.doubleValue)
    }
    
    @objc func trebleSliderChanged(_ sender: NSSlider) {
        playerManager.trebleGain = Float(sender.doubleValue)
    }
    
    @objc func selectEqualizerPreset(_ sender: NSMenuItem) {
        if let presetString = sender.representedObject as? String,
           let preset = PlayerManager.EqualizerPreset(rawValue: presetString) {
            playerManager.currentPreset = preset
            
            // Update the selected state of the preset menu item
            if let equalizerItem = menu.items.first(where: { $0.title == NSLocalizedString("Equalizer", comment: "") }),
               let equalizerMenu = equalizerItem.submenu,
               let presetsItem = equalizerMenu.items.first(where: { $0.title == NSLocalizedString("Presets", comment: "") }),
               let presetsMenu = presetsItem.submenu {
                for item in presetsMenu.items {
                    if let itemPresetString = item.representedObject as? String {
                        item.state = (itemPresetString == presetString) ? .on : .off
                    }
                }
            }
            
            updateEqualizerSliders()
        }
    }
    
    private func updateEqualizerSliders() {
        if let equalizerItem = menu.items.first(where: { $0.title == NSLocalizedString("Equalizer", comment: "") }),
           let equalizerMenu = equalizerItem.submenu {
            
            if let bassItem = equalizerMenu.items.first(where: { $0.title == NSLocalizedString("Bass", comment: "") }),
               let bassSlider = bassItem.view?.subviews.last as? NSSlider {
                bassSlider.doubleValue = Double(playerManager.bassGain)
            }
            
            if let midItem = equalizerMenu.items.first(where: { $0.title == NSLocalizedString("Mid", comment: "") }),
               let midSlider = midItem.view?.subviews.last as? NSSlider {
                midSlider.doubleValue = Double(playerManager.midGain)
            }
            
            if let trebleItem = equalizerMenu.items.first(where: { $0.title == NSLocalizedString("Treble", comment: "") }),
               let trebleSlider = trebleItem.view?.subviews.last as? NSSlider {
                trebleSlider.doubleValue = Double(playerManager.trebleGain)
            }
        }
    }
    
    @objc func resetEqualizer() {
        playerManager.currentPreset = .flat
        
        if let equalizerItem = menu.items.first(where: { $0.title == NSLocalizedString("Equalizer", comment: "") }),
           let equalizerMenu = equalizerItem.submenu,
           let presetsItem = equalizerMenu.items.first(where: { $0.title == NSLocalizedString("Presets", comment: "") }),
           let presetsMenu = presetsItem.submenu {
            for item in presetsMenu.items {
                if let itemPresetString = item.representedObject as? String {
                    item.state = (itemPresetString == PlayerManager.EqualizerPreset.flat.rawValue) ? .on : .off
                }
            }
        }
        
        updateEqualizerSliders()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        sleepManager.cleanupResourcesOnly()
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
    
    @objc func showDownloadWindow() {
        if let existingWindow = self.downloadWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let downloadVC = DownloadViewController()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = downloadVC
        window.title = NSLocalizedString("Download Music", comment: "")
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
        
        updateMenuItems()
    }
    
    @objc func switchLibrary(_ sender: NSMenuItem) {
        guard let libraryId = sender.representedObject as? UUID else { return }
        
        libraryManager.switchLibrary(id: libraryId)
        
        if let currentLibrary = libraryManager.currentLibrary {
            playerManager.loadLibrary(currentLibrary)
        }
        
        updateMenuItems()
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
            
            if let newCurrent = libraryManager.currentLibrary {
                playerManager.loadLibrary(newCurrent)
            }
            
            updateMenuItems()
        }
    }
    
    @objc func refreshCurrentLibrary() {
        guard let currentLibrary = libraryManager.currentLibrary else { return }
        
        NotificationCenter.default.post(name: NSNotification.Name("RefreshMusicLibrary"), object: nil)
        
        if let button = statusItem?.button {
            let oldImage = button.image
            button.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refreshing")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.updateStatusBarIcon()
            }
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
                
                updateMenuItems()
            }
        }
    }
    
    @objc func showConfigWindow() {
        if let existingWindow = self.configWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let configVC = ConfigViewController { [weak self] in
            NotificationCenter.default.post(name: NSNotification.Name("ConfigUpdated"), object: nil)
        }
        
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
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            if window == downloadWindow {
                downloadWindow = nil
            } else if window == configWindow {
                configWindow = nil
            }
        }
    }
}
