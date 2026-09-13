import SwiftUI

struct WelcomeView: View {
    let onStart: () -> Void

    var body: some View {
        StageShell(step: "01 / Welcome", title: "Make your first note.", subtitle: "Choose your instrument, tune up, then play along with three tiny lessons.") {
            StageButton(title: "Let's start", symbol: "arrow.right", action: onStart)
                .frame(maxWidth: 300)
            Text("One quick setup. Your music starts here.")
                .font(.subheadline)
                .foregroundStyle(ArcadeTheme.muted)
        } trailing: {
            StagePanel {
                VStack(spacing: 16) {
                    NeonNote(symbol: "music.note", label: "LISTEN · PLAY · LEVEL UP", color: ArcadeTheme.pink)
                    HStack {
                        Label("Pick", systemImage: "guitars")
                        Spacer()
                        Label("Tune", systemImage: "waveform")
                        Spacer()
                        Label("Play", systemImage: "sparkles")
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ArcadeTheme.yellow)
                }
            }
        }
    }
}
