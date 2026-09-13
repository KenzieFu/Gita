import SwiftUI
import UIKit

struct TunerView: View {
    let instrument: Instrument
    @ObservedObject var microphone: Microphone
    let onProgress: (Set<Int>) -> Void
    let onComplete: () -> Void
    let onBack: () -> Void

    @State private var selectedIndex = 0
    @State private var completed: Set<Int>
    @State private var reading: PitchReading?
    @State private var judge = TuningJudge()

    init(instrument: Instrument, microphone: Microphone, completed: Set<Int>, onProgress: @escaping (Set<Int>) -> Void, onComplete: @escaping () -> Void, onBack: @escaping () -> Void) {
        self.instrument = instrument
        self.microphone = microphone
        self.onProgress = onProgress
        self.onComplete = onComplete
        self.onBack = onBack
        _completed = State(initialValue: completed)
        _selectedIndex = State(initialValue: (0..<instrument.openStrings.count).first { !completed.contains($0) } ?? 0)
    }

    private var target: StringTarget { instrument.openStrings[selectedIndex] }
    private var cents: Double? { reading.map { PitchDetector.cents($0.frequency, target: target.frequency) } }

    var body: some View {
        StageShell(step: "04 / Tune · \(completed.count)/\(instrument.openStrings.count)", title: "Tune one string.", subtitle: "Select a string, then pluck it alone. Hold a steady note to mark it in tune.") {
            HStack(spacing: 8) {
                ForEach(instrument.openStrings.indices, id: \.self) { index in
                    Button {
                        selectedIndex = index
                        judge.reset()
                        reading = nil
                    } label: {
                        VStack(spacing: 4) {
                            Text(instrument.openStrings[index].label)
                                .font(.title2.weight(.black))
                            Text(completed.contains(index) ? "✓" : "\(index + 1)")
                                .font(.caption.monospaced())
                        }
                        .frame(maxWidth: .infinity, minHeight: 68)
                        .foregroundStyle(selectedIndex == index ? ArcadeTheme.background : ArcadeTheme.cyan)
                        .background(selectedIndex == index ? ArcadeTheme.cyan : ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("String \(index + 1), \(instrument.openStrings[index].label), \(completed.contains(index) ? "tuned" : "not yet tuned")")
                }
            }
            Text("Play one string at a time. The mic hears pitch, not which string you touched; chords and noise will not finish tuning.")
                .font(.footnote)
                .foregroundStyle(ArcadeTheme.muted)
            Button("Change instrument", action: onBack)
                .foregroundStyle(ArcadeTheme.muted)
        } trailing: {
            StagePanel {
                VStack(spacing: 13) {
                    Text("STRING \(selectedIndex + 1) · \(target.label)")
                        .font(.caption.monospaced().weight(.black))
                        .foregroundStyle(ArcadeTheme.yellow)
                    Text(String(format: "%.2f Hz", target.frequency))
                        .font(.title.weight(.black).monospacedDigit())
                        .foregroundStyle(.white)
                    Text(reading.map { String(format: "Heard %.1f Hz", $0.frequency) } ?? "Pluck the string")
                        .font(.headline)
                        .foregroundStyle(ArcadeTheme.cyan)
                    tuningMeter
                    Text(direction)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(ArcadeTheme.yellow)
                    microphoneStatus
                }
            }
        }
        .onReceive(microphone.$latestSamples) { samples in
            guard !samples.isEmpty, microphone.state == .listening else { return }
            let newReading = PitchDetector.estimate(samples, sampleRate: microphone.sampleRate)
            reading = newReading
            if judge.ingest(newReading, target: target.frequency, at: ProcessInfo.processInfo.systemUptime) {
                completed.insert(selectedIndex)
                onProgress(completed)
                judge.reset()
                if completed.count == instrument.openStrings.count {
                    onComplete()
                } else if let next = (0..<instrument.openStrings.count).first(where: { !completed.contains($0) }) {
                    selectedIndex = next
                    reading = nil
                }
            }
        }
    }

    private var direction: String {
        guard let cents else { return "Waiting for a clear note" }
        if abs(cents) <= 10 { return "Hold it steady…" }
        return cents < 0 ? "Too low — tighten a little" : "Too high — loosen a little"
    }

    private var tuningMeter: some View {
        VStack(spacing: 6) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule().fill(ArcadeTheme.cyan).frame(width: 4)
                        .offset(x: geometry.size.width / 2)
                    if let cents {
                        Circle().fill(abs(cents) <= 10 ? ArcadeTheme.yellow : ArcadeTheme.pink)
                            .frame(width: 18, height: 18)
                            .offset(x: max(0, min(geometry.size.width - 18, geometry.size.width / 2 + CGFloat(cents / 50) * geometry.size.width / 2 - 9)))
                    }
                }
            }
            .frame(height: 18)
            HStack { Text("FLAT"); Spacer(); Text("IN TUNE"); Spacer(); Text("SHARP") }
                .font(.caption2.monospaced().weight(.bold))
                .foregroundStyle(ArcadeTheme.muted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cents.map { String(format: "%.0f cents %@", abs($0), $0 < 0 ? "flat" : "sharp") } ?? "Waiting for pitch")
    }

    @ViewBuilder private var microphoneStatus: some View {
        switch microphone.state {
        case .idle, .requestingPermission:
            Text("Starting microphone…").foregroundStyle(ArcadeTheme.muted)
        case .listening:
            Label("Microphone listening", systemImage: "mic.fill")
                .foregroundStyle(ArcadeTheme.cyan)
        case .denied:
            VStack(spacing: 8) {
                Text("Microphone access is off. Enable it in Settings to tune.")
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .foregroundStyle(ArcadeTheme.cyan)
            }
        case .interrupted:
            StageButton(title: "Resume listening", symbol: "mic", secondary: true) { Task { await microphone.start() } }
        case .failed(let message):
            VStack(spacing: 8) {
                Text(message)
                StageButton(title: "Try microphone again", symbol: "arrow.clockwise", secondary: true) { Task { await microphone.start() } }
            }
        }
    }
}
