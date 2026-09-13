import SwiftUI
import UIKit

struct TutorialView: View {
    let instrument: Instrument
    @ObservedObject var microphone: Microphone
    let onStepComplete: (Int) -> Void
    let onComplete: () -> Void
    let onBack: () -> Void

    @State private var stepIndex: Int
    @State private var isArmed = false
    @State private var countIn = 0
    @State private var feedback = "Tap Play along, then follow the cue."
    @State private var judge = LessonJudge()

    init(instrument: Instrument, microphone: Microphone, initialStep: Int, onStepComplete: @escaping (Int) -> Void, onComplete: @escaping () -> Void, onBack: @escaping () -> Void) {
        self.instrument = instrument
        self.microphone = microphone
        self.onStepComplete = onStepComplete
        self.onComplete = onComplete
        self.onBack = onBack
        _stepIndex = State(initialValue: min(max(initialStep, 0), 2))
    }

    private var target: LessonTarget { instrument.lesson[stepIndex] }

    var body: some View {
        StageShell(step: "05 / Tutorial · \(stepIndex + 1)/3", title: target.title, subtitle: target.instruction) {
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Capsule()
                        .fill(index <= stepIndex ? ArcadeTheme.cyan : ArcadeTheme.panel)
                        .frame(height: 7)
                }
            }
            Text(target.kind == .chord ? "Approximate sound match only — the microphone cannot see your finger placement." : "Listen for the note, then try it on your instrument.")
                .font(.subheadline)
                .foregroundStyle(ArcadeTheme.muted)
            Button("Back to tuning", action: onBack)
                .foregroundStyle(ArcadeTheme.muted)
        } trailing: {
            StagePanel {
                VStack(spacing: 13) {
                    NeonNote(symbol: target.kind == .chord ? "music.note.list" : "music.note", label: target.kind == .chord ? "\(target.stringLabel) · CHORD" : "\(target.stringLabel) STRING · FRET \(target.fret ?? 0)", color: target.kind == .chord ? ArcadeTheme.pink : ArcadeTheme.cyan)
                    Text(countIn > 0 ? "\(countIn)" : feedback)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(countIn > 0 ? ArcadeTheme.yellow : .white)
                        .multilineTextAlignment(.center)
                        .frame(minHeight: 34)
                    StageButton(title: isArmed ? "Restart count-in" : "Play along", symbol: "play.fill") { startCountIn() }
                    microphoneStatus
                }
            }
        }
        .onReceive(microphone.$latestSamples) { samples in
            guard microphone.state == .listening, !samples.isEmpty else { return }
            if countIn > 0 {
                judge.observe(samples)
                return
            }
            guard isArmed else { return }
            if judge.matches(samples, sampleRate: microphone.sampleRate, target: target) {
                isArmed = false
                feedback = target.kind == .chord ? "Sound match! Nice strum." : "Note matched! Nice work."
                if stepIndex == 2 {
                    onComplete()
                } else {
                    stepIndex += 1
                    onStepComplete(stepIndex)
                    judge.reset()
                    feedback = "Great! Tap Play along for the next step."
                }
            } else if samples.contains(where: { abs($0) > 0.08 }) {
                feedback = target.kind == .chord ? "Keep trying — play the chord together." : "Try that string and fret again."
            }
        }
    }

    private func startCountIn() {
        judge.reset()
        isArmed = false
        countIn = 3
        feedback = "Get ready…"
        Task {
            if microphone.state != .listening { await microphone.start() }
            guard microphone.state == .listening else { return }
            for remaining in stride(from: 2, through: 0, by: -1) {
                try? await Task.sleep(for: .milliseconds(550))
                countIn = remaining
            }
            feedback = "Play now!"
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
