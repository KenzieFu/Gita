import SwiftUI
import UIKit

struct TunerView: View {
    let instrument: Instrument
    @ObservedObject var microphone: Microphone
    let onProgress: (Set<Int>) -> Void
    let onComplete: () -> Void
    let onBack: () -> Void

    @State private var completed: Set<Int>
    @State private var feedback: AutoTuningFeedback?
    @State private var autoTuner = AutoTuner()

    init(instrument: Instrument, microphone: Microphone, completed: Set<Int>, onProgress: @escaping (Set<Int>) -> Void, onComplete: @escaping () -> Void, onBack: @escaping () -> Void) {
        self.instrument = instrument
        self.microphone = microphone
        self.onProgress = onProgress
        self.onComplete = onComplete
        self.onBack = onBack
        _completed = State(initialValue: completed)
    }

    private var activeIndex: Int? { feedback?.stringIndex }
    private var cents: Double? { feedback?.cents }
    private var zone: TuningZone { TuningZone.classify(cents) }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 14) {
                    HStack {
                        Label("GITA", systemImage: "waveform.path")
                            .font(.headline.weight(.black))
                            .tracking(3)
                            .foregroundStyle(.white)
                        Spacer()
                        Text("TUNE · \(completed.count)/\(instrument.openStrings.count)")
                            .font(.caption.monospaced().weight(.bold))
                            .foregroundStyle(ArcadeTheme.yellow)
                    }
                    HStack(alignment: .top, spacing: 22) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Tune up.")
                                .font(.system(size: 34, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Pluck one string with no frets pressed. Gita finds the note.")
                                .font(.subheadline)
                                .foregroundStyle(ArcadeTheme.muted)
                            TuningHeadstock(instrument: instrument, highlighted: activeIndex, completed: completed)
                            HStack {
                                Text("No buttons — just play")
                                    .font(.caption)
                                    .foregroundStyle(ArcadeTheme.muted)
                                Spacer()
                                Button("Change instrument", action: onBack)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(ArcadeTheme.cyan)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        StagePanel {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(activeIndex.map { "LIKELY OPEN STRING \($0 + 1)" } ?? "LISTENING FOR A STRING")
                                    .font(.caption.monospaced().weight(.bold))
                                    .foregroundStyle(ArcadeTheme.yellow)
                                Text(activeIndex.map { instrument.openStrings[$0].label } ?? "—")
                                    .font(.system(size: 52, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                tuningMeter
                                Text(direction)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(zone == .inTune ? ArcadeTheme.cyan : (zone == .flat || zone == .sharp ? ArcadeTheme.pink : ArcadeTheme.yellow))
                                microphoneStatus
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
            .background(ArcadeTheme.background.ignoresSafeArea())
        }
        .onReceive(microphone.$latestSamples) { samples in
            guard !samples.isEmpty, microphone.state == .listening else { return }
            let newReading = PitchDetector.estimate(samples, sampleRate: microphone.sampleRate)
            let result = autoTuner.ingest(newReading, targets: instrument.openStrings, at: ProcessInfo.processInfo.systemUptime)
            withAnimation(.easeOut(duration: 0.16)) { feedback = result }
            if let tunedIndex = result.newlyTunedIndex, !completed.contains(tunedIndex) {
                completed.insert(tunedIndex)
                onProgress(completed)
                if completed.count == instrument.openStrings.count {
                    onComplete()
                }
            }
        }
    }

    private var direction: String {
        switch zone {
        case .waiting: "Pluck an open string"
        case .flat: "Too low — tighten a little"
        case .closeFlat: "Close — tighten a little"
        case .inTune: "In tune — hold it steady"
        case .closeSharp: "Close — loosen a little"
        case .sharp: "Too high — loosen a little"
        }
    }

    private var tuningMeter: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(ArcadeTheme.background)
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ArcadeTheme.yellow.opacity(0.14))
                        .frame(width: (geometry.size.width - 44) * CGFloat(TuningZone.closeCents / 60), height: 66)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ArcadeTheme.cyan.opacity(0.15))
                        .frame(width: (geometry.size.width - 44) * CGFloat(TuningZone.inTuneCents / 60), height: 66)
                    ForEach(0..<13) { mark in
                        Rectangle()
                            .fill(.white.opacity(mark == 6 ? 0.5 : 0.12))
                            .frame(width: mark == 6 ? 2 : 1, height: mark == 6 ? 66 : 38)
                            .offset(x: (CGFloat(mark) / 12 - 0.5) * (geometry.size.width - 28))
                    }
                    Circle()
                        .stroke(ArcadeTheme.cyan, lineWidth: 3)
                        .frame(width: 34, height: 34)
                    if let cents {
                        Circle()
                            .fill(zone == .inTune ? ArcadeTheme.cyan : (zone == .closeFlat || zone == .closeSharp ? ArcadeTheme.yellow : ArcadeTheme.pink))
                            .frame(width: 18, height: 18)
                            .offset(x: CGFloat(max(-60, min(60, cents)) / 60) * (geometry.size.width / 2 - 22))
                    }
                }
            }
            .frame(height: 76)
            HStack { Text("♭ LOW"); Spacer(); Text("CLOSE"); Spacer(); Text("IN TUNE"); Spacer(); Text("CLOSE"); Spacer(); Text("HIGH ♯") }
                .font(.caption2.monospaced().weight(.bold))
                .foregroundStyle(ArcadeTheme.muted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(direction)
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

private struct TuningHeadstock: View {
    let instrument: Instrument
    let highlighted: Int?
    let completed: Set<Int>

    private var leftStrings: [Int] { instrument == .ukulele ? [1, 0] : [2, 1, 0] }
    private var rightStrings: [Int] { instrument == .ukulele ? [2, 3] : [3, 4, 5] }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 12) {
                ForEach(leftStrings, id: \.self) { badge(for: $0) }
            }
            headstock
            VStack(spacing: 12) {
                ForEach(rightStrings, id: \.self) { badge(for: $0) }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func badge(for index: Int) -> some View {
        let isActive = highlighted == index
        let isComplete = completed.contains(index)
        return VStack(spacing: 2) {
            Text(instrument.openStrings[index].label)
                .font(.title2.weight(.black))
            Text(isComplete ? "✓" : "\(index + 1)")
                .font(.caption.monospaced().weight(.bold))
        }
        .frame(width: 58, height: 50)
        .foregroundStyle(isActive ? ArcadeTheme.background : (isComplete ? ArcadeTheme.cyan : .white))
        .background(isActive ? ArcadeTheme.cyan : ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(ArcadeTheme.cyan.opacity(isActive || isComplete ? 1 : 0.35), lineWidth: 2))
        .accessibilityLabel("String \(index + 1), \(instrument.openStrings[index].label), \(isActive ? "detected" : isComplete ? "tuned" : "not tuned")")
    }

    private var headstock: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(LinearGradient(colors: [Color(red: 0.54, green: 0.27, blue: 0.23), Color(red: 0.27, green: 0.14, blue: 0.20)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(ArcadeTheme.yellow.opacity(0.6), lineWidth: 2))
            HStack(spacing: 16) {
                ForEach(0..<instrument.openStrings.count, id: \.self) { _ in
                    Rectangle().fill(.white.opacity(0.6)).frame(width: 1)
                }
            }
            .padding(.vertical, 18)
            VStack {
                ForEach(0..<leftStrings.count, id: \.self) { _ in
                    HStack {
                        Circle().fill(ArcadeTheme.muted).frame(width: 15, height: 15)
                        Spacer()
                        Circle().fill(ArcadeTheme.muted).frame(width: 15, height: 15)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(16)
        }
        .frame(width: 106, height: instrument == .ukulele ? 140 : 165)
        .accessibilityHidden(true)
    }
}
