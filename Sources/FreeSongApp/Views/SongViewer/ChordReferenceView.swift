import SwiftUI

// MARK: - Chord Shape Model

struct ChordShape: Identifiable {
    let id = UUID()
    let name: String
    let suffix: String
    /// Frets: 6 strings, -1 = muted, 0 = open, 1+ = fret number
    let frets: [Int]
    /// Fingers: 0 = no finger, 1-4 = finger number
    let fingers: [Int]
    /// Starting fret (for barre chords)
    let barre: Int?

    static let all: [ChordShape] = {
        let major = [
            ChordShape(name: "C", suffix: "", frets: [-1, 3, 2, 0, 1, 0], fingers: [0, 3, 2, 0, 1, 0], barre: nil),
            ChordShape(name: "D", suffix: "", frets: [-1, -1, 0, 2, 3, 2], fingers: [0, 0, 0, 2, 3, 1], barre: nil),
            ChordShape(name: "E", suffix: "", frets: [0, 2, 2, 1, 0, 0], fingers: [0, 2, 3, 1, 0, 0], barre: nil),
            ChordShape(name: "F", suffix: "", frets: [1, 1, 2, 3, 3, 1], fingers: [1, 1, 2, 3, 4, 1], barre: 1),
            ChordShape(name: "G", suffix: "", frets: [3, 2, 0, 0, 0, 3], fingers: [2, 1, 0, 0, 0, 3], barre: nil),
            ChordShape(name: "A", suffix: "", frets: [-1, 0, 2, 2, 2, 0], fingers: [0, 0, 2, 3, 4, 0], barre: nil),
            ChordShape(name: "B", suffix: "", frets: [-1, 2, 4, 4, 4, 2], fingers: [0, 1, 2, 3, 4, 1], barre: 2),
        ]
        let minor = [
            ChordShape(name: "Cm", suffix: "m", frets: [-1, 3, 5, 5, 4, 3], fingers: [0, 1, 3, 4, 2, 1], barre: 3),
            ChordShape(name: "Dm", suffix: "m", frets: [-1, -1, 0, 2, 3, 1], fingers: [0, 0, 0, 2, 3, 1], barre: nil),
            ChordShape(name: "Em", suffix: "m", frets: [0, 2, 2, 0, 0, 0], fingers: [0, 2, 3, 0, 0, 0], barre: nil),
            ChordShape(name: "Fm", suffix: "m", frets: [1, 1, 2, 2, 1, 1], fingers: [1, 1, 2, 3, 1, 1], barre: 1),
            ChordShape(name: "Gm", suffix: "m", frets: [3, 3, 5, 5, 4, 3], fingers: [1, 1, 3, 4, 2, 1], barre: 3),
            ChordShape(name: "Am", suffix: "m", frets: [-1, 0, 2, 2, 1, 0], fingers: [0, 0, 2, 3, 1, 0], barre: nil),
            ChordShape(name: "Bm", suffix: "m", frets: [-1, 2, 4, 4, 3, 2], fingers: [0, 1, 3, 4, 2, 1], barre: 2),
        ]
        let seventh = [
            ChordShape(name: "C7", suffix: "7", frets: [-1, 3, 2, 3, 1, 0], fingers: [0, 3, 2, 4, 1, 0], barre: nil),
            ChordShape(name: "D7", suffix: "7", frets: [-1, -1, 0, 2, 1, 2], fingers: [0, 0, 0, 2, 1, 3], barre: nil),
            ChordShape(name: "E7", suffix: "7", frets: [0, 2, 0, 1, 0, 0], fingers: [0, 2, 0, 1, 0, 0], barre: nil),
            ChordShape(name: "G7", suffix: "7", frets: [3, 2, 0, 0, 0, 1], fingers: [2, 1, 0, 0, 0, 3], barre: nil),
            ChordShape(name: "A7", suffix: "7", frets: [-1, 0, 2, 0, 2, 0], fingers: [0, 0, 2, 0, 3, 0], barre: nil),
            ChordShape(name: "B7", suffix: "7", frets: [-1, 2, 1, 2, 0, 2], fingers: [0, 2, 1, 3, 0, 4], barre: nil),
        ]
        let other = [
            ChordShape(name: "C", suffix: "maj7", frets: [-1, 3, 2, 0, 0, 0], fingers: [0, 3, 2, 0, 0, 0], barre: nil),
            ChordShape(name: "D", suffix: "maj7", frets: [-1, -1, 0, 2, 2, 2], fingers: [0, 0, 0, 1, 2, 3], barre: nil),
            ChordShape(name: "Am7", suffix: "m7", frets: [-1, 0, 2, 0, 1, 0], fingers: [0, 0, 2, 0, 1, 0], barre: nil),
            ChordShape(name: "Em7", suffix: "m7", frets: [0, 2, 0, 0, 0, 0], fingers: [0, 2, 0, 0, 0, 0], barre: nil),
            ChordShape(name: "Dm7", suffix: "m7", frets: [-1, -1, 0, 2, 1, 1], fingers: [0, 0, 0, 3, 1, 1], barre: nil),
            ChordShape(name: "Dsus4", suffix: "sus4", frets: [-1, -1, 0, 2, 3, 3], fingers: [0, 0, 0, 1, 2, 3], barre: nil),
            ChordShape(name: "Asus4", suffix: "sus4", frets: [-1, 0, 2, 2, 3, 0], fingers: [0, 0, 1, 2, 3, 0], barre: nil),
            ChordShape(name: "Dsus2", suffix: "sus2", frets: [-1, -1, 0, 2, 3, 0], fingers: [0, 0, 0, 1, 2, 0], barre: nil),
            ChordShape(name: "Asus2", suffix: "sus2", frets: [-1, 0, 2, 2, 0, 0], fingers: [0, 0, 1, 2, 0, 0], barre: nil),
        ]
        return major + minor + seventh + other
    }()

