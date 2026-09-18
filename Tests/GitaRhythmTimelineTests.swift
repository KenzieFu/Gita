import Foundation

@main
enum GitaRhythmTimelineTests {
    static func main() throws {
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        let chart = try SongChart.decodeValidated(Data(contentsOf: url))
        precondition(chart.fullSongSection.startSeconds == 0)
        precondition(chart.fullSongSection.endSeconds == chart.audioDurationSeconds)
        precondition(chart.fullSongSection.title == "Full Song")
        let section = chart.sections[0]
        let short = RhythmTimeline(chart: chart, tier: .superstar, section: section)
        precondition(short.events.count == 1)
        precondition(short.events[0].name == "C" && short.events[0].onset == 4)
        precondition(short.events[0].frets == [0, 0, 0, 3])
        var full = section
        full.endSeconds = chart.audioDurationSeconds
        let timeline = RhythmTimeline(chart: chart, tier: .superstar, section: full)
        precondition(timeline.events.count == 83)
        precondition(timeline.events.contains { $0.onset == 44.51 })
        precondition(timeline.events[2].name == "Em" && timeline.events[2].onset == 9)
        precondition(timeline.targetIndex(at: 3, rate: 1) == 0)
        precondition(timeline.targetIndex(at: 4.3, rate: 1) == 0)
        precondition(timeline.targetIndex(at: 4.36, rate: 1) == 1)
        precondition(timeline.targetIndex(at: 4.2, rate: 0.5) == 1)
        precondition(timeline.targetIndex(at: chart.audioDurationSeconds, rate: 1) == nil)
        precondition(RhythmTimeline.approach(onset: 44.51, position: 44.51, rate: 0.5) == 1)
        precondition(RhythmTimeline.approach(onset: 6, position: 4, rate: 0.5) == 0)
        precondition(RhythmPerformance(session: nil).accuracy == nil)
        var session = PracticeSession(chart: chart.practiceChart(experience: chart.experience!, arrangement: chart.experience!.arrangements[0]), speed: 1)
        session.start(at: 0)
        precondition(RhythmPerformance(session: session).accuracy == nil)
        session.advance(to: 4.4)
        precondition(RhythmPerformance(session: session).accuracy == 0)
        precondition(RhythmPerformance(session: session).combo == 0)
        session.restart(at: 0)
        let frequencies = [392.0, 261.625565, 329.627557, 523.251131]
        let samples: [Float] = (0..<8192).map { index in
            Float(frequencies.reduce(0.0) { sum, frequency in
                sum + sin(2 * Double.pi * frequency * Double(index) / 44100)
            } / Double(frequencies.count))
        }
        precondition(session.observeChord(samples: samples, sampleRate: 44100, at: 4.05)?.count == 4)
        precondition(RhythmPerformance(session: session).combo == 1, "One strum is one combo, not four")
        precondition(RhythmPerformance(session: session).accuracy == 1)
        session.advance(to: 6.4)
        precondition(RhythmPerformance(session: session).combo == 0)
        precondition(RhythmPerformance(session: session).accuracy == 0.5)
        precondition(ArrangementTier.noob.selectionDifficulty == .easy)
        precondition(ArrangementTier.guitaristWannabe.selectionDifficulty == .medium)
        precondition(ArrangementTier.superstar.selectionDifficulty == .hard)
        for tuning in [UkuleleTuning.highG, .baritone] {
            for target in tuning.lessons {
                let lesson = TutorialPlayChart.make(for: .ukulele, tuning: tuning, target: target)
                try lesson.validate()
                let events = RhythmTimeline(chart: lesson, tier: .superstar, section: lesson.fullSongSection).events
                precondition(events.count == 1 && events[0].onset == 4)
                precondition(events[0].name.contains(target.kind == .chord ? "CHORD" : "FRET"))
            }
        }
        for target in Instrument.guitar.lessonTargets(nil) {
            let lesson = TutorialPlayChart.make(for: .guitar, tuning: nil, target: target)
            try lesson.validate()
            precondition(RhythmTimeline(chart: lesson, tier: .superstar, section: lesson.fullSongSection).events.count == 1)
        }
        print("Passed: JSON cues, fractional time, section boundaries, slowed approach, hints and unscored/miss metrics")
    }
}
