import Combine
import SwiftUI
import UIKit

struct PracticeView: View {
    let chart: PracticeChart
    @ObservedObject var microphone: Microphone
    let onClose: () -> Void
    let onSave: (PracticeTake) -> Void

    @State private var session: PracticeSession
    @State private var clock = ProcessInfo.processInfo.systemUptime
    @State private var speed = 1.0
    @State private var firstBarOnly = false
    @State private var autoRepeat = true
    @State private var isPlaying = false
    @State private var countIn = 0
    @State private var feedback = "Choose a speed, then play along."
    @State private var previousRMS = 0.0
    @State private var latestTake: PracticeTake?
    @State private var countInTask: Task<Void, Never>?

    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    init(chart: PracticeChart, microphone: Microphone, onClose: @escaping () -> Void, onSave: @escaping (PracticeTake) -> Void) {
        self.chart = chart
        self.microphone = microphone
        self.onClose = onClose
        self.onSave = onSave
        _session = State(initialValue: PracticeSession(chart: chart, speed: 1))
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Button(action: onClose) {
                            Label("Back", systemImage: "chevron.left")
                                .font(.headline)
                        }
                        Spacer()
                        Text("GITA · PRACTICE")
                            .font(.caption.monospaced().weight(.black))
                            .tracking(3)
                            .foregroundStyle(ArcadeTheme.yellow)
                    }
                    .foregroundStyle(ArcadeTheme.cyan)

                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(chart.title)
                                .font(.system(size: 29, weight: .black, design: .rounded))
                            Text("Original starter riff · \(chart.stringLabels.count) strings · \(Int(chart.bpm * speed)) BPM")
                                .font(.subheadline)
                                .foregroundStyle(ArcadeTheme.muted)
                        }
                        Spacer()
                        Text(firstBarOnly ? "LOOP · BAR 1" : "FULL RIFF")
                            .font(.caption.monospaced().weight(.bold))
                            .foregroundStyle(ArcadeTheme.yellow)
                    }

                    noteHighway
                        .frame(height: CGFloat(chart.stringLabels.count) * 39 + 10)

                    HStack(spacing: 8) {
                        Button(isPlaying || countIn > 0 ? "Restart" : "Play") { startCountIn() }
                            .buttonStyle(PracticeControlStyle(primary: true))
                        Button(firstBarOnly ? "Whole riff" : "Loop first bar") {
                            firstBarOnly.toggle()
                            startCountIn()
                        }
                        .buttonStyle(PracticeControlStyle())
                        Button("− Speed") { changeSpeed(by: -0.25) }
                            .buttonStyle(PracticeControlStyle())
                        Button("+ Speed") { changeSpeed(by: 0.25) }
                            .buttonStyle(PracticeControlStyle())
                        Button(autoRepeat ? "Auto repeat on" : "Auto repeat off") { autoRepeat.toggle() }
                            .buttonStyle(PracticeControlStyle())
                    }

                    HStack(spacing: 12) {
                        Text(countIn > 0 ? "Get ready: \(countIn)" : feedback)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(countIn > 0 ? ArcadeTheme.yellow : ArcadeTheme.cyan)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let latestTake {
                            Text("\(Int((latestTake.accuracy * 100).rounded()))% notes")
                                .font(.caption.monospaced().weight(.bold))
                                .foregroundStyle(ArcadeTheme.green)
                            Button("Save take") { onSave(latestTake) }
                                .buttonStyle(PracticeControlStyle(primary: true))
                        }
                    }
                    Text("Provisional practice timing · the microphone checks sound, not exact finger placement.")
                        .font(.caption)
                        .foregroundStyle(ArcadeTheme.muted)
                    microphoneStatus
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
            .background(ArcadeTheme.background.ignoresSafeArea())
        }
        .onAppear { Task { await microphone.start() } }
        .onDisappear {
            countInTask?.cancel()
            microphone.stop()
        }
        .onReceive(timer) { _ in
            clock = ProcessInfo.processInfo.systemUptime
            guard isPlaying else { return }
            session.advance(to: clock)
            if session.isComplete {
                isPlaying = false
                latestTake = session.makeTake(playedAt: Date())
                feedback = "Run complete. Save this take or try again."
                if autoRepeat {
                    countInTask?.cancel()
                    countInTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(650))
                        guard !Task.isCancelled else { return }
                        startCountIn()
                    }
                }
            }
        }
        .onReceive(microphone.$latestSamples) { samples in
            guard !samples.isEmpty else { return }
            let rms = sqrt(samples.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(samples.count))
            let attack = rms > max(0.025, previousRMS * 1.4)
            previousRMS = rms
            guard isPlaying, attack, microphone.state == .listening else { return }
            let now = ProcessInfo.processInfo.systemUptime
            if let chordHits = session.observeChord(samples: samples, sampleRate: microphone.sampleRate, at: now), !chordHits.isEmpty {
                feedback = "Strum heard — lenient chord pitch check."
            } else if let pitch = PitchDetector.estimate(samples, sampleRate: microphone.sampleRate),
                      pitch.clarity >= 0.80,
                      let hit = session.observe(frequency: pitch.frequency, at: now) {
                feedback = hit.grade == .perfect ? "Nice note!" : "Good — keep the beat."
            }
        }
    }

    private var noteHighway: some View {
        GeometryReader { geometry in
            let laneHeight: CGFloat = 39
            let hitX: CGFloat = 74
            let pixelsPerBeat: CGFloat = 92
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(ArcadeTheme.panel)
                ForEach(chart.stringLabels.indices, id: \.self) { lane in
                    let centerY = CGFloat(lane) * laneHeight + laneHeight / 2 + 5
                    Rectangle()
                        .fill(ArcadeTheme.cyan.opacity(0.24))
                        .frame(height: 1)
                        .position(x: geometry.size.width / 2, y: centerY)
                    Text(chart.stringLabels[lane])
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(ArcadeTheme.cyan)
                        .position(x: 22, y: centerY)
                }
                Rectangle()
                    .fill(ArcadeTheme.yellow)
                    .frame(width: 3, height: CGFloat(chart.stringLabels.count) * laneHeight)
                    .position(x: hitX, y: CGFloat(chart.stringLabels.count) * laneHeight / 2 + 5)
                ForEach(session.activeNotes) { note in
                    let x = hitX + CGFloat(note.beat - session.currentBeat(at: clock)) * pixelsPerBeat
                    if x >= hitX - 24 && x <= geometry.size.width + 24 {
                        Text("\(note.fret)")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(ArcadeTheme.background)
                            .frame(width: 34, height: 29)
                            .background(noteColor(note), in: RoundedRectangle(cornerRadius: 9))
                            .position(x: x, y: CGFloat(note.stringIndex) * laneHeight + laneHeight / 2 + 5)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .accessibilityLabel("\(chart.stringLabels.count) string note highway. Current beat \(Int(session.currentBeat(at: clock)) + 1).")
    }

    private func noteColor(_ note: PracticeNote) -> Color {
        switch session.hits.first(where: { $0.noteID == note.id })?.grade {
        case .perfect: ArcadeTheme.green
        case .great: ArcadeTheme.cyan
        case .good: ArcadeTheme.yellow
        case .miss: ArcadeTheme.pink
        case nil: ArcadeTheme.cyan
        }
    }

    private func changeSpeed(by adjustment: Double) {
        speed = min(1.5, max(0.5, speed + adjustment))
        startCountIn()
    }

    private func startCountIn() {
        countInTask?.cancel()
        isPlaying = false
        previousRMS = 0
        session = PracticeSession(chart: chart, speed: speed)
        if firstBarOnly {
            session.setLoop(startBeat: 0, endBeat: Double(chart.beatsPerBar), at: 0)
        }
        countIn = 3
        countInTask = Task { @MainActor in
            if microphone.state != .listening { await microphone.start() }
            guard microphone.state == .listening else {
                feedback = "Allow the microphone to score your playing."
                countIn = 0
                return
            }
            for remaining in stride(from: 2, through: 0, by: -1) {
                try? await Task.sleep(for: .seconds(session.secondsPerBeat))
                guard !Task.isCancelled else { return }
                countIn = remaining
            }
            clock = ProcessInfo.processInfo.systemUptime
            session.start(at: clock)
            isPlaying = true
            feedback = "Play on the yellow line!"
        }
    }

    @ViewBuilder private var microphoneStatus: some View {
        switch microphone.state {
        case .listening: Label("Microphone listening", systemImage: "mic.fill").foregroundStyle(ArcadeTheme.cyan)
        case .denied:
            Button("Enable microphone in Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .foregroundStyle(ArcadeTheme.yellow)
        case .failed(let message): Text(message).foregroundStyle(ArcadeTheme.pink)
        case .interrupted: Button("Retry microphone") { Task { await microphone.start() } }
        case .idle, .requestingPermission: Text("Starting microphone…").foregroundStyle(ArcadeTheme.muted)
        }
    }
}

private struct PracticeControlStyle: ButtonStyle {
    var primary = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.bold))
            .foregroundStyle(primary ? ArcadeTheme.background : ArcadeTheme.cyan)
            .padding(.horizontal, 11)
            .frame(minHeight: 38)
            .background(primary ? ArcadeTheme.cyan : ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 10))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
