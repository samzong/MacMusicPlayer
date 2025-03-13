//
//  SleepManager.swift
//  MacMusicPlayer
//
//  Created by X on 2024/10/01.
//

import Foundation
import IOKit.pwr_mgt

class SleepManager: ObservableObject {
    @Published var preventSleep: Bool {
        didSet {
            updateSleepAssertion()
            UserDefaults.standard.set(preventSleep, forKey: "PreventSleepEnabled")
        }
    }
    
    private var assertionID: IOPMAssertionID = 0
    
    init() {
        if UserDefaults.standard.object(forKey: "PreventSleepEnabled") != nil {
            self.preventSleep = UserDefaults.standard.bool(forKey: "PreventSleepEnabled")
        } else {
            self.preventSleep = true
            UserDefaults.standard.set(true, forKey: "PreventSleepEnabled")
        }
        
        updateSleepAssertion()
    }
    
    deinit {
        releaseAssertion()
    }
    
    private func updateSleepAssertion() {
        if preventSleep {
            createAssertion()
        } else {
            releaseAssertion()
        }
    }
    
    private func createAssertion() {
        if assertionID != 0 {
            releaseAssertion()
        }
        
        _ = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "MacMusicPlayer is preventing display sleep" as CFString,
            &assertionID
        )
    }
    
    private func releaseAssertion() {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
    }
}
