import SwiftUI

struct TakeResultView: View {
    let take: PracticeTake
    let suggestedTitle: String
    let suggestedDay: Int
    let onSave: (ChallengeEntry) -> Void
    let onClose: () -> Void

    @State private var day: Int
    @State private var songTitle: String

    init(take: PracticeTake, suggestedTitle: String, suggestedDay: Int, onSave: @escaping (ChallengeEntry) -> Void, onClose: @escaping () -> Void) {
        self.take = take
        self.suggestedTitle = suggestedTitle
        self.suggestedDay = suggestedDay
        self.onSave = onSave
        self.onClose = onClose
        _day = State(initialValue: min(100, max(1, suggestedDay)))
        _songTitle = State(initialValue: suggestedTitle)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Button(action: onClose) {
                        Label("Back to practice", systemImage: "chevron.left")
                    }
                    .foregroundStyle(ArcadeTheme.cyan)

                    Text("TAKE COMPLETE")
                        .font(.caption.monospaced().weight(.black))
                        .tracking(3)
                        .foregroundStyle(ArcadeTheme.yellow)
                    Text("Your practice, your pace.")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                    HStack(spacing: 18) {
                        metric("NOTES HEARD", "\(take.hitCount) / \(take.noteCount)")
                        metric("NOTE MATCH", "\(Int((take.accuracy * 100).rounded()))%")
                        metric("SPEED", "\(Int((take.speed * 100).rounded()))%")
                    }

                    HStack(spacing: 14) {
                        VStack(alignment: .leading) {
                            Text("CHALLENGE DAY")
                                .font(.caption.monospaced().weight(.bold))
                                .foregroundStyle(ArcadeTheme.muted)
                            Stepper("Day \(day)", value: $day, in: 1...100)
                        }
                        VStack(alignment: .leading) {
                            Text("SONG / PRACTICE NAME")
                                .font(.caption.monospaced().weight(.bold))
                                .foregroundStyle(ArcadeTheme.muted)
                            TextField("Name this practice", text: $songTitle)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(16)
                    .background(ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 14))

                    HStack {
                        Text("Pick any day and practice. The day is not assigned automatically to a song.")
                            .font(.caption)
                            .foregroundStyle(ArcadeTheme.muted)
                        Spacer()
                        Button("Save to challenge") {
                            onSave(ChallengeEntry(day: day, songTitle: songTitle.trimmingCharacters(in: .whitespacesAndNewlines), take: take))
                        }
                        .disabled(songTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .buttonStyle(.borderedProminent)
                        .tint(ArcadeTheme.cyan)
                    }
                    Text("Scoring is experimental. This result confirms matching notes, not the exact string or finger placement. Video export is not available yet.")
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

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption.monospaced().weight(.bold)).foregroundStyle(ArcadeTheme.muted)
            Text(value).font(.title2.weight(.black)).foregroundStyle(ArcadeTheme.green)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 12))
    }
}
