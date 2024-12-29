//
//  AppDelegate.swift
//  MacMusicPlayer
//
//  Created by X on 9/18/24.
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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        playerManager = PlayerManager()
        sleepManager = SleepManager()
        launchManager = LaunchManager()
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.title = "🤡"
            button.target = self
            button.action = #selector(toggleMenu)
        }
        
        setupMenu()
        setupRemoteCommandCenter()
    }
    
    func setupMenu() {
        menu = NSMenu()
        menu.minimumWidth = 200
        
        // Current track info
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
        
        // Play/Pause
        let playPauseItem = NSMenuItem(title: NSLocalizedString("Play", comment: ""), action: #selector(togglePlayPause), keyEquivalent: "")
        menu.addItem(playPauseItem)
        
        // Previous
        menu.addItem(NSMenuItem(title: NSLocalizedString("Previous", comment: ""), action: #selector(playPrevious), keyEquivalent: ""))
        
        // Next
        menu.addItem(NSMenuItem(title: NSLocalizedString("Next", comment: ""), action: #selector(playNext), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        // 播放模式子菜单
        let playModeMenu = NSMenu()
        let playModeItem = NSMenuItem(title: NSLocalizedString("Playback Mode", comment: ""), action: nil, keyEquivalent: "")
        
        let sequentialItem = NSMenuItem(title: NSLocalizedString("Sequential", comment: ""), action: #selector(setPlayMode(_:)), keyEquivalent: "")
        sequentialItem.tag = 0
        let singleLoopItem = NSMenuItem(title: NSLocalizedString("Single Loop", comment: ""), action: #selector(setPlayMode(_:)), keyEquivalent: "")
        singleLoopItem.tag = 1
        let randomItem = NSMenuItem(title: NSLocalizedString("Random", comment: ""), action: #selector(setPlayMode(_:)), keyEquivalent: "")
        randomItem.tag = 2
        
        playModeMenu.addItem(sequentialItem)
        playModeMenu.addItem(singleLoopItem)
        playModeMenu.addItem(randomItem)
        
        playModeItem.submenu = playModeMenu
        menu.addItem(playModeItem)
        
        // Reconfigure folder
        menu.addItem(NSMenuItem(title: NSLocalizedString("Set Music Source", comment: ""), action: #selector(reconfigureFolder), keyEquivalent: "s"))

        // 防止休眠开关
        let preventSleepItem = NSMenuItem(title: NSLocalizedString("Prevent Mac Sleep", comment: ""), action: #selector(togglePreventSleep), keyEquivalent: "")
        preventSleepItem.state = sleepManager.preventSleep ? .on : .off
        menu.addItem(preventSleepItem)
        
        // 开机自启动开关
        let launchAtLoginItem = NSMenuItem(title: NSLocalizedString("Launch at Login", comment: ""), action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.state = launchManager.launchAtLogin ? .on : .off
        menu.addItem(launchAtLoginItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        menu.addItem(NSMenuItem(title: NSLocalizedString("Quit", comment: ""), action: #selector(quit), keyEquivalent: ""))
        
        // Set up observers for player state changes
        NotificationCenter.default.addObserver(self, selector: #selector(updateMenuItems), name: NSNotification.Name("TrackChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateMenuItems), name: NSNotification.Name("PlaybackStateChanged"), object: nil)
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
        
        updatePlayModeMenuItems()
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
        if let preventSleepItem = menu.item(withTitle: "防止 Mac 休眠") {
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
        guard let playModeItem = menu.item(withTitle: "播放模式"),
              let playModeMenu = playModeItem.submenu else { return }
        
        for item in playModeMenu.items {
            item.state = item.tag == playerManager.playMode.tag ? .on : .off
        }
    }
    
    @objc func toggleLaunchAtLogin() {
        launchManager.launchAtLogin.toggle()
        if let launchAtLoginItem = menu.item(withTitle: "开机自动启动") {
            launchAtLoginItem.state = launchManager.launchAtLogin ? .on : .off
        }
    }
    
    // 添加这个方法来确保应用保持活跃状态
    func applicationWillTerminate(_ aNotification: Notification) {
        sleepManager.preventSleep = false
    }
}
