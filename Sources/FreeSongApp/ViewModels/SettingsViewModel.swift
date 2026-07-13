import SwiftUI
import FreeSongCore
import FreeSongSync

@MainActor
final class SettingsViewModel: ObservableObject {
    // Published settings
    @Published var owner: String = ""
    @Published var repo: String = ""
    @Published var branch: String = "main"
    @Published var token: String = ""
    @Published var tokenSaved = false

    // Connection state
    @Published var isTesting = false
    @Published var connectionMessage: String?

    // Sync state
    @Published var isSyncing = false
    @Published var syncProgressMessage = ""
    @Published var syncResult: SyncResult?
    @Published var syncError: String?

    // Conflict resolution
    @Published var showConflictAlert = false
    @Published var pendingConflict: SyncConflict?

    private let defaults = UserDefaults.standard

    init() {
        loadSettings()
    }

    func loadSettings() {
        owner = defaults.string(forKey: "codeberg_owner") ?? ""
        repo = defaults.string(forKey: "codeberg_repo") ?? ""
        branch = defaults.string(forKey: "codeberg_branch") ?? "main"
        tokenSaved = FreeSongSync.hasToken
    }

    func saveSettings() {
        defaults.set(owner, forKey: "codeberg_owner")
        defaults.set(repo, forKey: "codeberg_repo")
        defaults.set(branch, forKey: "codeberg_branch")
    }

    func saveToken() {
        guard !token.isEmpty else { return }
        do {
            try FreeSongSync.storeToken(token)
            tokenSaved = true
            token = ""
        } catch {
            connectionMessage = "Failed to save token: \(error.localizedDescription)"
        }
    }

    func deleteToken() {
        try? FreeSongSync.deleteToken()
        tokenSaved = false
        connectionMessage = "Token removed."
    }

    func testConnection() async {
        guard !owner.isEmpty, !repo.isEmpty else {
            connectionMessage = "Enter owner and repository name first."
            return
        }
        saveSettings()

        isTesting = true
        connectionMessage = nil
        let sync = FreeSongSync(owner: owner, repo: repo, branch: branch)

        do {
            let valid = try await sync.validateAccess()
            connectionMessage = valid ? "Connected successfully!" : "Connection failed. Check your token and repository."
        } catch {
            connectionMessage = error.localizedDescription
        }
        isTesting = false
    }

    func pushSongs() async {
        guard !owner.isEmpty, !repo.isEmpty else {
            syncError = "Configure owner and repo in Settings."
            return
        }
        saveSettings()

        isSyncing = true
        syncError = nil
        syncResult = nil
        let sync = FreeSongSync(owner: owner, repo: repo, branch: branch)

        do {
            let result = try await sync.pushSongs { progress in
                Task { @MainActor in
                    self.syncProgressMessage = self.syncProgressText(progress)
                }
            }
            syncResult = result
            if !result.errors.isEmpty {
                syncError = result.errors.joined(separator: "\n")
            }
        } catch {
            syncError = error.localizedDescription
        }
        isSyncing = false
    }

    func pullSongs() async {
        guard !owner.isEmpty, !repo.isEmpty else {
            syncError = "Configure owner and repo in Settings."
            return
        }
        saveSettings()

        isSyncing = true
        syncError = nil
        syncResult = nil
        let sync = FreeSongSync(owner: owner, repo: repo, branch: branch)

        do {
            let result = try await sync.pullSongs { progress in
                Task { @MainActor in
                    self.syncProgressMessage = self.syncProgressText(progress)
                }
            }
            syncResult = result
            if !result.errors.isEmpty {
                syncError = result.errors.joined(separator: "\n")
            }
        } catch {
            syncError = error.localizedDescription
        }
        isSyncing = false
    }

    private func syncProgressText(_ progress: SyncProgress) -> String {
        switch progress {
        case .authenticating:
            return "Authenticating…"
        case .fetchingRemoteSongs:
            return "Fetching remote songs…"
        case .comparingSongs(let current, let total):
            return "Comparing \(current)/\(total)…"
        case .uploadingSong(let title, _, _):
            return "Uploading \(title)…"
        case .downloadingSong(let title, _, _):
            return "Downloading \(title)…"
        case .resolvingConflicts:
            return "Resolving conflicts…"
        case .completed(let result):
            let parts = [
                result.uploaded.isEmpty ? nil : "\(result.uploaded.count) uploaded",
                result.downloaded.isEmpty ? nil : "\(result.downloaded.count) downloaded",
                result.conflicts.isEmpty ? nil : "\(result.conflicts.count) conflicts",
            ].compactMap { $0 }
            return "Done: \(parts.joined(separator: ", "))"
        }
    }
}
