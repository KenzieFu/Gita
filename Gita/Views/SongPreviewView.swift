import SwiftUI

struct SongPreviewView: View {
    let info: SongPreviewInfo
    let onPlay: () -> Void
    let onClose: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Button(action: onClose) { Label("Back", systemImage: "chevron.left") }
                        .foregroundStyle(ArcadeTheme.cyan)
                    Text("BEFORE YOU PLAY")
                        .font(.caption.monospaced().weight(.black))
                        .tracking(3)
                        .foregroundStyle(ArcadeTheme.yellow)
                    Text(info.title)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                    HStack(spacing: 10) {
                        previewTag("\(info.difficulty.rawValue.capitalized) difficulty", color: ArcadeTheme.green)
                        ForEach(info.playTypes, id: \.self) { type in
                            previewTag(type, color: ArcadeTheme.cyan)
                        }
                    }
                    VStack(alignment: .leading, spacing: 9) {
                        Text("WHAT YOU'LL PRACTICE")
                            .font(.caption.monospaced().weight(.black))
                            .foregroundStyle(ArcadeTheme.yellow)
                        Text(info.playTypes.joined(separator: " + "))
                            .font(.title3.weight(.bold))
                        if !info.chordNames.isEmpty {
                            Text("Chords in this song")
                                .font(.subheadline)
                                .foregroundStyle(ArcadeTheme.muted)
                            HStack(spacing: 8) {
                                ForEach(info.chordNames, id: \.self) { chord in
                                    Text(chord)
                                        .font(.headline.monospaced().weight(.black))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 9)
                                        .background(ArcadeTheme.cyan.opacity(0.16), in: RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        } else {
                            Text("No chords yet—focus on one note at a time.")
                                .foregroundStyle(ArcadeTheme.muted)
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 16))
                    Button(action: onPlay) {
                        Label("Let's play", systemImage: "play.fill")
                            .font(.headline.weight(.black))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ArcadeTheme.cyan)
                    Text("Start slowly. You can repeat this part as many times as you need.")
                        .font(.footnote)
                        .foregroundStyle(ArcadeTheme.muted)
                }
                .padding(24)
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
            .background(ArcadeTheme.background.ignoresSafeArea())
        }
        .preferredColorScheme(.dark)
    }

    private func previewTag(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption.weight(.black))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color.opacity(0.14), in: Capsule())
    }
}
