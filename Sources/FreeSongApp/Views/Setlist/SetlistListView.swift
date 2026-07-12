import SwiftUI
import FreeSongCore
import FreeSongStorage

struct SetlistListView: View {
    @StateObject private var viewModel = SetlistEditorViewModel()
    @State private var showingNewSheet = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.setlists.isEmpty {
                ProgressView("Loading setlists…")
            } else if viewModel.setlists.isEmpty {
                EmptyStateView(
                    icon: "list.star",
                    title: "No Setlists",
                    message: "Create a setlist to organize songs for your next session."
                )
            } else {
                listContent
            }
        }
        .navigationTitle("Setlists")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingNewSheet = true }) {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    Button {
                        Task { await viewModel.exportSetlists() }
                    } label: {
                        Label("Export Backup", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        Task { await viewModel.importSetlistsFromBackup() }
                    } label: {
                        Label("Import Backup", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            await viewModel.loadSetlists()
            await viewModel.checkForAutoRestore()
        }
        .alert("New Setlist", isPresented: $showingNewSheet) {
            TextField("Name", text: $viewModel.newSetlistName)
            Button("Cancel", role: .cancel) { viewModel.newSetlistName = "" }
            Button("Create") {
                let name = viewModel.newSetlistName
                viewModel.newSetlistName = ""
                Task { await viewModel.createSetlist(name: name) }
            }
        } message: {
            Text("Enter a name for the new setlist.")
        }
        .alert("Restore Setlists?", isPresented: $viewModel.showingBackupRestorePrompt) {
            Button("Cancel", role: .cancel) {}
            Button("Restore") {
                Task { await viewModel.importSetlistsFromBackup() }
            }
        } message: {
            Text("A setlist backup was found on this device. Would you like to restore it?")
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var listContent: some View {
        List {
            ForEach(viewModel.setlists) { setlist in
                NavigationLink(value: setlist) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(setlist.name)
                            .font(.body.weight(.medium))
                        HStack(spacing: 12) {
                            Label("\(setlist.items.count)", systemImage: "music.note")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(setlist.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { await viewModel.deleteSetlist(id: setlist.id) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: SetList.self) { setlist in
            SetlistDetailView(setlist: setlist, viewModel: viewModel)
        }
    }
}

#Preview("Setlists") {
    NavigationStack {
        SetlistListView()
    }
}
