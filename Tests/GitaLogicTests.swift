import Foundation

@main
struct GitaLogicTests {
    static func main() {
        precondition(Instrument.ukulele.openStrings.map(\.label) == ["G", "C", "E", "A"], "Ukulele order must match the screen")
        precondition(abs(Instrument.guitar.openStrings[0].frequency - 82.4069) < 0.02, "Low E must be E2")
        precondition(Instrument.ukulele.lesson.count == 3, "Ukulele has three guided exercises")
        precondition(Instrument.guitar.lesson.count == 3, "Guitar has three guided exercises")
        precondition(SetupProgress(instrument: nil, tutorialComplete: false).destination == .instrumentChoice)
        precondition(SetupProgress(instrument: .ukulele, tutorialComplete: false).destination == .tuning)
        precondition(SetupProgress(instrument: .ukulele, tutorialComplete: true).destination == .ready)
        let sampleRate = 44_100.0
        let a4 = tone(440, count: 8_192, sampleRate: sampleRate)
        let estimate = PitchDetector.estimate(a4, sampleRate: sampleRate)
        precondition(estimate != nil && abs(estimate!.frequency - 440) < 3, "A4 estimate must be close to 440 Hz")
        precondition(PitchDetector.estimate(Array(repeating: 0, count: 8_192), sampleRate: sampleRate) == nil, "Silence must not be a note")
        precondition(abs(PitchDetector.cents(440, target: 440)) < 0.1)
        precondition(abs(PitchDetector.cents(466.16, target: 440) - 100) < 0.5)
        let lowE = tone(82.4069, count: 8_192, sampleRate: sampleRate)
        precondition(abs((PitchDetector.estimate(lowE, sampleRate: sampleRate)?.frequency ?? 0) - 82.4069) < 2, "Low guitar E2 must be detected")
        let cChord = mixture([261.63, 329.63, 392, 523.25], count: 8_192, sampleRate: sampleRate)
        let chordPitch = PitchDetector.estimate(cChord, sampleRate: sampleRate)
        precondition(chordPitch == nil || chordPitch!.clarity < 0.84, "A multi-note strum must not count as a clear single pitch")
        precondition(ChordMatcher.matches(cChord, sampleRate: sampleRate, targets: [261.63, 329.63, 392, 523.25]), "C chord pitch content should match")
        precondition(!ChordMatcher.matches(a4, sampleRate: sampleRate, targets: [261.63, 329.63, 392, 523.25]), "A single pitch is not a C chord")
        precondition(!ChordMatcher.matches(Array(repeating: 0, count: 8_192), sampleRate: sampleRate, targets: [261.63, 329.63, 392, 523.25]), "Silence is not a chord")
        let suite = "GitaLogicTests.\(UUID().uuidString)"
        guard let isolatedDefaults = UserDefaults(suiteName: suite) else { fatalError("Unable to make isolated defaults") }
        let progressStore = ProgressStore(defaults: isolatedDefaults)
        progressStore.save(SetupProgress(instrument: .ukulele, tutorialComplete: true), for: "account-A")
        precondition(progressStore.load(for: "account-A").destination == .ready)
        precondition(progressStore.load(for: "account-B").destination == .instrumentChoice, "Progress must not cross Apple accounts")
        progressStore.saveGuest(SetupProgress(instrument: .guitar, tutorialComplete: true))
        precondition(progressStore.loadGuest().instrument == .guitar, "Guest progress stays in its own slot")
        precondition(progressStore.load(for: "account-A").instrument == .ukulele, "Guest must not replace Apple progress")
        progressStore.setGuestModeEnabled(true)
        precondition(ProgressStore(defaults: isolatedDefaults).isGuestModeEnabled, "Guest choice persists across launches")
        precondition(SetupPolicy.route(guestMode: true, userID: nil, progress: progressStore.loadGuest(), started: false) == .ready, "Returning guest resumes progress")
        progressStore.setGuestModeEnabled(false)
        precondition(!ProgressStore(defaults: isolatedDefaults).isGuestModeEnabled, "Switching to Apple leaves guest mode")
        precondition(progressStore.loadGuest().destination == .ready, "Leaving guest mode does not erase guest practice")
        isolatedDefaults.removePersistentDomain(forName: suite)
        var judge = TuningJudge()
        precondition(!judge.ingest(PitchReading(frequency: 440, clarity: 0.95), target: 440, at: 0.0))
        precondition(!judge.ingest(PitchReading(frequency: 440, clarity: 0.95), target: 440, at: 0.25))
        precondition(judge.ingest(PitchReading(frequency: 440, clarity: 0.95), target: 440, at: 0.55), "Stable half-second in tune should complete")
        judge.reset()
        precondition(!judge.ingest(PitchReading(frequency: 440, clarity: 0.95), target: 440, at: 1.0))
        precondition(!judge.ingest(nil, target: 440, at: 1.4))
        precondition(!judge.ingest(PitchReading(frequency: 466.16, clarity: 0.95), target: 440, at: 1.8), "Wrong pitch must not complete")
        precondition(SetupPolicy.route(userID: nil, progress: SetupProgress(), started: false) == .welcome)
        precondition(SetupPolicy.route(userID: nil, progress: SetupProgress(), started: true) == .signIn)
        precondition(SetupPolicy.route(userID: "account-A", progress: SetupProgress(instrument: .guitar, tutorialComplete: true), started: false) == .ready)
        precondition(SetupRoute.tuning.usesMicrophone && SetupRoute.tutorial.usesMicrophone)
        precondition(!SetupRoute.signIn.usesMicrophone && !SetupRoute.ready.usesMicrophone)
        var lessonJudge = LessonJudge()
        precondition(!lessonJudge.matches(a4, sampleRate: sampleRate, target: Instrument.guitar.lesson[0]), "A4 is not the guitar high E")
        lessonJudge.reset()
        precondition(lessonJudge.matches(tone(329.63, count: 8_192, sampleRate: sampleRate), sampleRate: sampleRate, target: Instrument.guitar.lesson[0]), "High E pluck should match")
        lessonJudge.reset()
        precondition(!lessonJudge.matches(a4, sampleRate: sampleRate, target: Instrument.ukulele.lesson[2]), "One note cannot pass a chord lesson")
        lessonJudge.reset()
        precondition(lessonJudge.matches(cChord, sampleRate: sampleRate, target: Instrument.ukulele.lesson[2]), "Chord content with an attack should pass")
        lessonJudge.reset()
        lessonJudge.observe(cChord)
        precondition(!lessonJudge.matches(cChord, sampleRate: sampleRate, target: Instrument.ukulele.lesson[2]), "A chord held before the cue is not a new strum")
        lessonJudge.observe(Array(repeating: 0, count: 8_192))
        precondition(lessonJudge.matches(cChord, sampleRate: sampleRate, target: Instrument.ukulele.lesson[2]), "A fresh strum after silence is accepted")
        print("Gita logic tests passed")
    }

    private static func tone(_ frequency: Double, count: Int, sampleRate: Double) -> [Float] {
        (0..<count).map { Float(sin(2 * Double.pi * frequency * Double($0) / sampleRate)) }
    }

    private static func mixture(_ frequencies: [Double], count: Int, sampleRate: Double) -> [Float] {
        (0..<count).map { index in
            Float(frequencies.reduce(0) { sum, frequency in
                sum + sin(2 * Double.pi * frequency * Double(index) / sampleRate)
            } / Double(frequencies.count))
        }
    }
}
