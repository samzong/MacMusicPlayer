//
//  SleepManager.swift
//  MacMusicPlayer
//
//  Created by X on 10/1/24.
//

import Foundation
import IOKit.pwr_mgt

class SleepManager: ObservableObject {
    @Published var preventSleep = false {
        didSet {
            updateSleepAssertion()
        }
    }
    
    private var assertionID: IOPMAssertionID = 0
    
    func updateSleepAssertion() {
        if preventSleep {
            createAssertion()
        } else {
            releaseAssertion()
        }
    }
    
    private func createAssertion() {
        let reason = "MacMusicPlayer is preventing display sleep"
        IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                    IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                    reason as CFString,
                                    &assertionID)
    }
    
    private func releaseAssertion() {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
    }
}
