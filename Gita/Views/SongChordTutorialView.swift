import SwiftUI

struct SongChordTutorialView: View {
    let chart: SongChart
    let arrangement: SongArrangement
    let onFinish: () -> Void
    let onClose: () -> Void
    @State private var chordIndex = 0

    private var chords: [ChordDefinition] {
        arrangement.chordIDs.compactMap { chart.experience?.chord(id: $0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Button(action: onClose) { Label("Back", systemImage: "chevron.left") }
                    .foregroundStyle(ArcadeTheme.cyan)
                Text("CHORD WARM-UP")
                    .font(.caption.monospaced().weight(.black))
                    .foregroundStyle(ArcadeTheme.yellow)
                Text("Learn the shapes before the lyrics move.")
                    .font(.largeTitle.weight(.black))
                Text("\(arrangement.tier.title) · \(chordIndex + 1) of \(chords.count)")
                    .foregroundStyle(ArcadeTheme.muted)
                if chords.indices.contains(chordIndex) {
                    let chord = chords[chordIndex]
                    VStack(alignment: .leading, spacing: 16) {
                        Text(chord.displayName).font(.system(size: 58, weight: .black, design: .rounded))
                            .foregroundStyle(ArcadeTheme.cyan)
                        HStack(spacing: 12) {
                            ForEach(chord.frets.indices, id: \.self) { index in
                                VStack(spacing: 8) {
                                    Text(chart.stringLabels[index]).font(.headline)
                                    Text(chord.frets[index].map(String.init) ?? "×")
                                        .font(.title.weight(.black))
                                        .frame(width: 54, height: 54)
                                        .background(ArcadeTheme.cyan.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                        Text("0 = open string · × = muted · number = fret. Shape the chord, then strum slowly and listen for each string.")
                            .foregroundStyle(ArcadeTheme.muted)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 20))
                }
                Button(chordIndex + 1 < chords.count ? "Next chord" : "Continue to song") {
                    if chordIndex + 1 < chords.count { chordIndex += 1 } else { onFinish() }
                }
                .buttonStyle(.borderedProminent)
                .tint(ArcadeTheme.cyan)
                Button("Continue without a microphone score", action: onFinish)
                    .font(.subheadline)
                    .foregroundStyle(ArcadeTheme.muted)
            }
            .padding(22)
        }
        .background(ArcadeTheme.background.ignoresSafeArea())
    }
}
