import SwiftUI

struct FretFinderView: View {
    let instrument: Instrument
    let tuning: UkuleleTuning?
    let onClose: () -> Void

    @State private var game: FretFinderGame
    @State private var feedback = "Tap the matching string and fret."

    init(instrument: Instrument, tuning: UkuleleTuning?, onClose: @escaping () -> Void) {
        self.instrument = instrument
        self.tuning = tuning
        self.onClose = onClose
        _game = State(initialValue: FretFinderGame(stringCount: instrument.stringCount, maxFret: 5))
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Button(action: onClose) { Label("Back", systemImage: "chevron.left") }
                        .foregroundStyle(ArcadeTheme.cyan)
                    Text("FRET FINDER")
                        .font(.caption.monospaced().weight(.black))
                        .tracking(3)
                        .foregroundStyle(ArcadeTheme.yellow)
                    Text("Find \(targetLabel) · fret \(game.target.fret)")
                        .font(.system(size: 31, weight: .black, design: .rounded))
                    Text("Fret 0 is the open string. For other frets, press just behind the metal fret line.")
                        .foregroundStyle(ArcadeTheme.muted)
                    HStack(spacing: 5) {
                        Text("STRING")
                            .frame(width: 70, alignment: .leading)
                        ForEach(0...game.maxFret, id: \.self) { fret in
                            Text("\(fret)").frame(maxWidth: .infinity)
                        }
                    }
                    .font(.caption.monospaced().weight(.bold))
                    .foregroundStyle(ArcadeTheme.yellow)
                    ForEach(0..<game.stringCount, id: \.self) { stringIndex in
                        HStack(spacing: 5) {
                            Text(labels[stringIndex])
                                .font(.headline.weight(.black))
                                .foregroundStyle(ArcadeTheme.cyan)
                                .frame(width: 70, alignment: .leading)
                            ForEach(0...game.maxFret, id: \.self) { fret in
                                Button {
                                    feedback = game.select(stringIndex: stringIndex, fret: fret)
                                        ? "Yes! Next position unlocked."
                                        : "Not this one. Follow the string label and fret number."
                                } label: {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(ArcadeTheme.panel)
                                        .overlay {
                                            Text("\(fret)")
                                                .font(.headline.monospaced().weight(.bold))
                                                .foregroundStyle(ArcadeTheme.cyan)
                                        }
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity)
                                .frame(height: 43)
                                .accessibilityLabel("\(labels[stringIndex]) string, fret \(fret)")
                            }
                        }
                    }
                    Text(feedback)
                        .font(.headline)
                        .foregroundStyle(ArcadeTheme.green)
                    Text("\(game.correctCount) positions found · Touch practice only. This does not check your real fingers.")
                        .font(.caption)
                        .foregroundStyle(ArcadeTheme.muted)
                }
                .padding(24)
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
            .background(ArcadeTheme.background.ignoresSafeArea())
        }
        .preferredColorScheme(.dark)
    }

    private var labels: [String] {
        instrument.tuningTargets(tuning).map(\.label)
    }

    private var targetLabel: String { labels[game.target.stringIndex] }
}
