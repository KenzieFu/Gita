import SwiftUI

struct ReadyView: View {
    let instrument: Instrument
    let isGuest: Bool
    let onRetune: () -> Void
    let onReplay: () -> Void
    let onSwitch: () -> Void
    let onSignIn: () -> Void

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
                    if isGuest {
                        StageButton(title: "Sign in with Apple", symbol: "person.crop.circle", secondary: true, action: onSignIn)
                        Text("Your guest practice remains on this device; signing in does not merge it.")
                            .font(.footnote)
                            .foregroundStyle(ArcadeTheme.muted)
                    }
                }
            }
        }
    }
}
