import SwiftUI
import FreeSongCore
import FreeSongStorage
#if os(iOS)
import UIKit
#endif

/// Song editor: a single always-editable text view for both chord formats. On iOS
/// the cursor-driven chord-shift controls float in a pill anchored to the caret
/// (mirroring Android's cursor-anchored PopupWindow); the fixed bottom bar keeps
/// the delete / font / format-toggle actions.
struct SongEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: SongEditorViewModel
    @AppStorage("songEditorFontSize") private var fontSize: Double = 16
    private let title: String
    #if os(iOS)
    /// Caret rect in the text editor's (visible) coordinate space; `.null` when unknown.
    @State private var caretRect: CGRect = .null
    @State private var pillSize: CGSize = .zero
    #endif

    init(song: Song, onSave: @escaping () -> Void = {}, onDelete: @escaping () -> Void = {}) {
        self.title = song.title
        _vm = StateObject(wrappedValue: SongEditorViewModel(song: song, onSave: onSave, onDelete: onDelete))
    }

    var body: some View {
        NavigationStack {
            editor
                .safeAreaInset(edge: .bottom) { bottomBar }
                .navigationTitle("Edit \(title)")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar { toolbarContent }
                .interactiveDismissDisabled(vm.isDirty)
                .alert("Delete Song?", isPresented: $vm.showDeleteConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) { vm.delete() }
                } message: {
                    Text("Delete \"\(title)\"? This cannot be undone.")
                }
                .confirmationDialog("Discard Changes?", isPresented: $vm.showDiscardConfirmation, titleVisibility: .visible) {
                    Button("Discard", role: .destructive) { dismiss() }
                    Button("Keep Editing", role: .cancel) { }
                }
                .alert("Error", isPresented: .init(
                    get: { vm.errorMessage != nil },
                    set: { if !$0 { vm.errorMessage = nil } }
                )) {
                    Button("OK") { vm.errorMessage = nil }
                } message: {
                    Text(vm.errorMessage ?? "")
                }
                .onChange(of: vm.isFinished) { finished in
                    if finished { dismiss() }
                }
        }
    }

    // MARK: - Editor text view

    @ViewBuilder
    private var editor: some View {
        #if os(iOS)
        ChordTextEditorWrapper(
            text: $vm.editedContent,
            selection: $vm.selectedRange,
            fontSize: CGFloat(fontSize),
            caretRect: $caretRect
        )
        .overlay { floatingChordPill }
        #else
        TextEditor(text: $vm.editedContent)
            .font(.system(size: fontSize, design: .monospaced))
            .autocorrectionDisabled(true)
            .padding()
        #endif
    }

    // MARK: - Floating chord-shift pill (iOS)

    #if os(iOS)
    /// Floating shift controls anchored to the caret, like Android's PopupWindow:
    /// above the caret by default, flipped below when too close to the top, X
    /// clamped so the pill never leaves the visible bounds.
    @ViewBuilder
    private var floatingChordPill: some View {
        if let chord = vm.chordAtCursor, !caretRect.isNull {
            GeometryReader { geo in
                chordShiftControls(chord)
                    .background(GeometryReader { pill in
                        Color.clear.preference(key: PillSizeKey.self, value: pill.size)
                    })
                    .onPreferenceChange(PillSizeKey.self) { pillSize = $0 }
                    .position(pillPosition(in: geo.size))
            }
        }
    }

    private func pillPosition(in container: CGSize) -> CGPoint {
        let width = max(pillSize.width, 44)
        let height = max(pillSize.height, 40)
        let margin: CGFloat = 8
        // Clamp X into the visible bounds — this is the fix for the old clipping bug.
        let x = min(max(caretRect.midX, width / 2 + margin), container.width - width / 2 - margin)
        // Above the caret by default; flip below when it would poke past the top.
        var y = caretRect.minY - height / 2 - margin
        if y - height / 2 < margin {
            y = caretRect.maxY + height / 2 + margin
        }
        return CGPoint(x: x, y: y)
    }

    private func chordShiftControls(_ chord: SongEditorViewModel.ChordCursor) -> some View {
        HStack(spacing: 16) {
            Button { vm.shift(delta: -1, wordwise: true) }  label: { Image(systemName: "chevron.left.2") }
            Button { vm.shift(delta: -1, wordwise: false) } label: { Image(systemName: "chevron.left") }
            Text(chord.name)
                .font(.system(.subheadline, design: .monospaced).weight(.bold))
                .foregroundStyle(.accent)
            Button { vm.shift(delta: 1, wordwise: false) }  label: { Image(systemName: "chevron.right") }
            Button { vm.shift(delta: 1, wordwise: true) }   label: { Image(systemName: "chevron.right.2") }
        }
        .font(.title3)
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(.regularMaterial).shadow(color: .black.opacity(0.2), radius: 4, y: 2))
        .fixedSize()
    }

    private struct PillSizeKey: PreferenceKey {
        static var defaultValue: CGSize = .zero
        static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
    }
    #endif

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            #if !os(iOS)
            // macOS fallback keeps the non-floating shift bar.
            if let chord = vm.chordAtCursor {
                chordShiftBar(chord)
                Divider()
            }
            #endif
            HStack {
                Button(role: .destructive) {
                    vm.showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash").foregroundStyle(.red)
                }

                Spacer()
                fontControls
                Spacer()

                Button { vm.toggleFormat() } label: {
                    Label(
                        vm.isInlineFormat ? "→ Above" : "→ Inline",
                        systemImage: vm.isInlineFormat ? "list.bullet.indent" : "text.alignleft"
                    )
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    #if !os(iOS)
    private func chordShiftBar(_ chord: SongEditorViewModel.ChordCursor) -> some View {
        HStack(spacing: 20) {
            Button { vm.shift(delta: -1, wordwise: true) }  label: { Image(systemName: "chevron.left.2") }
            Button { vm.shift(delta: -1, wordwise: false) } label: { Image(systemName: "chevron.left") }
            Text(chord.name)
                .font(.system(.subheadline, design: .monospaced).weight(.bold))
                .foregroundStyle(.accent)
                .frame(minWidth: 44)
            Button { vm.shift(delta: 1, wordwise: false) }  label: { Image(systemName: "chevron.right") }
            Button { vm.shift(delta: 1, wordwise: true) }   label: { Image(systemName: "chevron.right.2") }
        }
        .font(.title3)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }
    #endif

    private var fontControls: some View {
        HStack(spacing: 8) {
            Button { fontSize = max(10, fontSize - 2) } label: { Image(systemName: "textformat.size.smaller") }
            Text("\(Int(fontSize))").font(.caption.monospacedDigit()).frame(minWidth: 22)
            Button { fontSize = min(32, fontSize + 2) } label: { Image(systemName: "textformat.size.larger") }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { vm.requestCancel(dismiss: { dismiss() }) }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") { vm.save() }.disabled(!vm.isDirty)
        }
    }
}

// MARK: - ChordTextEditorWrapper is defined in ChordTextEditor.swift