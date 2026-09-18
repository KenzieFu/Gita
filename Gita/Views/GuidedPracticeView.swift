import AVFoundation
import Combine
import SwiftUI

struct GuidedPracticeView: View {
    let chart: SongChart
    let section: SongSection
    let audioURL: URL
    let tier: ArrangementTier
    let contextTitle: String?
    @ObservedObject var microphone: Microphone
    let onTake: (PracticeTake, URL) -> Void
    let onClose: () -> Void

    @State private var flow = LearningFlow(stage: .play, rate: 1)
    @State private var player: GuidedSongPlayer?
    @State private var position = 0.0
    @State private var isPlaying = false
    @State private var isScored = false
    @State private var session: PracticeSession?
    @State private var recorder: PracticeAudioRecorder?
    @State private var previousRMS = 0.0
    @State private var feedbackGrade: PracticeGrade?
    @State private var feedbackSequence = 0
    @State private var message = "Loading full song…"
    @State private var songFinished = false
    @State private var showReadyPopup = true
    @State private var usesSpeakerEchoCancellation = false
    @State private var consumedCueOnsets: Set<Double> = []
    @State private var judgedCueGrades: [Double: PracticeGrade] = [:]
    @State private var hitSoundPlayer: AVAudioPlayer?
    private let timer = Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()
    private var performance: RhythmPerformance { RhythmPerformance(session: session) }

