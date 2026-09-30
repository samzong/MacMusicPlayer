import Foundation

final class SleepManager {
    private static let key = "PreventSleepEnabled"
    private var activity: NSObjectProtocol?

    var preventSleep: Bool {
        didSet {
            UserDefaults.standard.set(preventSleep, forKey: Self.key)
            apply()
        }
    }

    init() {
        preventSleep = UserDefaults.standard.object(forKey: Self.key) as? Bool ?? true
        apply()
    }

    private func apply() {
        if preventSleep, activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(options: [.idleDisplaySleepDisabled, .idleSystemSleepDisabled], reason: "MacMusicPlayer is preventing sleep")
        } else if !preventSleep, let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
    }
}
