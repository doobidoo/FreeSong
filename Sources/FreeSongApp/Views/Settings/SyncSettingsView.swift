import SwiftUI
import FreeSongCore
import FreeSongSync

struct SyncSettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        Form {
            // MARK: Repository
            Section("Codeberg Repository") {
                TextField("Owner", text: $viewModel.owner)
                    .autocorrectionDisabled()
                TextField("Repository", text: $viewModel.repo)
                    .autocorrectionDisabled()
                TextField("Branch", text: $viewModel.branch)
                    .autocorrectionDisabled()
                Button("Save Repository Settings") {
                    viewModel.saveSettings()
                }
                .disabled(viewModel.owner.isEmpty || viewModel.repo.isEmpty)
            }

            // MARK: Token
            Section("Access Token") {
                if viewModel.tokenSaved {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Token saved")
                            .foregroundStyle(.secondary)
                    }
                    Button("Remove Token", role: .destructive) {
                        viewModel.deleteToken()
                    }
                } else {
                    SecureField("Personal Access Token", text: $viewModel.token)
                    Button("Save Token") {
                        viewModel.saveToken()
                    }
                    .disabled(viewModel.token.isEmpty)
                }
            }

            // MARK: Connection
            Section {
                if let message = viewModel.connectionMessage {
                    HStack {
                        Image(systemName: message.contains("success") ? "checkmark.circle" : "xmark.circle")
                            .foregroundStyle(message.contains("success") ? .green : .red)
                        Text(message)
                            .font(.caption)
                    }
                }

                Button("Test Connection") {
                    Task { await viewModel.testConnection() }
                }
                .disabled(viewModel.isTesting || viewModel.owner.isEmpty || viewModel.repo.isEmpty)

                if viewModel.isTesting {
                    ProgressView()
                }
            } header: {
                Text("Connection")
            }

            // MARK: Sync Actions
            Section("Sync") {
                if viewModel.isSyncing {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView()
                        Text(viewModel.syncProgressMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Button("Push to Codeberg") {
                    Task { await viewModel.pushSongs() }
                }
                .disabled(viewModel.isSyncing)

                Button("Pull from Codeberg") {
                    Task { await viewModel.pullSongs() }
                }
                .disabled(viewModel.isSyncing)
            }

            // MARK: Sync Result
            if let result = viewModel.syncResult {
                Section("Result") {
                    if !result.uploaded.isEmpty {
                        Label("\(result.uploaded.count) uploaded", systemImage: "arrow.up.circle")
                    }
                    if !result.downloaded.isEmpty {
                        Label("\(result.downloaded.count) downloaded", systemImage: "arrow.down.circle")
                    }
                    if !result.conflicts.isEmpty {
                        Label("\(result.conflicts.count) conflicts", systemImage: "exclamationmark.circle")
                    }
                }
            }

            if let error = viewModel.syncError {
                Section("Error") {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Sync Settings")
    }
}

#Preview {
    NavigationStack {
        SyncSettingsView()
    }
}
