import SwiftUI

/// Manual chord progression display. Cue times come directly from Chart Studio;
/// lyrics are deliberately not used as the gameplay clock.
struct LyricPlayerSurface: View {
    let experience: SongExperience
    let arrangement: SongArrangement
    let section: SongSection
    let position: Double
    let nominalBPM: Double

    private var sectionCues: [ChordCue] {
        let tokenSections = Dictionary(uniqueKeysWithValues: experience.lyricLines.flatMap { line in
            line.tokens.map { ($0.id, line.sectionID) }
        })
        return arrangement.cues.filter { cue in
            if let tokenID = cue.lyricTokenID, let owner = tokenSections[tokenID] { return owner == section.id }
            return cue.onsetSeconds >= section.startSeconds && cue.onsetSeconds < section.endSeconds
        }
    }

    private var currentIndex: Int? { sectionCues.lastIndex { $0.onsetSeconds <= position } }
    private var currentCue: ChordCue? { currentIndex.map { sectionCues[$0] } }
    private var nextCue: ChordCue? { sectionCues.first { $0.onsetSeconds > position } }
    private var beatProgress: Double {
        guard nominalBPM > 0 else { return 0 }
        let beats = max(0, position - section.startSeconds) * nominalBPM / 60
        return beats - floor(beats)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 12) {
                Circle()
                    .fill(ArcadeTheme.yellow)
                    .frame(width: 16, height: 16)
                    .scaleEffect(1 + 0.38 * sin(beatProgress * .pi))
                    .shadow(color: ArcadeTheme.yellow.opacity(0.75), radius: 9)
                Text("FOLLOW THE CHORD PROGRESSION")
                    .font(.caption.monospaced().weight(.black))
                    .tracking(1.5)
                    .foregroundStyle(ArcadeTheme.yellow)
                Spacer()
                Text("\(Int(nominalBPM.rounded())) BPM")
                    .font(.caption.monospaced().weight(.black))
                    .foregroundStyle(ArcadeTheme.muted)
            }

            HStack(spacing: 12) {
                focusCard(label: "PLAY", cue: currentCue, color: ArcadeTheme.cyan)
                Image(systemName: "chevron.right")
                    .font(.title2.weight(.black))
                    .foregroundStyle(ArcadeTheme.muted)
                focusCard(label: nextInstruction, cue: nextCue, color: ArcadeTheme.yellow)
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(sectionCues.enumerated()), id: \.element.id) { index, cue in
                            VStack(spacing: 4) {
                                Text(experience.chord(id: cue.chordID)?.displayName ?? cue.chordID)
                                    .font(.title3.monospaced().weight(.black))
                                Text(cue.onsetSeconds, format: .number.precision(.fractionLength(2)))
                                    .font(.caption2.monospaced().weight(.bold))
                                    .opacity(0.7)
                            }
                            .foregroundStyle(index == currentIndex ? ArcadeTheme.background : .primary)
                            .frame(minWidth: 66, minHeight: 55)
                            .background(index == currentIndex ? ArcadeTheme.cyan : ArcadeTheme.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(index == currentIndex ? ArcadeTheme.cyan : ArcadeTheme.muted.opacity(0.25)))
                            .id(cue.id)
                        }
                    }
                }
                .onChange(of: currentCue?.id) { _, cueID in
                    if let cueID { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(cueID, anchor: .center) } }
                }
            }
        }
        .padding(18)
        .background(ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private func focusCard(label: String, cue: ChordCue?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.monospaced().weight(.black))
                .foregroundStyle(color)
            Text(cue.flatMap { experience.chord(id: $0.chordID)?.displayName } ?? "—")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .minimumScaleFactor(0.65)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(ArcadeTheme.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.5), lineWidth: 2))
    }

    private var nextInstruction: String {
        guard let nextCue else { return "NEXT" }
        let beats = max(0, nextCue.onsetSeconds - position) * nominalBPM / 60
        if beats < 0.5 { return "NOW" }
        let count = max(1, Int(beats.rounded(.up)))
        return "NEXT · \(count) BEAT\(count == 1 ? "" : "S")"
    }

    private var accessibilitySummary: String {
        let current = currentCue.flatMap { experience.chord(id: $0.chordID)?.displayName } ?? "none"
        let next = nextCue.flatMap { experience.chord(id: $0.chordID)?.displayName } ?? "none"
        return "Current chord \(current). Next chord \(next)."
    }
}
