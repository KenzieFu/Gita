import AVFoundation
import Foundation

@MainActor
final class GuidedSongPlayer {
    private let engine = AVAudioEngine()
    private let songNode = AVAudioPlayerNode()
    private let guideNode = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()
    private var file: AVAudioFile?
    private var chart: SongChart?
    private var section: SongSection?
    private var startedAt: Double?
    private var playingRate = 1.0
    private var observers: [NSObjectProtocol] = []

    var sourceTime: TimeInterval {
        guard let section, let startedAt else { return section?.startSeconds ?? 0 }
        let elapsed = max(0, ProcessInfo.processInfo.systemUptime - startedAt)
        return min(section.endSeconds, section.startSeconds + elapsed * playingRate)
    }

    var playbackStartUptime: Double? { startedAt }

    init() {
        engine.attach(songNode)
        engine.attach(timePitch)
        engine.attach(guideNode)
        timePitch.pitch = 0

        let interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let rawValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: rawValue) == .began else { return }
            Task { @MainActor [weak self] in self?.stop() }
        }
        observers.append(interruptionObserver)

        let routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let rawValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: rawValue),
                  reason == .oldDeviceUnavailable || reason == .noSuitableRouteForCategory else { return }
            Task { @MainActor [weak self] in self?.stop() }
        }
        observers.append(routeObserver)
    }

    func prepare(chart: SongChart, audioURL: URL, section: SongSection) throws {
        try chart.validate()
        guard section.startSeconds >= 0,
              section.startSeconds < section.endSeconds,
              section.endSeconds <= chart.audioDurationSeconds else {
            throw SongChartError.invalid("Invalid playback range")
        }
        stop()
        let source = try AVAudioFile(forReading: audioURL)
        guard Double(source.length) / source.processingFormat.sampleRate >= section.endSeconds - 0.05 else {
            throw SongChartError.invalid("Audio is shorter than the selected section")
        }
        engine.disconnectNodeOutput(songNode)
        engine.disconnectNodeOutput(timePitch)
        engine.disconnectNodeOutput(guideNode)
        engine.connect(songNode, to: timePitch, format: source.processingFormat)
        engine.connect(timePitch, to: engine.mainMixerNode, format: nil)
        let guideFormat = AVAudioFormat(standardFormatWithSampleRate: source.processingFormat.sampleRate, channels: 1)!
        engine.connect(guideNode, to: engine.mainMixerNode, format: guideFormat)
        self.file = source
        self.chart = chart
        self.section = section
        engine.prepare()
    }

    func play(stage: LearningStage, rate: Double, echoCancellation: Bool = false) throws {
        guard let file, let chart, let section, rate.isFinite, (0.5...1).contains(rate) else {
            throw SongChartError.invalid("Song playback is not ready")
        }
        stopNodes()
        try AVAudioSession.sharedInstance().setCategory(
            .playAndRecord,
            mode: echoCancellation ? .voiceChat : .measurement,
            options: [.defaultToSpeaker]
        )
        try AVAudioSession.sharedInstance().setActive(true)
        timePitch.rate = Float(rate)
        songNode.volume = stage == .hear ? 0 : (stage == .learn ? 0.25 : 1)
        guideNode.volume = stage == .play ? 0.2 : 1

        let sampleRate = file.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition((section.startSeconds * sampleRate).rounded())
        let frameCount = AVAudioFrameCount(((section.endSeconds - section.startSeconds) * sampleRate).rounded())
        file.framePosition = startFrame
        songNode.scheduleSegment(file, startingFrame: startFrame, frameCount: frameCount, at: nil)
        let guide = makeGuideBuffer(chart: chart, section: section, rate: rate, sampleRate: sampleRate, includeNotes: stage != .play)
        guideNode.scheduleBuffer(guide, at: nil)

        if !engine.isRunning { try engine.start() }
        let delay = 0.12
        let startHostTime = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: delay)
        let startTime = AVAudioTime(hostTime: startHostTime)
        songNode.play(at: startTime)
        guideNode.play(at: startTime)
        playingRate = rate
        startedAt = ProcessInfo.processInfo.systemUptime + delay
    }

    func stop() {
        stopNodes()
        if engine.isRunning { engine.stop() }
        startedAt = nil
    }

    private func stopNodes() {
        songNode.stop()
        guideNode.stop()
    }

    private func makeGuideBuffer(chart: SongChart, section: SongSection, rate: Double, sampleRate: Double, includeNotes: Bool) -> AVAudioPCMBuffer {
        let duration = (section.endSeconds - section.startSeconds) / rate
        let frameCount = AVAudioFrameCount(ceil(duration * sampleRate))
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let channel = buffer.floatChannelData![0]
        for index in 0..<Int(frameCount) { channel[index] = 0 }
        let timeline = SongPlaybackTimeline(sourceStart: section.startSeconds, rate: rate)

        if includeNotes {
            for note in chart.notes where note.onsetSeconds >= section.startSeconds && note.onsetSeconds < section.endSeconds {
                let frequency = chart.openFrequencies[note.stringIndex] * pow(2, Double(note.fret) / 12)
                let tone = GuideToneRenderer.render(frequency: frequency, duration: min(0.3, note.durationSeconds / rate), sampleRate: sampleRate)
                mix(tone, at: timeline.elapsed(forSourceSeconds: note.onsetSeconds), into: channel, count: Int(frameCount), sampleRate: sampleRate, gain: 0.5)
            }
        }
        let schedule = GuideEventSchedule(chart: chart, section: section, rate: rate)
        let click = GuideToneRenderer.render(frequency: 880, duration: 0.035, sampleRate: sampleRate)
        for onset in schedule.beatOnsets {
            mix(click, at: onset, into: channel, count: Int(frameCount), sampleRate: sampleRate, gain: 0.25)
        }
        return buffer
    }

    private func mix(_ samples: [Float], at time: Double, into channel: UnsafeMutablePointer<Float>, count: Int, sampleRate: Double, gain: Float) {
        let start = Int((time * sampleRate).rounded())
        guard start >= 0 && start < count else { return }
        for index in 0..<min(samples.count, count - start) {
            channel[start + index] = max(-1, min(1, channel[start + index] + samples[index] * gain))
        }
    }

    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }
}
