import SwiftUI
import UniformTypeIdentifiers
import FreeSongCore
import FreeSongImport

struct ImportView: View {
    @StateObject private var viewModel = ImportViewModel()
    @State private var showFilePicker = false
    @State private var showSongFilePicker = false

    /// Song file types accepted for single-file import — matches the extensions
    /// FileSongRepository scans: onsong, chordpro, cho, crd, pro, txt.
    private let songFileContentTypes: [UTType] = {
        let custom = ["onsong", "chordpro", "cho", "crd", "pro"]
            .compactMap { UTType(filenameExtension: $0) }
        return custom + [.plainText]
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                if viewModel.isImporting {
                    ImportProgressView(message: viewModel.importProgressMessage)
                } else if let result = viewModel.importResult {
                    resultSummary(result)
                } else if let validation = viewModel.validation {
                    validationSummary(validation)
                } else {
                    instructions
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                if !viewModel.isImporting {
                    if viewModel.importResult != nil {
                        Button("Import Another") { viewModel.reset() }
                            .buttonStyle(.bordered)
                    } else if viewModel.validation != nil {
                        Button("Start Import") {
                            Task { await viewModel.startImport() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isImporting)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Import")
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.archive, .zip],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.validateFile(url: url)
                }
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $showSongFilePicker,
            allowedContentTypes: songFileContentTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task { await viewModel.importSingleFiles(urls: urls) }
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 40))
                .foregroundStyle(.accent)
            Text("Import from OnSong Backup")
                .font(.title2.weight(.semibold))
            Text("Select a `.freesongbackup` file to import songs and setlists.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var instructions: some View {
        VStack(spacing: 16) {
            Button("Choose Backup File") {
                showFilePicker = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Import Song File(s)") {
                showSongFilePicker = true
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private func validationSummary(_ v: BackupValidation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Backup Analysis", systemImage: "doc.text.magnifyingglass")
                .font(.headline)

            if v.isValid {
                Label("Valid backup", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            Label("\(v.totalEntries) archive entries", systemImage: "archivebox")
            Label("\(v.songFileCount) song files", systemImage: "music.note")
            if v.hasDatabase {
                Label("OnSong database found", systemImage: "cylinder")
            }

            if !v.warnings.isEmpty {
                Divider()
                ForEach(v.warnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func resultSummary(_ r: ImportResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Import Complete", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)

            Label("\(r.importedFiles) songs imported", systemImage: "music.note")
            Label("\(r.importedSetlists) setlists imported", systemImage: "list.star")

            if !r.warnings.isEmpty {
                Divider()
                ForEach(r.warnings, id: \.self) { w in
                    Label(w, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }
            }

            if !r.importedNames.isEmpty {
                Divider()
                Text("Imported songs:")
                    .font(.caption.weight(.medium))
                ForEach(r.importedNames, id: \.self) { name in
                    Text("• \(name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview("Import") {
    NavigationStack {
        ImportView()
    }
}
