import SwiftUI
import FreeSongCore
import FreeSongStorage
import FreeSongImport
import FreeSongSync

/// Public entry point for the FreeSong SwiftUI application.
///
/// To use from an app target:
/// ```swift
/// @main
/// struct FreeSongApp: App {
///     var body: some Scene {
///         WindowGroup {
///             AppRootView()
///         }
///     }
/// }
/// ```
public enum AppRoot {
    /// The root view of the application, ready to present.
    public static func rootView() -> some View {
        ContentView()
    }
}
