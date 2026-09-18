import SwiftUI

/// The briefing shown after choosing a song and before microphone gameplay.
struct SongExperiencePreviewView: View {
    let chart: SongChart
    let initialTier: ArrangementTier
    let contextTitle: String?
    let locksTier: Bool
    let onPlay: (ArrangementTier) -> Void
    let onClose: () -> Void

    @State private var selectedTier: ArrangementTier
    @State private var appeared = false

    init(
        chart: SongChart,
        initialTier: ArrangementTier,
        contextTitle: String? = nil,
        locksTier: Bool = false,
        onPlay: @escaping (ArrangementTier) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.chart = chart
        self.initialTier = initialTier
        self.contextTitle = contextTitle
        self.locksTier = locksTier
        self.onPlay = onPlay
        self.onClose = onClose
        _selectedTier = State(initialValue: initialTier)
    }

    private var arrangement: SongArrangement? {
        chart.experience?.arrangement(for: selectedTier)
    }

    private var chordNames: [String] {
        guard let arrangement, let experience = chart.experience else { return chart.chordNames }
        return arrangement.chordIDs.compactMap { experience.chord(id: $0)?.displayName }
    }

    private var canPlay: Bool { chart.experience == nil || arrangement != nil }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header
                HStack(spacing: 24) {
                    cover.frame(width: min(300, geometry.size.width * 0.34))
                    briefing.frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background {
                ZStack {
                    ArcadeTheme.background
                    RadialGradient(colors: [difficultyColor.opacity(0.24), .clear], center: .leading, startRadius: 20, endRadius: 520)
                    RadialGradient(colors: [ArcadeTheme.cyan.opacity(0.12), .clear], center: .bottomTrailing, startRadius: 10, endRadius: 430)
                }
                .ignoresSafeArea()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            selectedTier = initialTier
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) { appeared = true }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button(action: onClose) {
                Label("Songs", systemImage: "chevron.left").font(.headline.weight(.black))
            }
            .buttonStyle(.plain)
            .foregroundStyle(ArcadeTheme.cyan)
            VStack(alignment: .leading, spacing: 2) {
                Text(contextTitle == nil ? "SONG BRIEFING" : "DAILY TASK")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(ArcadeTheme.yellow)
                Text(contextTitle ?? "Check the chart before you play")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ArcadeTheme.muted)
            }
            Spacer()
            Label("MICROPHONE SCORING", systemImage: "mic.fill")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(ArcadeTheme.green)
        }
        .padding(.horizontal, 26)
        .frame(height: 58)
        .background(Color.black.opacity(0.24))
        .overlay(alignment: .bottom) { Rectangle().fill(ArcadeTheme.cyan.opacity(0.24)).frame(height: 1) }
    }

    private var cover: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(LinearGradient(colors: [difficultyColor, ArcadeTheme.pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: chart.style == .basicStrum ? "guitars.fill" : "music.note")
                    .font(.system(size: 96, weight: .black))
                    .foregroundStyle(.white.opacity(0.3))
                VStack {
                    Spacer()
                    HStack {
                        Text(selectedTier.selectionDifficulty.rawValue.uppercased())
                            .font(.caption.monospaced().weight(.black))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.55), in: Capsule())
                        Spacer()
                    }
                    .padding(16)
                }
            }
            .frame(height: 220)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.38), lineWidth: 1.5))
            .shadow(color: difficultyColor.opacity(0.34), radius: 24, y: 10)
            .scaleEffect(appeared ? 1 : 0.92)
            .opacity(appeared ? 1 : 0)

            Text(chart.title)
                .font(.system(size: 27, weight: .black, design: .rounded))
                .lineLimit(2)
            Text("\(chart.instrument.displayName) · Full song")
                .font(.caption.weight(.bold))
                .foregroundStyle(ArcadeTheme.muted)
        }
    }

    private var briefing: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("READY CHECK")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(ArcadeTheme.yellow)

            HStack(spacing: 9) {
                metric("BPM", value: "\(Int(chart.nominalBPM.rounded()))", symbol: "metronome")
                metric("DIFFICULTY", value: chart.difficulty.rawValue.uppercased(), symbol: "gauge.with.dots.needle.50percent")
                metric("LENGTH", value: formattedDuration, symbol: "clock.fill")
                metric("TYPE", value: chart.style == .basicStrum ? "CHORDS" : "NOTES", symbol: "music.note")
            }

            if !locksTier, let experience = chart.experience {
                VStack(alignment: .leading, spacing: 7) {
                    Text("PLAY MODE").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(ArcadeTheme.muted)
                    HStack(spacing: 8) {
                        ForEach(experience.availableTiers) { tier in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) { selectedTier = tier }
                            } label: {
                                VStack(spacing: 1) {
                                    Text(tier.title.uppercased()).font(.caption.weight(.black))
                                    Text("+\(tier.playXP) XP").font(.system(size: 8, weight: .black, design: .monospaced))
                                }
                                .frame(maxWidth: .infinity, minHeight: 42)
                                .foregroundStyle(selectedTier == tier ? ArcadeTheme.background : ArcadeTheme.muted)
                                .background(selectedTier == tier ? ArcadeTheme.cyan : ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                Label("\(selectedTier.title.uppercased()) MODE", systemImage: "lock.fill")
                    .font(.caption.monospaced().weight(.black))
                    .foregroundStyle(ArcadeTheme.cyan)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("CHORDS YOU WILL PLAY")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(ArcadeTheme.muted)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(chordNames, id: \.self) { chord in
                            Text(chord)
                                .font(.headline.monospaced().weight(.black))
                                .padding(.horizontal, 13)
                                .frame(height: 38)
                                .background(ArcadeTheme.cyan.opacity(0.13), in: RoundedRectangle(cornerRadius: 9))
                                .overlay(RoundedRectangle(cornerRadius: 9).stroke(ArcadeTheme.cyan.opacity(0.35)))
                        }
                    }
                }
            }

            Spacer(minLength: 0)
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("The chart starts after you tap play.").font(.caption.weight(.bold))
                    Text("Strum when each blue chord reaches the hit box.")
                        .font(.caption2)
                        .foregroundStyle(ArcadeTheme.muted)
                }
                Spacer()
                Button { onPlay(selectedTier) } label: {
                    Label(contextTitle == nil ? "PLAY SONG" : "START TASK", systemImage: "play.fill")
                        .font(.headline.weight(.black))
                        .padding(.horizontal, 26)
                        .frame(minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(ArcadeTheme.yellow)
                .foregroundStyle(ArcadeTheme.background)
                .disabled(!canPlay)
            }
        }
        .padding(18)
        .background(ArcadeTheme.panel.opacity(0.72), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.08)))
        .offset(x: appeared ? 0 : 32)
        .opacity(appeared ? 1 : 0)
    }

    private func metric(_ title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol).foregroundStyle(ArcadeTheme.cyan)
            Text(value).font(.system(size: 15, weight: .black, design: .rounded)).lineLimit(1).minimumScaleFactor(0.65)
            Text(title).font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(ArcadeTheme.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .padding(.horizontal, 11)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 11))
    }

    private var formattedDuration: String {
        String(format: "%d:%02d", Int(chart.audioDurationSeconds) / 60, Int(chart.audioDurationSeconds) % 60)
    }

    private var difficultyColor: Color {
        switch chart.difficulty {
        case .easy: ArcadeTheme.green
        case .medium: ArcadeTheme.cyan
        case .hard: ArcadeTheme.pink
        }
    }
}