    var body: some View {
        GeometryReader { geometry in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 16) {
                        Button { stopAndClose() } label: { Label("Back", systemImage: "chevron.left") }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(chart.title).font(.headline).lineLimit(1)
                            Text(contextTitle ?? "\(section.title) · \(tier.title) · Original speed")
                                .font(.caption2).foregroundStyle(ArcadeTheme.muted)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(performance.accuracy.map { String(format: "%.1f%%", $0 * 100) } ?? "—")
                                .font(.system(size: 27, weight: .black, design: .rounded))
                                .contentTransition(.numericText())
                            Text(isScored ? "LIVE NOTE ACCURACY" : "PRACTICE · UNSCORED")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                        }
                    }
                    .foregroundStyle(ArcadeTheme.cyan)
                    ProgressView(value: max(0, min(1, (position - section.startSeconds) / (section.endSeconds - section.startSeconds))))
                        .tint(ArcadeTheme.cyan)
                    HStack {
                        Label(isPlaying ? (contextTitle == nil ? "PLAYING SONG" : "DAILY TASK") : "READY", systemImage: isPlaying ? "waveform" : "music.note")
                            .font(.caption2.monospaced().weight(.black))
                            .foregroundStyle(ArcadeTheme.yellow)
                        Spacer()
                        Text("\(Int(chart.nominalBPM)) BPM · \(chart.stringLabels.count) STRINGS")
                            .font(.caption2.monospaced().weight(.bold)).foregroundStyle(ArcadeTheme.muted)
                    }
                    RhythmPlaySurface(chart: chart, section: section, tier: tier, position: position, rate: flow.rate,
                                      grade: feedbackGrade, feedbackSequence: feedbackSequence, combo: performance.combo,
                                      consumedCueOnsets: consumedCueOnsets, judgedCueGrades: judgedCueGrades)
                        .frame(maxHeight: .infinity)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .frame(width: geometry.size.width, height: geometry.size.height)
            .background(ArcadeTheme.background.ignoresSafeArea())
        }
        .overlay {
            if showReadyPopup {
                readyPopup
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            } else if songFinished {
                VStack(spacing: 14) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44, weight: .black))
                    Text(contextTitle == nil ? "SONG COMPLETE" : "TASK COMPLETE")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                    Text(contextTitle == nil ? "Play it again or return to song selection." : "Nice work. Your daily progress is ready.")
                        .font(.subheadline).foregroundStyle(ArcadeTheme.muted)
                    HStack {
                        Button(contextTitle == nil ? "Back to songs" : "Back to daily path", action: stopAndClose)
                        Button("Play again", action: startPart)
                            .buttonStyle(.borderedProminent).tint(ArcadeTheme.cyan)
                    }
                }
                .padding(28)
                .foregroundStyle(ArcadeTheme.cyan)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(ArcadeTheme.cyan.opacity(0.5)))
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .onAppear {
            prepareHitSound()
            let preparedPlayer = GuidedSongPlayer()
            do {
                try preparedPlayer.prepare(chart: chart, audioURL: audioURL, section: section)
                player = preparedPlayer
                position = section.startSeconds
            } catch {
                message = "This song could not be opened. Check its audio file."
            }
        }
        .onDisappear {
            player?.stop()
            hitSoundPlayer?.stop()
            recorder?.cancel()
            microphone.stop()
        }
        .onReceive(timer) { _ in
            guard let player, isPlaying else { return }
            position = player.sourceTime
            if isScored, var current = session {
                let priorCount = current.hits.count
                current.advance(to: ProcessInfo.processInfo.systemUptime)
                session = current
                if current.hits.count > priorCount {
                    let newHits = Array(current.hits[priorCount...])
                    if newHits.contains(where: { $0.grade == .miss }) {
                        registerJudgement(newHits, grade: .miss, in: current)
                    }
                }
            }
            if position >= section.endSeconds {
                player.stop()
                isPlaying = false
                if isScored, var current = session {
                    current.advance(to: ProcessInfo.processInfo.systemUptime + 0.5)
                    session = current
                    if let take = current.makeTake(playedAt: Date()) { finishTake(take) }
                }
                if !isScored {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { songFinished = true }
                }
            }
        }
        .onReceive(microphone.$latestSamples) { samples in
            guard isScored, flow.stage == .play, !samples.isEmpty, var current = session else { return }
            do {
                try recorder?.append(samples, sampleRate: microphone.sampleRate)
            } catch {
                recorder?.cancel()
                recorder = nil
                isScored = false
                message = "Audio recording stopped. This attempt will not count as a challenge day."
                return
            }
            let rms = sqrt(samples.reduce(0) { $0 + Double($1) * Double($1) } / Double(samples.count))
            let attack = rms > max(0.025, previousRMS * 1.4)
            previousRMS = rms
            guard attack else { return }
            let now = ProcessInfo.processInfo.systemUptime
            if let hits = current.observeChord(samples: samples, sampleRate: microphone.sampleRate, at: now), !hits.isEmpty {
                let grade = hits[0].grade
                registerJudgement(hits, grade: grade, in: current)
                message = "\(grade.rawValue.capitalized)! Keep the progression moving."
            } else if let pitch = PitchDetector.estimate(samples, sampleRate: microphone.sampleRate),
                      pitch.clarity >= 0.8, let hit = current.observe(frequency: pitch.frequency, at: now) {
                registerJudgement([hit], grade: hit.grade, in: current)
                message = "\(hit.grade.rawValue.capitalized)! Keep going."
            }
            session = current
        }
    }
    private func startPart() {
        guard let player else { return }
        withAnimation(.easeOut(duration: 0.2)) { showReadyPopup = false }
        songFinished = false
        player.stop()
        recorder?.cancel()
        recorder = nil
        isPlaying = false
        session = nil
        previousRMS = 0
        consumedCueOnsets = []
        judgedCueGrades = [:]
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        let hasPrivateAudioOutput = outputs.contains {
            $0.portType == .headphones ||
            $0.portType == .bluetoothA2DP ||
            $0.portType == .bluetoothHFP ||
            $0.portType == .bluetoothLE
        }
        usesSpeakerEchoCancellation = !hasPrivateAudioOutput
        isScored = flow.stage == .play
        feedbackGrade = nil
        Task { @MainActor in
            if isScored { await microphone.start(echoCancellation: usesSpeakerEchoCancellation) }
            if isScored && microphone.state != .listening {
                isScored = false
                message = "Microphone unavailable. Play along without a score."
            }
            if isScored {
                do {
                    let recordingsRoot = FileManager.default.temporaryDirectory.appendingPathComponent("GitaPracticeRecordings", isDirectory: true)
                    let freshRecorder = PracticeAudioRecorder(root: recordingsRoot)
                    try freshRecorder.start(sampleRate: microphone.sampleRate)
                    recorder = freshRecorder
                } catch {
                    isScored = false
                    message = "Recording could not start. You can still play without a score."
                }
            }
            do {
                try player.play(
                    stage: flow.stage,
                    rate: flow.rate,
                    echoCancellation: isScored && usesSpeakerEchoCancellation
                )
                position = section.startSeconds
                isPlaying = true
                if isScored, let startedAt = player.playbackStartUptime {
                    let practiceChart: PracticeChart
                    if let experience = chart.experience,
                       let arrangement = experience.arrangement(for: tier) {
                        practiceChart = chart.practiceChart(experience: experience, arrangement: arrangement)
                    } else {
                        practiceChart = chart.practiceChart()
                    }
                    var newSession = PracticeSession(chart: practiceChart, speed: flow.rate)
                    let startBeat = section.startSeconds * chart.nominalBPM / 60
                    let endBeat = min(practiceChart.totalBeats, section.endSeconds * chart.nominalBPM / 60)
                    if startBeat < endBeat {
                        newSession.setLoop(startBeat: startBeat, endBeat: endBeat, at: startedAt)
                    } else {
                        newSession.start(at: startedAt)
                    }
                    session = newSession
                    message = "Play on the yellow line."
                } else if flow.stage == .play {
                    message = "Follow the chord progression."
                }
            } catch {
                message = "Playback could not start. Try this part again."
            }
        }
    }

    private var readyPopup: some View {
        ZStack {
            Color.black.opacity(0.28).ignoresSafeArea()
            HStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(LinearGradient(colors: [difficultyColor, ArcadeTheme.pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: chart.style == .basicStrum ? "guitars.fill" : "music.note")
                        .font(.system(size: 58, weight: .black))
                        .foregroundStyle(.white.opacity(0.35))
                    VStack {
                        Spacer()
                        Text(contextTitle == nil ? "FULL SONG" : "QUICK DAILY CHECK")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.55), in: Capsule())
                            .padding(10)
                    }
                }
                .frame(width: 170, height: 116)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.38)))

                VStack(alignment: .leading, spacing: 10) {
                    Text(contextTitle ?? chart.title)
                        .font(.title2.weight(.black))
                        .lineLimit(1)
                    if contextTitle != nil {
                        Text("\(section.title) · Easy mode")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ArcadeTheme.muted)
                    }
                    HStack(spacing: 8) {
                        readyMetric("BPM", value: "\(Int(chart.nominalBPM.rounded()))", symbol: "metronome")
                        readyMetric("DIFFICULTY", value: contextTitle == nil ? chart.difficulty.rawValue.uppercased() : "EASY", symbol: "gauge.with.dots.needle.50percent")
                        readyMetric("MODE", value: tier.title.uppercased(), symbol: "music.note.list")
                    }
                    Button(action: startPart) {
                        Label(contextTitle == nil ? "START SONG" : "START QUICK CHECK", systemImage: "play.fill")
                            .font(.headline.weight(.black))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ArcadeTheme.yellow)
                    .foregroundStyle(ArcadeTheme.background)
                }
                .frame(width: 360)
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.18)))
            .shadow(color: difficultyColor.opacity(0.28), radius: 28)
        }
    }

    private func readyMetric(_ title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(ArcadeTheme.cyan)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.caption.weight(.black)).lineLimit(1)
                Text(title).font(.system(size: 6, weight: .black, design: .monospaced)).foregroundStyle(ArcadeTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
        .padding(.horizontal, 8)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
    }

    private var difficultyColor: Color {
        switch chart.difficulty {
        case .easy: ArcadeTheme.green
        case .medium: ArcadeTheme.cyan
        case .hard: ArcadeTheme.pink
        }
    }

    private func stopAndClose() {
        player?.stop()
        recorder?.cancel()
        microphone.stop()
        onClose()
    }

    private func finishTake(_ take: PracticeTake) {
        isScored = false
        isPlaying = false
        player?.stop()
        do {
            let audioURL = try recorder?.stop()
            recorder = nil
            guard let audioURL else { throw PracticeAudioRecorderError.notRecording }
            message = "Practice checked. Your recording is saved locally."
            onTake(take, audioURL)
        } catch {
            message = "The recording could not be saved. This attempt will not count."
        }
    }

    private func showFeedback(_ grade: PracticeGrade) {
        feedbackSequence += 1
        withAnimation(.spring(response: 0.24, dampingFraction: 0.56)) { feedbackGrade = grade }
        let sequence = feedbackSequence
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(720))
            guard sequence == feedbackSequence else { return }
            withAnimation(.easeOut(duration: 0.18)) { feedbackGrade = nil }
        }
    }

    private func prepareHitSound() {
        guard let url = Bundle.main.url(forResource: "normal_note", withExtension: "mp3") else { return }
        hitSoundPlayer = try? AVAudioPlayer(contentsOf: url)
        hitSoundPlayer?.volume = 0.7
        hitSoundPlayer?.prepareToPlay()
    }

    private func playHitSound(for grade: PracticeGrade) {
        guard grade != .miss else { return }
        if hitSoundPlayer == nil { prepareHitSound() }
        hitSoundPlayer?.currentTime = 0
        hitSoundPlayer?.play()
    }

    private func registerJudgement(_ hits: [PracticeHit], grade: PracticeGrade, in session: PracticeSession) {
        playHitSound(for: grade)
        let onsets = Set(hits.compactMap { hit in
            session.activeNotes.first(where: { $0.id == hit.noteID })?.beat
        }.map { $0 * 60 / chart.nominalBPM })
        guard !onsets.isEmpty else {
            showFeedback(grade)
            return
        }
        consumedCueOnsets.formUnion(onsets)
        for onset in onsets { judgedCueGrades[onset] = grade }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.easeOut(duration: 0.38)) {
                for onset in onsets { judgedCueGrades.removeValue(forKey: onset) }
            }
        }
        showFeedback(grade)
    }
}
