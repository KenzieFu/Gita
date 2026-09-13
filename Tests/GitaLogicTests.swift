import Foundation

@main
struct GitaLogicTests {
    static func main() {
        precondition(UkuleleTuning.allCases.count == 3, "The supported four-string layouts must be explicit")
        precondition(UkuleleTuning.highG.openStrings.map(\.frequency) == [392, 261.63, 329.63, 440], "High-G targets must match open strings")
        precondition(UkuleleTuning.lowG.openStrings.map(\.frequency) == [196, 261.63, 329.63, 440], "Low-G must use G3 rather than G4")
        precondition(UkuleleTuning.baritone.openStrings.map(\.frequency) == [146.83, 196, 246.94, 329.63], "Baritone must use DGBE")
        precondition(Instrument.ukulele.tuningTargets(nil).isEmpty, "Unknown ukulele tuning must not assume high-G")
        precondition(Instrument.guitar.tuningTargets(nil).count == 6, "Guitar targets must remain available")
        precondition(UkuleleTuning.lowG.lessons[2].frequencies.contains(196), "Low-G chord lesson must expect G3")
        precondition(UkuleleTuning.baritone.lessons[2].frequencies == [146.83, 196, 246.94, 392], "Baritone G chord target must match its strings")
        precondition(Instrument.ukulele.openStrings.map(\.label) == ["G", "C", "E", "A"], "Ukulele order must match the screen")
        precondition(abs(Instrument.guitar.openStrings[0].frequency - 82.4069) < 0.02, "Low E must be E2")
        precondition(Instrument.ukulele.lesson.count == 3, "Ukulele has three guided exercises")
        precondition(Instrument.guitar.lesson.count == 3, "Guitar has three guided exercises")
        precondition(SetupProgress(instrument: nil, tutorialComplete: false).destination == .instrumentChoice)
        precondition(SetupProgress(instrument: .ukulele, tutorialComplete: false).destination == .tuning)
        precondition(SetupProgress(instrument: .ukulele, tutorialComplete: true).destination == .ready)
        let sampleRate = 44_100.0
        precondition(PitchDetector.gOctaveEvidence(tone(392, count: 8_192, sampleRate: sampleRate), sampleRate: sampleRate, estimatedFrequency: 392) == .high, "Pure high G must not be classified as low G")
        precondition(PitchDetector.gOctaveEvidence(harmonicTone(196, lowAmplitude: 0.35, highAmplitude: 1, count: 8_192, sampleRate: sampleRate), sampleRate: sampleRate, estimatedFrequency: 392) == .low, "Low G with a loud octave harmonic must retain its fundamental")
        precondition(PitchDetector.gOctaveEvidence(harmonicTone(196, lowAmplitude: 0.15, highAmplitude: 1, count: 8_192, sampleRate: sampleRate), sampleRate: sampleRate, estimatedFrequency: 392) == .uncertain, "Weak fundamental must remain ambiguous")
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
        precondition(TuningZone.classify(nil) == .waiting, "Silence must not show a tuning direction")
        precondition(TuningZone.classify(8) == .inTune, "A small offset should be in tune")
        precondition(TuningZone.classify(-18) == .closeFlat, "A near-flat note should show close, not too low")
        precondition(TuningZone.classify(15) == .closeSharp, "A near-sharp note should show close, not too high")
        precondition(TuningZone.classify(25) == .sharp, "A larger offset should remain too high")
        judge.reset()
        precondition(!judge.ingest(PitchReading(frequency: 443.8, clarity: 0.95), target: 440, at: 2.0))
        precondition(!judge.ingest(PitchReading(frequency: 443.8, clarity: 0.95), target: 440, at: 2.6), "A close note must not auto-complete outside the true in-tune window")
        precondition(SetupPolicy.route(userID: nil, progress: SetupProgress(), started: false) == .welcome)
        precondition(SetupPolicy.route(userID: nil, progress: SetupProgress(), started: true) == .signIn)
        precondition(SetupPolicy.route(userID: "account-A", progress: SetupProgress(instrument: .guitar, tutorialComplete: true), started: false) == .ready)
        precondition(SetupRoute.tuning.usesMicrophone && SetupRoute.tutorial.usesMicrophone)
        precondition(!SetupRoute.signIn.usesMicrophone && !SetupRoute.ready.usesMicrophone)
        var autoTuner = AutoTuner()
        let ukuleleStrings = Instrument.ukulele.openStrings
        let cFeedback = autoTuner.ingest(PitchReading(frequency: 261.63, clarity: 0.95), targets: ukuleleStrings, at: 0)
        precondition(cFeedback.stringIndex == 1 && abs(cFeedback.cents ?? 1_000) < 1, "Open C should be selected without a tap")
        precondition(cFeedback.newlyTunedIndex == nil, "One reading must not finish a string")
        let cTuned = autoTuner.ingest(PitchReading(frequency: 261.63, clarity: 0.95), targets: ukuleleStrings, at: 0.6)
        precondition(cTuned.newlyTunedIndex == 1, "A steady open C should complete automatically")
        let sharpA = autoTuner.ingest(PitchReading(frequency: 450, clarity: 0.95), targets: ukuleleStrings, at: 1)
        precondition(sharpA.stringIndex == 3 && (sharpA.cents ?? 0) > 0, "The A indicator should move toward sharp")
        precondition(sharpA.newlyTunedIndex == nil, "Switching strings resets tuning stability")
        let weakReading = autoTuner.ingest(PitchReading(frequency: 440, clarity: 0.2), targets: ukuleleStrings, at: 1.1)
        precondition(weakReading.stringIndex == nil, "Noisy audio must not guess a string")
        let distantReading = autoTuner.ingest(PitchReading(frequency: 493.88, clarity: 0.95), targets: ukuleleStrings, at: 1.2)
        precondition(distantReading.stringIndex == nil, "A note far from open tuning must not pick the nearest string")
        let highE = autoTuner.ingest(PitchReading(frequency: 329.63, clarity: 0.95), targets: Instrument.guitar.openStrings, at: 2)
        precondition(highE.stringIndex == 5, "The guitar high E should not be confused with its low E")
        precondition(autoTuner.ingest(nil, targets: Instrument.guitar.openStrings, at: 2.2).stringIndex == nil, "Silence clears the live string indication")
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

    private static func harmonicTone(_ base: Double, lowAmplitude: Double, highAmplitude: Double, count: Int, sampleRate: Double) -> [Float] {
        (0..<count).map { index in
            let phase = 2 * Double.pi * Double(index) / sampleRate
            return Float((lowAmplitude * sin(base * phase) + highAmplitude * sin(2 * base * phase)) / (lowAmplitude + highAmplitude))
        }
    }
}
