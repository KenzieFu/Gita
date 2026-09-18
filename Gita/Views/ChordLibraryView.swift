import SwiftUI

struct ChordLibraryView: View {
    let instrument: Instrument
    let onClose: () -> Void

    private var stringLabels: [String] {
        instrument == .ukulele ? ["G", "C", "E", "A"] : ["E", "A", "D", "G", "B", "e"]
    }

    private var chords: [ChordDefinition] {
        if instrument == .ukulele {
            return [
                ChordDefinition(id: "C", displayName: "C", frets: [0, 0, 0, 3]),
                ChordDefinition(id: "G", displayName: "G", frets: [0, 2, 3, 2]),
                ChordDefinition(id: "Am", displayName: "Am", frets: [2, 0, 0, 0]),
                ChordDefinition(id: "Dm", displayName: "Dm", frets: [2, 2, 1, 0]),
                ChordDefinition(id: "F", displayName: "F", frets: [2, 0, 1, 0]),
                ChordDefinition(id: "Em", displayName: "Em", frets: [0, 4, 3, 2])
            ]
        }
        return [
            ChordDefinition(id: "C", displayName: "C", frets: [nil, 3, 2, 0, 1, 0]),
            ChordDefinition(id: "G", displayName: "G", frets: [3, 2, 0, 0, 0, 3]),
            ChordDefinition(id: "Am", displayName: "Am", frets: [nil, 0, 2, 2, 1, 0]),
            ChordDefinition(id: "Dm", displayName: "Dm", frets: [nil, nil, 0, 2, 3, 1]),
            ChordDefinition(id: "F", displayName: "F", frets: [1, 3, 3, 2, 1, 1]),
            ChordDefinition(id: "Em", displayName: "Em", frets: [0, 2, 2, 0, 0, 0])
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button(action: onClose) { Label("Settings", systemImage: "chevron.left") }
                Spacer()
                Text("CHORD LIBRARY")
                    .font(.caption.monospaced().weight(.black))
                    .tracking(2)
                    .foregroundStyle(ArcadeTheme.yellow)
            }
            .foregroundStyle(ArcadeTheme.cyan)

            VStack(alignment: .leading, spacing: 3) {
                Text("Common \(instrument.displayName) chords")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                Text("Open circles are unfretted strings. × means do not play that string.")
                    .font(.subheadline)
                    .foregroundStyle(ArcadeTheme.muted)
            }

            ScrollView(.horizontal) {
                LazyHStack(spacing: 14) {
                    ForEach(chords) { chord in
                        LibraryChordCard(chord: chord, stringLabels: stringLabels)
                            .containerRelativeFrame(.horizontal, count: 4, spacing: 14)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        }
        .padding(22)
        .background(ArcadeTheme.background.ignoresSafeArea())
    }
}

private struct LibraryChordCard: View {
    let chord: ChordDefinition
    let stringLabels: [String]

    var body: some View {
        VStack(spacing: 10) {
            Text(chord.displayName)
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(ArcadeTheme.cyan)
            GeometryReader { geometry in
                let count = max(chord.frets.count, 1)
                let spacing = geometry.size.width / CGFloat(count)
                ZStack(alignment: .topLeading) {
                    ForEach(0..<count, id: \.self) { string in
                        let x = spacing * (CGFloat(string) + 0.5)
                        Rectangle().fill(Color.white.opacity(0.45)).frame(width: 1)
                            .position(x: x, y: geometry.size.height / 2)
                    }
                    ForEach(0..<5, id: \.self) { fret in
                        Rectangle().fill(Color.white.opacity(fret == 0 ? 0.8 : 0.3)).frame(height: fret == 0 ? 3 : 1)
                            .position(x: geometry.size.width / 2, y: 18 + CGFloat(fret) * 27)
                    }
                    ForEach(chord.frets.indices, id: \.self) { string in
                        let x = spacing * (CGFloat(string) + 0.5)
                        if let fret = chord.frets[string] {
                            if fret == 0 {
                                Circle().stroke(Color.white, lineWidth: 2).frame(width: 12, height: 12).position(x: x, y: 7)
                            } else {
                                Text("\(fret)").font(.caption2.weight(.black)).foregroundStyle(ArcadeTheme.background)
                                    .frame(width: 23, height: 23).background(ArcadeTheme.yellow, in: Circle())
                                    .position(x: x, y: 18 + (CGFloat(fret) - 0.5) * 27)
                            }
                        } else {
                            Text("×").font(.headline.weight(.black)).position(x: x, y: 7)
                        }
                    }
                }
            }
            .frame(height: 132)
            HStack(spacing: 0) {
                ForEach(stringLabels.indices, id: \.self) { index in
                    Text(stringLabels[index]).frame(maxWidth: .infinity)
                }
            }
            .font(.caption.monospaced().weight(.bold))
            .foregroundStyle(ArcadeTheme.muted)
        }
        .padding(14)
        .background(ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(ArcadeTheme.cyan.opacity(0.25)))
    }
}
