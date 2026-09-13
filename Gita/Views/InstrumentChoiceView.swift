import SwiftUI

struct InstrumentChoiceView: View {
    let onChoose: (Instrument) -> Void

    var body: some View {
        StageShell(step: "03 / Instrument", title: "Pick your sound.", subtitle: "Start with the instrument in your hands. You can switch later.") {
            Text("The tuner listens to your open strings, then matches the exercises to your instrument.")
                .font(.subheadline)
                .foregroundStyle(ArcadeTheme.muted)
        } trailing: {
            VStack(spacing: 12) {
                ForEach(Instrument.allCases) { instrument in
                    Button { onChoose(instrument) } label: {
                        HStack(spacing: 18) {
                            Image(systemName: instrument == .ukulele ? "music.note" : "guitars")
                                .font(.largeTitle)
                                .foregroundStyle(instrument == .ukulele ? ArcadeTheme.pink : ArcadeTheme.cyan)
                                .frame(width: 54)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(instrument.displayName)
                                    .font(.title2.weight(.black))
                                    .foregroundStyle(.white)
                                Text(instrument.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(ArcadeTheme.muted)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(ArcadeTheme.yellow)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, minHeight: 100)
                        .background(ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 22))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(ArcadeTheme.cyan.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Choose \(instrument.displayName), \(instrument.subtitle)")
                }
            }
        }
    }
}