    static let categories: [(name: String, icon: String, chords: [ChordShape])] = [
        ("Major", "house", ChordShape.all.filter { $0.suffix == "" && $0.name.count == 1 }),
        ("Minor", "minus.circle", ChordShape.all.filter { $0.suffix == "m" }),
        ("Seventh", "7.circle", ChordShape.all.filter { $0.suffix == "7" }),
        ("Other", "ellipsis.circle", ChordShape.all.filter { !["", "m", "7"].contains($0.suffix) }),
    ]
}

// MARK: - Fretboard View

struct FretboardView: View {
    let chord: ChordShape

    private let stringCount = 6
    private let fretCount = 5

    var body: some View {
        GeometryReader { geometry in
            let stringSpacing = geometry.size.width / CGFloat(stringCount + 1)
            let fretSpacing = geometry.size.height / CGFloat(fretCount + 1)

            ZStack {
                // Strings (vertical lines)
                ForEach(0..<stringCount, id: \.self) { i in
                    let x = stringSpacing * CGFloat(i + 1)
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: i == 0 ? 1.5 : (i == 5 ? 1.5 : 1))
                        .position(x: x, y: geometry.size.height / 2)
                        .frame(width: 1, height: geometry.size.height)
                }

                // Frets (horizontal lines)
                ForEach(0...fretCount, id: \.self) { i in
                    let y = fretSpacing * CGFloat(i + 1)
                    Rectangle()
                        .fill(i == 0 ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(height: i == 0 ? 2 : 1)
                        .position(x: geometry.size.width / 2, y: y)
                }

                // Nut (thicker top line for open chords)
                Rectangle()
                    .fill(Color.primary)
                    .frame(height: 2.5)
                    .position(x: geometry.size.width / 2, y: fretSpacing)

                // Fret markers and finger positions
                ForEach(0..<stringCount, id: \.self) { string in
                    let x = stringSpacing * CGFloat(string + 1)
                    let fret = chord.frets[string]

                    if fret == -1 {
                        // Muted string: X above nut
                        Text("×")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .position(x: x, y: fretSpacing * 0.4)
                    } else if fret == 0 {
                        // Open string: O above nut
                        Text("○")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .position(x: x, y: fretSpacing * 0.4)
                    } else {
                        let finger = chord.fingers[string]
                        let displayFret = chord.barre.map { fret - $0 + 1 } ?? fret
                        let y = fretSpacing * CGFloat(displayFret + 1) - fretSpacing * 0.5

                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 22, height: 22)
                            .position(x: x, y: y)

                        Text("\(finger)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .position(x: x, y: y)
                    }
                }

                // Starting fret label (for barre chords)
                if let barre = chord.barre {
                    Text("\(barre)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .position(x: stringSpacing * 0.3, y: fretSpacing * 1.5)
                }
            }
        }
        .aspectRatio(0.8, contentMode: .fit)
    }
}

// MARK: - Chord Reference View

struct ChordReferenceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchQuery = ""
    @State private var selectedCategory: String = "Major"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category picker
                Picker("Category", selection: $selectedCategory) {
                    ForEach(ChordShape.categories, id: \.name) { category in
                        Label(category.name, systemImage: category.icon).tag(category.name)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Chord grid
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 16) {
                        let chords = filteredChords
                        if chords.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.secondary)
                                Text("No Chords Found")
                                    .font(.headline)
                                Text("Try a different search.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 60)
                        } else {
                            ForEach(chords) { chord in
                                chordCard(chord)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Chord Reference")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .searchable(text: $searchQuery, prompt: "Search chords")
        }
    }

    private var filteredChords: [ChordShape] {
        let chords = ChordShape.categories
            .first(where: { $0.name == selectedCategory })?.chords ?? ChordShape.all
        if searchQuery.isEmpty { return chords }
        return chords.filter {
            "\($0.name)\($0.suffix)".localizedCaseInsensitiveContains(searchQuery)
        }
    }

    private func chordCard(_ chord: ChordShape) -> some View {
        VStack(spacing: 8) {
            FretboardView(chord: chord)
                .frame(height: 120)

            Text("\(chord.name)\(chord.suffix)")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
        .padding(8)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview("Chord Reference") {
    ChordReferenceView()
}
