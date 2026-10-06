import Cocoa

@main
struct MacMusicPlayerApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}
