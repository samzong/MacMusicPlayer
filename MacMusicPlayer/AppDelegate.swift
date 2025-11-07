//
//  AppDelegate.swift
//  MacMusicPlayer
//
//  Created by samzong<samzong.lu@gmail.com> on 2024/09/18.
//

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

    // Strong reference to the window
    private var downloadWindow: NSWindow?
    private var configWindow: NSWindow?
    private var songPickerWindow: SimpleSongPickerWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        playerManager = PlayerManager()
        sleepManager = SleepManager()
        launchManager = LaunchManager()
        libraryManager = LibraryManager()
        DownloadManager.shared.updateLibraryManager(libraryManager)
        
        if let currentLibrary = libraryManager.currentLibrary {
            playerManager.loadLibrary(currentLibrary)
        } else {
            playerManager.requestMusicFolderAccess()
        }
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.target = self
            button.action = #selector(toggleMenu)
        }

        statusMenuController = StatusMenuController(
            playerManager: playerManager,
            sleepManager: sleepManager,
            launchManager: launchManager,
            libraryManager: libraryManager
        )

        if let statusItem = statusItem {
            statusMenuController.configureStatusItem(statusItem, target: self)
        }
        setupRemoteCommandCenter()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAddNewLibrary(_:)),
            name: NSNotification.Name("AddNewLibrary"),
            object: nil
        )
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
        statusMenuController.refresh()
        statusItem?.button?.performClick(nil)
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
    
    @objc func quit() {
        NSApplication.shared.terminate(self)
    }
    @objc func togglePreventSleep() {
        sleepManager.preventSleep.toggle()
        statusMenuController.refresh()
    }

    @objc func setPlayMode(_ sender: NSMenuItem) {
        let mode: PlayMode
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
        statusMenuController.refresh()
    }

    @objc func toggleLaunchAtLogin() {
        launchManager.launchAtLogin.toggle()
        statusMenuController.refresh()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        sleepManager.cleanupResourcesOnly()
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

        statusMenuController.refresh()
    }
    
    @objc func switchLibrary(_ sender: NSMenuItem) {
        guard let libraryId = sender.representedObject as? UUID else { return }
        
        libraryManager.switchLibrary(id: libraryId)
        
        if let currentLibrary = libraryManager.currentLibrary {
            playerManager.loadLibrary(currentLibrary)
        }

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
            
            if let newCurrent = libraryManager.currentLibrary {
                playerManager.loadLibrary(newCurrent)
            }

            statusMenuController.refresh()
        }
    }
    
    @objc func refreshCurrentLibrary() {
        guard let currentLibrary = libraryManager.currentLibrary else { return }

        playerManager.loadLibrary(currentLibrary)
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
        if let existingWindow = self.configWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let configVC = ConfigViewController {
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

    @objc func showSongPickerWindow() {
        if let existingWindow = self.songPickerWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let songPickerWindow = SimpleSongPickerWindow(playerManager: playerManager)
        songPickerWindow.delegate = self

        self.songPickerWindow = songPickerWindow

        songPickerWindow.makeKeyAndOrderFront(nil)
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
            } else if window == songPickerWindow {
                songPickerWindow = nil
            }
        }
    }
}
