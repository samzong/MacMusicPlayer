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
            UserDefaults.standard.synchronize()
        }
    }
    
    private var displayAssertionID: IOPMAssertionID = 0
    private var systemAssertionID: IOPMAssertionID = 0
    
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
    
    func cleanupResourcesOnly() {
        releaseAssertion()
    }
    
    private func createAssertion() {
        if displayAssertionID != 0 || systemAssertionID != 0 {
            releaseAssertion()
        }
        
        let displayResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "MacMusicPlayer is preventing display sleep" as CFString,
            &displayAssertionID
        )
        
        if displayResult != kIOReturnSuccess {
            print("Failed to create display sleep assertion: \(displayResult)")
            displayAssertionID = 0
        }
        
        let systemResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "MacMusicPlayer is preventing system sleep" as CFString,
            &systemAssertionID
        )
        
        if systemResult != kIOReturnSuccess {
            print("Failed to create system sleep assertion: \(systemResult)")
            systemAssertionID = 0
        }
    }
    
    private func releaseAssertion() {
        if displayAssertionID != 0 {
            IOPMAssertionRelease(displayAssertionID)
            displayAssertionID = 0
        }
        
        if systemAssertionID != 0 {
            IOPMAssertionRelease(systemAssertionID)
            systemAssertionID = 0
        }
    }
}
