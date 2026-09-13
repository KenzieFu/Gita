import SwiftUI

struct ReadyView: View {
    let instrument: Instrument
    let onRetune: () -> Void
    let onReplay: () -> Void
    let onSwitch: () -> Void

    var body: some View {
        StageShell(step: "Setup complete", title: "You're ready to play.", subtitle: "Your \(instrument.displayName.lowercased()) is set up. Keep practicing whenever you want.") {
            Text("FIRST SESSION CLEAR")
                .font(.caption.monospaced().weight(.black))
                .foregroundStyle(ArcadeTheme.yellow)
        } trailing: {
            StagePanel {
                VStack(spacing: 14) {
                    NeonNote(symbol: "checkmark.seal.fill", label: "NICE WORK", color: ArcadeTheme.yellow)
                    StageButton(title: "Tune again", symbol: "waveform", action: onRetune)
                    StageButton(title: "Replay tutorial", symbol: "arrow.counterclockwise", secondary: true, action: onReplay)
                    StageButton(title: "Switch instrument", symbol: "guitars", secondary: true, action: onSwitch)
                }
            }
        }
    }
}
