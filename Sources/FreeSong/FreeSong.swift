import SwiftUI
import FreeSongApp

@main
struct FreeSong: App {
    init() {
        // Parse command-line args from `simctl launch <device> <bundle> -key value`
        // and store in UserDefaults for ContentView to read.
        // This is the most reliable mechanism for screenshot automation.
        let args = CommandLine.arguments
        for i in stride(from: 1, to: args.count - 1, by: 2) {
            switch args[i] {
            case "-FREESONG_VIEW":
                UserDefaults.standard.set(args[i + 1], forKey: "FREESONG_VIEW")
            case "-FREESONG_SONG_TITLE":
                UserDefaults.standard.set(args[i + 1], forKey: "FREESONG_SONG_TITLE")
            default:
                break
            }
        }
    }

    @AppStorage("darkMode") private var darkMode = false

    var body: some Scene {
        WindowGroup {
            AppRoot.rootView()
                .preferredColorScheme(darkMode ? .dark : nil)
        }
    }
}
