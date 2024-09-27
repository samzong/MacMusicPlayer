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
    var menu: NSMenu!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        playerManager = PlayerManager()
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.title = "🤡"
            button.target = self
        }
        
        setupMenu()
        setupRemoteCommandCenter()
    }
    
    func setupMenu() {
        menu = NSMenu()
        menu.minimumWidth = 200 // 设置固定宽
        menu.allowsContextMenuPlugIns = true
        
        // Current track info
        let trackInfoItem = NSMenuItem(title: "No selected", action: nil, keyEquivalent: "")
        trackInfoItem.isEnabled = false
        trackInfoItem.view = NSView(frame: NSRect(x: 0, y: 0, width: 180, height: 20)) // 设置固定宽度的视图
        let trackLabel = NSTextField(frame: NSRect(x: 10, y: 0, width: 160, height: 20))
        trackLabel.isEditable = false
        trackLabel.isBordered = false
        trackLabel.backgroundColor = .clear
        trackLabel.lineBreakMode = .byTruncatingTail // 文本过长时显示省略号
        trackInfoItem.view?.addSubview(trackLabel)
        
        menu.addItem(trackInfoItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Play/Pause
        let playPauseItem = NSMenuItem(title: "Play", action: #selector(togglePlayPause), keyEquivalent: "")
        menu.addItem(playPauseItem)
        
        // Previous
        menu.addItem(NSMenuItem(title: "Previous", action: #selector(playPrevious), keyEquivalent: ""))
        
        // Next
        menu.addItem(NSMenuItem(title: "Next", action: #selector(playNext), keyEquivalent: ""))
        
        menu.addItem(NSMenuItem.separator())
        
        // Reconfigure folder
        menu.addItem(NSMenuItem(title: "Sources", action: #selector(reconfigureFolder), keyEquivalent: "s"))
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        menu.addItem(NSMenuItem(title: "Exit", action: #selector(quit), keyEquivalent: ""))
        
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
            trackLabel.stringValue = playerManager.currentTrack?.title ?? "No track selected"
        }
        
        if let playPauseItem = menu.item(at: 2) {
            playPauseItem.title = playerManager.isPlaying ? "Pause" : "Play"
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
}
