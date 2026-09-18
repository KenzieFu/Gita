import SwiftUI
import UIKit
import Combine

struct TutorialView: View {
    let instrument: Instrument
    let tuning: UkuleleTuning?
    @ObservedObject var microphone: Microphone
    let onStepComplete: (Int) -> Void
    let onComplete: () -> Void
    let onBack: () -> Void

    @State private var stepIndex: Int
    @State private var isArmed = false
    @State private var countIn = 0
    @State private var feedback = "Tap Play along, then follow the cue."
    @State private var judge = LessonJudge()
    @State private var feedbackGrade: PracticeGrade?
    @State private var feedbackSequence = 0
    @State private var position = 0.0
    @State private var startedAt: TimeInterval?
    @State private var consumedCueOnsets: Set<Double> = []
    @State private var judgedCueGrades: [Double: PracticeGrade] = [:]
    @State private var countInTask: Task<Void, Never>?
    private let timer = Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()

    init(instrument: Instrument, tuning: UkuleleTuning?, microphone: Microphone, initialStep: Int, onStepComplete: @escaping (Int) -> Void, onComplete: @escaping () -> Void, onBack: @escaping () -> Void) {
        self.instrument = instrument
        self.tuning = tuning
        self.microphone = microphone
        self.onStepComplete = onStepComplete
        self.onComplete = onComplete
        self.onBack = onBack
        _stepIndex = State(initialValue: min(max(initialStep, 0), 2))
    }

    private var target: LessonTarget {
        let targets = instrument.lessonTargets(tuning)
        return targets[safe: stepIndex] ?? LessonTarget(
            kind: .openString,
            title: "Ready to play",
            instruction: "Play any open string to begin.",
            stringLabel: instrument == .ukulele ? "A" : "e",
            fret: 0,
            frequencies: instrument == .ukulele ? [440] : [329.63]
        )
    }

    private var playChart: SongChart {
        TutorialPlayChart.make(for: instrument, tuning: tuning, target: target)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button(action: onBack) { Label("Tuning", systemImage: "chevron.left") }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(target.title).font(.headline.weight(.black))
                        Text("INTERACTIVE TUTORIAL · \(stepIndex + 1) / 3")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(ArcadeTheme.muted)
                    }
                    Spacer()
                    Text(feedbackGrade?.rawValue.uppercased() ?? "READY")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(judgementColor)
                        .contentTransition(.numericText())
                }
                .foregroundStyle(ArcadeTheme.cyan)

                HStack(spacing: 7) {
                    ForEach(0..<3) { index in
                        Capsule().fill(index <= stepIndex ? ArcadeTheme.cyan : ArcadeTheme.panel).frame(height: 6)
                    }
                }

                RhythmPlaySurface(
                    chart: playChart,
                    section: playChart.fullSongSection,
                    tier: .superstar,
                    position: position,
                    rate: 1,
                    grade: feedbackGrade,
                    feedbackSequence: feedbackSequence,
                    combo: consumedCueOnsets.isEmpty ? 0 : 1,
                    consumedCueOnsets: consumedCueOnsets,
                    judgedCueGrades: judgedCueGrades,
                    hintCardWidth: 116,
                    hintTitle: "CURRENT HINT"
                )
                .frame(maxHeight: .infinity)
                .overlay {
                    if countIn > 0 {
                        Text("\(countIn)")
                            .font(.system(size: 54, weight: .black, design: .rounded))
                            .foregroundStyle(ArcadeTheme.yellow)
                            .shadow(color: .black, radius: 12)
                    }
                }

                HStack {
                    Text(target.kind == .chord ? "The microphone checks the chord sound; the hint shows finger placement." : target.instruction)
                        .font(.caption)
                        .foregroundStyle(ArcadeTheme.muted)
                    Spacer()
                    Text(feedback)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(judgementColor)
                        .lineLimit(1)
                    Button(isArmed || countIn > 0 ? "Restart cue" : "Play along") { startCountIn() }
                        .buttonStyle(.borderedProminent)
                        .tint(ArcadeTheme.cyan)
                    Button("Skip tutorial", action: onComplete)
                        .foregroundStyle(ArcadeTheme.yellow)
                }
                microphoneStatus
                    .font(.caption2)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(ArcadeTheme.background.ignoresSafeArea())
        }
        .onReceive(timer) { _ in
            guard isArmed, let startedAt else { return }
            position = min(4, max(0, ProcessInfo.processInfo.systemUptime - startedAt))
        }
        .onDisappear { countInTask?.cancel() }
        .onReceive(microphone.$latestSamples) { samples in
            guard microphone.state == .listening, !samples.isEmpty else { return }
            if countIn > 0 {
                judge.observe(samples)
                return
            }
            guard isArmed else { return }
            guard position >= 3.65 else { return }
            if judge.matches(samples, sampleRate: microphone.sampleRate, target: target) {
                isArmed = false
                feedbackGrade = .perfect
                feedbackSequence += 1
                consumedCueOnsets.insert(4)
                judgedCueGrades[4] = .perfect
                feedback = target.kind == .chord ? "Sound match! Nice strum." : "Note matched! Nice work."
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(650))
                    if stepIndex == 2 {
                        onComplete()
                    } else {
                        stepIndex += 1
                        onStepComplete(stepIndex)
                        judge.reset()
                        position = 0
                        startedAt = nil
                        consumedCueOnsets = []
                        judgedCueGrades = [:]
                        feedbackGrade = nil
                        feedback = "Next cue ready. Tap Play along."
                    }
                }
            } else if samples.contains(where: { abs($0) > 0.08 }) {
                feedbackGrade = .miss
                feedbackSequence += 1
                feedback = target.kind == .chord ? "Keep trying — play the chord together." : "Try that string and fret again."
            }
        }
    }

    private var judgementColor: Color {
        switch feedbackGrade {
        case .perfect: ArcadeTheme.yellow
        case .great: .purple
        case .good: .green
        case .miss: .red
        case nil: ArcadeTheme.cyan
        }
    }

    private func startCountIn() {
        countInTask?.cancel()
        judge.reset()
        isArmed = false
        countIn = 3
        feedbackGrade = nil
        position = 0
        startedAt = nil
        consumedCueOnsets = []
        judgedCueGrades = [:]
        feedback = "Get ready…"
        countInTask = Task { @MainActor in
            if microphone.state != .listening { await microphone.start() }
            guard microphone.state == .listening else { return }
            for remaining in stride(from: 2, through: 0, by: -1) {
                try? await Task.sleep(for: .milliseconds(550))
                guard !Task.isCancelled else { return }
                countIn = remaining
            }
            feedback = "Play now!"
            startedAt = ProcessInfo.processInfo.systemUptime
            isArmed = true
        }
    }

    @ViewBuilder private var microphoneStatus: some View {
        switch microphone.state {
        case .listening:
            Label("Listening on this device", systemImage: "mic.fill").foregroundStyle(ArcadeTheme.cyan)
        case .denied:
            VStack {
                Text("Enable microphone access in Settings to play along.")
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .foregroundStyle(ArcadeTheme.cyan)
            }
        case .interrupted, .failed:
            StageButton(title: "Retry microphone", symbol: "arrow.clockwise", secondary: true) { Task { await microphone.start() } }
        case .idle, .requestingPermission:
            Text("Starting microphone…").foregroundStyle(ArcadeTheme.muted)
        }
    }
}
