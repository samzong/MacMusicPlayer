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
    var menu: NSMenu!
    
    // Strong reference to the window
    private var downloadWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        playerManager = PlayerManager()
        sleepManager = SleepManager()
        launchManager = LaunchManager()
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.target = self
            button.action = #selector(toggleMenu)
            button.imagePosition = .imageLeft
            updateStatusBarIcon()
        }
        
        setupMenu()
        setupRemoteCommandCenter()
    }
    
    func setupMenu() {
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
        
        menu.addItem(trackInfoItem)
        menu.addItem(NSMenuItem.separator())
        
        let playPauseItem = NSMenuItem(title: NSLocalizedString("Play", comment: ""), action: #selector(togglePlayPause), keyEquivalent: "")
        menu.addItem(playPauseItem)
        
        menu.addItem(NSMenuItem(title: NSLocalizedString("Previous", comment: ""), action: #selector(playPrevious), keyEquivalent: ""))        
        menu.addItem(NSMenuItem(title: NSLocalizedString("Next", comment: ""), action: #selector(playNext), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        // Playback mode submenu
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
        
        // Equalizer
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
        
        // Reset Equalizer
        equalizerMenu.addItem(NSMenuItem.separator())
        equalizerMenu.addItem(NSMenuItem(title: NSLocalizedString("Reset Equalizer", comment: ""), action: #selector(resetEqualizer), keyEquivalent: ""))
        
        equalizerItem.submenu = equalizerMenu
        menu.addItem(equalizerItem)
        
        menu.addItem(NSMenuItem(title: NSLocalizedString("Set Music Source", comment: ""), action: #selector(reconfigureFolder), keyEquivalent: "s"))        
        menu.addItem(NSMenuItem(title: NSLocalizedString("Download Music", comment: ""), action: #selector(showDownloadWindow), keyEquivalent: "d"))
        
        let preventSleepItem = NSMenuItem(title: NSLocalizedString("Prevent Mac Sleep", comment: ""), action: #selector(togglePreventSleep), keyEquivalent: "")
        preventSleepItem.state = sleepManager.preventSleep ? .on : .off
        menu.addItem(preventSleepItem)
        
        // Launch at login toggle
        let launchAtLoginItem = NSMenuItem(title: NSLocalizedString("Launch at Login", comment: ""), action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.state = launchManager.launchAtLogin ? .on : .off
        menu.addItem(launchAtLoginItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let versionString = getVersionString()
        let versionItem = NSMenuItem(title: versionString, action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        
        menu.addItem(NSMenuItem(title: NSLocalizedString("Quit", comment: ""), action: #selector(quit), keyEquivalent: ""))
        
        // Set up observers for player state changes
        NotificationCenter.default.addObserver(self, selector: #selector(updateMenuItems), name: NSNotification.Name("TrackChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateMenuItems), name: NSNotification.Name("PlaybackStateChanged"), object: nil)
    }
    
    // Create slider view
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
        playerManager.requestMusicFolderAccess()
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(self)
    }
    @objc func togglePreventSleep() {
        sleepManager.preventSleep.toggle()
        if let preventSleepItem = menu.item(withTitle: NSLocalizedString("Prevent Mac Sleep", comment: "")) {
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
        if let playModeItem = menu.item(withTitle: NSLocalizedString("Playback Mode", comment: "")),
           let playModeMenu = playModeItem.submenu {
            for item in playModeMenu.items {
                item.state = item.tag == playerManager.playMode.tag ? .on : .off
            }
        }
    }
    
    @objc func toggleLaunchAtLogin() {
        launchManager.launchAtLogin.toggle()
        if let launchAtLoginItem = menu.item(withTitle: NSLocalizedString("Launch at Login", comment: "")) {
            launchAtLoginItem.state = launchManager.launchAtLogin ? .on : .off
        }
    }
    
    @objc func toggleEqualizer() {
        playerManager.equalizerEnabled.toggle()
        if let equalizerItem = menu.item(withTitle: NSLocalizedString("Equalizer", comment: ""))?.submenu?.item(withTitle: NSLocalizedString("Enable Equalizer", comment: "")) {
            equalizerItem.state = playerManager.equalizerEnabled ? .on : .off
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
            if let equalizerMenu = menu.item(withTitle: NSLocalizedString("Equalizer", comment: ""))?.submenu,
               let presetsItem = equalizerMenu.item(withTitle: NSLocalizedString("Presets", comment: "")),
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
        if let equalizerMenu = menu.item(withTitle: NSLocalizedString("Equalizer", comment: ""))?.submenu {
            if let bassItem = equalizerMenu.item(withTitle: NSLocalizedString("Bass", comment: "")),
               let bassSlider = bassItem.view?.subviews.last as? NSSlider {
                bassSlider.doubleValue = Double(playerManager.bassGain)
            }
            
            if let midItem = equalizerMenu.item(withTitle: NSLocalizedString("Mid", comment: "")),
               let midSlider = midItem.view?.subviews.last as? NSSlider {
                midSlider.doubleValue = Double(playerManager.midGain)
            }
            
            if let trebleItem = equalizerMenu.item(withTitle: NSLocalizedString("Treble", comment: "")),
               let trebleSlider = trebleItem.view?.subviews.last as? NSSlider {
                trebleSlider.doubleValue = Double(playerManager.trebleGain)
            }
        }
    }
    
    @objc func resetEqualizer() {
        playerManager.currentPreset = .flat
        
        if let equalizerMenu = menu.item(withTitle: NSLocalizedString("Equalizer", comment: ""))?.submenu,
           let presetsItem = equalizerMenu.item(withTitle: NSLocalizedString("Presets", comment: "")),
           let presetsMenu = presetsItem.submenu {
            for item in presetsMenu.items {
                if let itemPresetString = item.representedObject as? String {
                    item.state = (itemPresetString == PlayerManager.EqualizerPreset.flat.rawValue) ? .on : .off
                }
            }
        }
        
        updateEqualizerSliders()
    }
    
    // Method to ensure the application stays active
    func applicationWillTerminate(_ aNotification: Notification) {
        sleepManager.preventSleep = false
    }
    
    private func getVersionString() -> String {
        #if DEBUG
            // Display Git info in Debug mode
            let gitCommit = Bundle.main.object(forInfoDictionaryKey: "GitCommit") as? String ?? "unknown"
            return String(format: NSLocalizedString("Dev: %@", comment: ""), gitCommit)
        #else
            // Display official version number in Release mode
            let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
            return String(format: NSLocalizedString("Version %@", comment: ""), appVersion)
        #endif
    }
    
    @objc func showDownloadWindow() {
        // If window already exists, just activate it
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
        
        // Set callback for window close
        window.isReleasedWhenClosed = false
        window.delegate = self
        
        // Save reference to window
        self.downloadWindow = window
        
        // Show window and ensure it becomes the focus window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - NSWindowDelegate
extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == downloadWindow {
            // Release window reference
            downloadWindow = nil
        }
    }
}
