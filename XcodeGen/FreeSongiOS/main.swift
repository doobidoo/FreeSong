import SwiftUI
import FreeSongApp

@main
struct FreeSongApp_iOS: App {
    @AppStorage("darkMode") private var darkMode = false
    
    var body: some Scene {
        WindowGroup {
            AppRoot.rootView()
                .preferredColorScheme(darkMode ? .dark : nil)
        }
    }
}
