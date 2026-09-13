# Automatic Four-String Ukulele Tuner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically identify and mark all four open ukulele strings from individual microphone plucks without a tuning picker or string taps.

**Architecture:** Keep the existing single-pitch detector and guitar tuner. Add three ukulele target layouts, a conservative G-octave check, and a Foundation-only state machine that infers the layout from distinct plucks before committing ambiguous checks. Persist the inferred layout so the tutorial uses the same notes.

**Tech Stack:** Swift 5, SwiftUI, AVFoundation microphone service already in the app, Foundation-only Swift command-line logic harness, Xcode iOS Simulator build.

**Spec:** `docs/superpowers/specs/2026-09-13-automatic-four-string-ukulele-tuner-design.md`

## Global Constraints

- Support high-G G4-C4-E4-A4, low-G G3-C4-E4-A4, and baritone D3-G3-B3-E4 only; no custom tuning, six/eight-string ukulele, polyphonic strum tuning, or finger-placement claims.
- No preset choice, no string tap, no Hz display. The player plucks one open string at a time, in any order.
- An uncertain note must not create a green check or assert a physical string. A chord must not create a tuning check.
- Retain the existing ±80-cent acquisition band, ±20-cent close guidance, and ±10-cent in-tune completion band; require about 0.5 seconds of valid in-tune evidence.
- Show each confirmed string in green and keep its check visible. Hold the four-string completion screen for about 1.5 seconds before tutorial navigation.
- Guitar tuner and guitar lessons must remain behaviorally unchanged. The app stays native SwiftUI and landscape-first.
- Preserve the unrelated, pre-existing changes to `Gita.xcodeproj/project.pbxproj` and `Gita/Gita.entitlements`; never stage or commit them. Do not push or deploy.

## File map and test command

- Create `Gita/Music/UkuleleTuning.swift`: the three layouts and profile-specific lesson targets.
- Create `Gita/Music/UkuleleAutoTuner.swift`: one-purpose, Foundation-only inference and check state.
- Modify `Gita/Music/Instrument.swift`: profile-aware target/lesson access while preserving guitar data.
- Modify `Gita/Music/PitchDetector.swift`: G3/G4 harmonic evidence, separate from its normal pitch estimate.
- Leave `Gita/Music/TuningJudge.swift` unchanged for guitar; put short-gap ukulele judging inside `Gita/Music/UkuleleAutoTuner.swift`.
- Modify `Gita/Setup/SetupState.swift`: inferred profile persistence and legacy migration.
- Modify `Gita/ContentView.swift`, `Gita/Views/TunerView.swift`, `Gita/Views/TutorialView.swift`, `Gita/Views/ArcadeTheme.swift`, `Gita/Views/InstrumentChoiceView.swift`: wire and render the new ukulele path.
- Extend `Tests/GitaLogicTests.swift`: deterministic tone, mixture, state, migration, and lesson checks. `Gita/Setup/ProgressStore.swift` should not need production changes.

Run the Foundation-only harness after each logic task:

```bash
swiftc Gita/Music/*.swift Gita/Setup/*.swift Tests/GitaLogicTests.swift -o /tmp/gita-ukulele-tests-20260913 && /tmp/gita-ukulele-tests-20260913
```

Run the iOS build at UI and final gates:

```bash
xcodebuild -project Gita.xcodeproj -scheme Gita -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

---

### Task 1: Three ukulele layouts and matching lessons

**Files:** Create `Gita/Music/UkuleleTuning.swift`; modify `Gita/Music/Instrument.swift`; extend `Tests/GitaLogicTests.swift`.

**Interfaces:** `UkuleleTuning: String, Codable, CaseIterable` has `highG`, `lowG`, `baritone`, `openStrings: [StringTarget]`, and `lessons: [LessonTarget]`. `Instrument.stringCount: Int`, `Instrument.tuningTargets(_ tuning: UkuleleTuning?) -> [StringTarget]`, and `Instrument.lessonTargets(_ tuning: UkuleleTuning?) -> [LessonTarget]`. An unknown ukulele profile returns an empty target/lesson array; guitar ignores the argument and returns its existing values. Keep old `Instrument.openStrings`/`.lesson` temporarily for compilation, then remove their uses in Task 5.

- [ ] **Step 1: Write failing target and lesson assertions.** Add these to the existing harness, retaining its current guitar assertions:

```swift
precondition(UkuleleTuning.allCases.count == 3)
precondition(UkuleleTuning.highG.openStrings.map(\.frequency) == [392, 261.63, 329.63, 440])
precondition(UkuleleTuning.lowG.openStrings.map(\.frequency) == [196, 261.63, 329.63, 440])
precondition(UkuleleTuning.baritone.openStrings.map(\.frequency) == [146.83, 196, 246.94, 329.63])
precondition(Instrument.ukulele.tuningTargets(nil).isEmpty)
precondition(Instrument.guitar.tuningTargets(nil).count == 6)
precondition(UkuleleTuning.lowG.lessons[2].frequencies.contains(196))
precondition(UkuleleTuning.baritone.lessons[2].frequencies == [146.83, 196, 246.94, 392])
```

- [ ] **Step 2: Run the harness.** Expect a compile failure for `UkuleleTuning` and `tuningTargets`, establishing red.
- [ ] **Step 3: Add the minimal profile model.** Use ordered targets and profile-specific lessons, preserving the existing three guitar lessons verbatim:

```swift
enum UkuleleTuning: String, Codable, CaseIterable {
    case highG, lowG, baritone

    var openStrings: [StringTarget] {
        let pitches: [(String, Double)] = switch self {
        case .highG: [("G", 392), ("C", 261.63), ("E", 329.63), ("A", 440)]
        case .lowG: [("G", 196), ("C", 261.63), ("E", 329.63), ("A", 440)]
        case .baritone: [("D", 146.83), ("G", 196), ("B", 246.94), ("E", 329.63)]
        }
        return pitches.map { StringTarget(label: $0.0, frequency: $0.1) }
    }

    var lessons: [LessonTarget] {
        if self == .baritone {
            return [
                LessonTarget(kind: .openString, title: "Find the E string", instruction: "Pluck the open E string once.", stringLabel: "E", fret: 0, frequencies: [329.63]),
                LessonTarget(kind: .fret, title: "Press fret 3", instruction: "Press fret 3 on the E string and pluck.", stringLabel: "E", fret: 3, frequencies: [392]),
                LessonTarget(kind: .chord, title: "Play a G chord", instruction: "Press E-string fret 3, then strum all four strings on the beat.", stringLabel: "D G B E", fret: nil, frequencies: [146.83, 196, 246.94, 392])
            ]
        }
        return [
            LessonTarget(kind: .openString, title: "Find the A string", instruction: "Pluck the open A string once.", stringLabel: "A", fret: 0, frequencies: [440]),
            LessonTarget(kind: .fret, title: "Press fret 3", instruction: "Press fret 3 on the A string and pluck.", stringLabel: "A", fret: 3, frequencies: [523.25]),
            LessonTarget(kind: .chord, title: "Play a C chord", instruction: "Press A-string fret 3, then strum all four strings on the beat.", stringLabel: "G C E A", fret: nil, frequencies: [261.63, 329.63, openStrings[0].frequency, 523.25])
        ]
    }
}

// Add to Instrument; retain the old properties until Task 5 has rewired all views.
var stringCount: Int { self == .ukulele ? 4 : 6 }
func tuningTargets(_ tuning: UkuleleTuning?) -> [StringTarget] {
    self == .ukulele ? (tuning?.openStrings ?? []) : openStrings
}
func lessonTargets(_ tuning: UkuleleTuning?) -> [LessonTarget] {
    self == .ukulele ? (tuning?.lessons ?? []) : lesson
}
```

- [ ] **Step 4: Run the harness and simulator build.** Both must pass; verify the old guitar test still checks E2 and guitar lessons. New Swift files are included by the Xcode project’s file-synchronized group, so do not edit signing/project configuration.
- [ ] **Step 5: Commit task-owned files only.** Stage these three paths and use `git commit --only -m 'Add four-string ukulele tuning targets' -- Gita/Music/UkuleleTuning.swift Gita/Music/Instrument.swift Tests/GitaLogicTests.swift`.

### Task 2: G-octave evidence

**Files:** Modify `Gita/Music/PitchDetector.swift`, `Tests/GitaLogicTests.swift`.

**Interfaces:** `enum GOctaveEvidence { case low, high, uncertain }`; `PitchDetector.gOctaveEvidence(_ samples: [Float], sampleRate: Double, estimatedFrequency: Double) -> GOctaveEvidence`. The function only classifies frequencies within 80 cents of G3 or G4; elsewhere it returns `.uncertain`. Existing `TuningJudge` is untouched.

- [ ] **Step 1: Add failing audio checks.** Add a `harmonicTone` fixture by summing sine waves at 196 and 392 Hz with specified amplitudes and dividing by total amplitude; use 8,192 samples at 44,100 Hz. Assert pure 392 is `.high`, 196 with its louder 392 harmonic at amplitudes 0.35/1 is `.low`, and a weak-196 case at 0.15/1 is `.uncertain`:

```swift
func harmonicTone(_ base: Double, lowAmplitude: Double, highAmplitude: Double, count: Int, sampleRate: Double) -> [Float] {
    (0..<count).map { index in
        let phase = 2 * Double.pi * Double(index) / sampleRate
        return Float((lowAmplitude * sin(base * phase) + highAmplitude * sin(2 * base * phase)) / (lowAmplitude + highAmplitude))
    }
}
precondition(PitchDetector.gOctaveEvidence(tone(392, count: 8_192, sampleRate: sampleRate), sampleRate: sampleRate, estimatedFrequency: 392) == .high)
precondition(PitchDetector.gOctaveEvidence(harmonicTone(196, lowAmplitude: 0.35, highAmplitude: 1, count: 8_192, sampleRate: sampleRate), sampleRate: sampleRate, estimatedFrequency: 392) == .low)
precondition(PitchDetector.gOctaveEvidence(harmonicTone(196, lowAmplitude: 0.15, highAmplitude: 1, count: 8_192, sampleRate: sampleRate), sampleRate: sampleRate, estimatedFrequency: 392) == .uncertain)
```

- [ ] **Step 2: Run the harness.** Expect failure for the missing `GOctaveEvidence` API.
- [ ] **Step 3: Implement the detector check.** Apply a Hann window and measure Fourier amplitude at the inferred G3 frequency and its octave (G4). Normalize both amplitudes by sample count. Classify `low / max(high, 0.0001)` as low at ≥0.25, high at ≤0.08, and uncertain between; reject near-silent windows. For readings near G4, test `estimatedFrequency / 2` and `estimatedFrequency`; for readings near G3, test `estimatedFrequency` and `estimatedFrequency * 2`. Keep the ordinary `PitchDetector.estimate` result separate.

```swift
enum GOctaveEvidence: Equatable { case low, high, uncertain }

// After measuring both Hann-windowed amplitudes inside gOctaveEvidence:
let ratio = lowAmplitude / max(highAmplitude, 0.0001)
if ratio >= 0.25 { return .low }
if ratio <= 0.08 { return .high }
return .uncertain
```

- [ ] **Step 4: Run the harness and simulator build.** Both must pass, including old guitar tuner tests and the “close is not complete” assertion.
- [ ] **Step 5: Commit only these paths.** Use `git commit --only -m 'Add G-octave evidence to pitch detector' -- Gita/Music/PitchDetector.swift Tests/GitaLogicTests.swift` after staging them.

### Task 3: Infer the ukulele layout without taps

**Files:** Create `Gita/Music/UkuleleAutoTuner.swift`; extend `Tests/GitaLogicTests.swift`.

**Interfaces:**

```swift
enum UkuleleTunerStatus: Equatable { case listening, ambiguous, tryAgain, tracking }
struct UkuleleTunerFeedback {
    let status: UkuleleTunerStatus
    let detectedNote: String?
    let confirmedTuning: UkuleleTuning?
    let stringIndex: Int?
    let cents: Double?
    let completed: Set<Int>
    let newlyTuned: Set<Int>
    let needsTopStringPrompt: Bool
}
struct UkuleleAutoTuner {
    init(confirmedTuning: UkuleleTuning? = nil, completed: Set<Int> = [])
    mutating func ingest(_ reading: PitchReading?, gEvidence: GOctaveEvidence?, at time: TimeInterval) -> UkuleleTunerFeedback
}
```

- [ ] **Step 1: Add failing deterministic sequences.** A test helper feeds each note at times `start`, `start+0.18`, `start+0.36`, `start+0.54`, followed by a nil reading 0.05 seconds later. Assert high-G locks after stable G4 and C4; low-G after G3 and A4; baritone after D3 and B3, all in arbitrary pluck order. Before lock, E4 and G3 alone cannot mark a physical slot. Four supported notes ultimately produce checks `{0,1,2,3}`. Repeating one note does not lock a layout. A G4 estimate tagged `.low` must be interpreted as low G3; `.uncertain` must not lock anything. A 0.2-clarity frame, nil, a note >80 cents from every supported target, and a synthetic four-note chord passed through `PitchDetector.estimate` must never add a check. Check that a +15-cent note is “close” but not checked. For ukulele only, test a 0.1-second invalid gap that pauses valid time without clearing it and a clear +25-cent reading that resets it.

```swift
func pluck(_ tuner: inout UkuleleAutoTuner, hz: Double, g: GOctaveEvidence? = nil, start: Double) -> UkuleleTunerFeedback {
    var result = tuner.ingest(nil, gEvidence: nil, at: start - 0.05)
    for offset in [0.0, 0.18, 0.36, 0.54] {
        result = tuner.ingest(PitchReading(frequency: hz, clarity: 0.95), gEvidence: g, at: start + offset)
    }
    _ = tuner.ingest(nil, gEvidence: nil, at: start + 0.59)
    return result
}
var tuner = UkuleleAutoTuner()
let first = tuner.ingest(PitchReading(frequency: 329.63, clarity: 0.95), gEvidence: nil, at: 0)
precondition(first.confirmedTuning == nil && first.completed.isEmpty)
let uncertainG = tuner.ingest(PitchReading(frequency: 196, clarity: 0.95), gEvidence: .uncertain, at: 0.2)
precondition(uncertainG.completed.isEmpty)
var highG = UkuleleAutoTuner()
_ = pluck(&highG, hz: 392, g: .high, start: 1)
let highResult = pluck(&highG, hz: 261.63, start: 2)
precondition(highResult.confirmedTuning == .highG)
precondition(highResult.completed.isSuperset(of: [0, 1]))
```

- [ ] **Step 2: Run the harness.** Expect a compile failure for `UkuleleAutoTuner`.
- [ ] **Step 3: Implement the independent state machine.** Require two successive clear readings within 20 cents of the same candidate target to accept an observation for profile locking; readings 20–80 cents away may guide the needle but cannot lock a layout. Use a ukulele-only valid-time accumulator for the active target. Retain stable observations as target frequencies and their in-tune completion status. Each supported layout remains plausible only if it can explain every accepted distinct observation. Ignore an isolated contradictory reading instead of eliminating a layout. Confirm a layout only when one remains after at least two *different* target observations, including one that distinguishes it. Replays of the same target do not increase distinct count. When confirmed, map buffered completed targets to their four physical indices and emit all newly available checks; while unconfirmed, keep physical checks pending rather than guessing. Once locked, continue checking the remaining strings with that layout and do not switch layouts mid-session. Convert G3/G4 readings according to `gEvidence`; if it is uncertain, retain an ambiguous state and do not use it as profile or check evidence. Set `needsTopStringPrompt` after two distinct stable observations still leave more than one layout plausible, or after a stable octave-ambiguous G. Retain up to five valid cents values per active target for the displayed median, clear that history on a target change, and hold the last display for at most 0.25 seconds across missing audio. The ukulele accumulator requires at least 0.5 seconds of valid ±10-cent readings, pauses for an invalid gap ≤0.2 seconds without counting the gap, and resets for a longer gap or a clear off-target reading. Do not modify guitar's `TuningJudge`.

```swift
// Helpers inside UkuleleAutoTuner; call accept only after two consistent readings.
func resolvedFrequency(_ reading: PitchReading, gEvidence: GOctaveEvidence?) -> Double? {
    let nearG = [196.0, 392.0].contains {
        abs(PitchDetector.cents(reading.frequency, target: $0)) <= 80
    }
    guard nearG else { return reading.frequency }
    switch gEvidence {
    case .low: return reading.frequency > 280 ? reading.frequency / 2 : reading.frequency
    case .high: return reading.frequency < 280 ? reading.frequency * 2 : reading.frequency
    case .uncertain, nil: return nil
    }
}

func index(in tuning: UkuleleTuning, for frequency: Double) -> Int? {
    tuning.openStrings.enumerated()
        .map { ($0.offset, abs(PitchDetector.cents(frequency, target: $0.element.frequency))) }
        .filter { $0.1 <= 80 }
        .min { $0.1 < $1.1 }?.0
}

mutating func accept(_ frequency: Double) {
    let supporting = Set(UkuleleTuning.allCases.filter { tuning in
        guard let slot = index(in: tuning, for: frequency) else { return false }
        return abs(PitchDetector.cents(frequency, target: tuning.openStrings[slot].frequency)) <= 20
    })
    let narrowed = candidates.intersection(supporting)
    guard !narrowed.isEmpty else { return }
    candidates = narrowed
    let canonical = narrowed.first!.openStrings[index(in: narrowed.first!, for: frequency)!]
    acceptedTargets.insert(canonical)
    if candidates.count == 1, acceptedTargets.count >= 2 {
        confirmedTuning = candidates.first!
    }
}

// Private ukulele-only hold accumulator; unlike guitar's TuningJudge it never
// counts invalid time, but tolerates one brief missing frame.
mutating func inTune(_ cents: Double?, at time: TimeInterval) -> Bool {
    guard let cents else {
        if invalidSince == nil { invalidSince = time }
        lastValidAt = nil
        if time - invalidSince! > 0.2 { resetHold() }
        return false
    }
    guard abs(cents) <= 10 else { resetHold(); return false }
    if let invalidSince, time - invalidSince > 0.2 { resetHold() }
    invalidSince = nil
    if let lastValidAt { validDuration += max(0, time - lastValidAt) }
    lastValidAt = time
    return validDuration >= 0.5
}
```

- [ ] **Step 4: Run the harness and simulator build.** Confirm all three profile sequences pass and old guitar `AutoTuner` assertions still pass.
- [ ] **Step 5: Commit only engine and harness.** Use `git commit --only -m 'Infer four-string ukulele tuning from plucks' -- Gita/Music/UkuleleAutoTuner.swift Tests/GitaLogicTests.swift` after staging.

### Task 4: Persist the inferred layout and migrate old sessions

**Files:** Modify `Gita/Setup/SetupState.swift`; extend `Tests/GitaLogicTests.swift`. Test `ProgressStore` through its existing injected `UserDefaults` API; production `ProgressStore.swift` should not change.

**Interfaces:** `SetupProgress.ukuleleTuning: UkuleleTuning?`; `SetupProgress.resetTuning()` clears checks and the inferred profile; `destination` uses `instrument.stringCount` and never enters ukulele tutorial with a nil profile. Keep existing initializer call sites source-compatible with `init(instrument: Instrument? = nil, tutorialComplete: Bool = false, completedTuning: Set<Int> = [], ukuleleTuning: UkuleleTuning? = nil, lessonStep: Int = 0)`.

- [ ] **Step 1: Add failing migration and isolation checks.** Decode legacy JSON for (a) unfinished ukulele with two old checks, (b) ukulele with four checks and incomplete tutorial, and (c) tutorial-complete ukulele. Expect (a) checks cleared and profile nil; expect (b)/(c) high-G inferred for legacy lesson compatibility. Encode/decode a new nil-profile session and verify it is *not* mistaken for legacy; save a low-G guest and baritone Apple-account session and verify they remain isolated. Assert `resetTuning()` clears both profile and checks without changing the chosen instrument.

```swift
let oldPartial = Data(#"{"instrument":"ukulele","tutorialComplete":false,"completedTuning":[0,1],"lessonStep":0}"#.utf8)
let migrated = try! JSONDecoder().decode(SetupProgress.self, from: oldPartial)
precondition(migrated.ukuleleTuning == nil && migrated.completedTuning.isEmpty)
var saved = SetupProgress(instrument: .ukulele, tutorialComplete: false, ukuleleTuning: .lowG)
saved.completedTuning = [0, 1]
saved.resetTuning()
precondition(saved.instrument == .ukulele && saved.ukuleleTuning == nil && saved.completedTuning.isEmpty)
```

- [ ] **Step 2: Run the harness.** Expect failure for missing `ukuleleTuning` and `resetTuning`.
- [ ] **Step 3: Add custom Codable migration.** Add `.ukuleleTuning` to `CodingKeys`. In decoding, use `container.contains(.ukuleleTuning)` to distinguish a legacy absent key from a new explicit `null`; for legacy ukulele with four checks or completed tutorial, assign `.highG`, otherwise clear old partial checks and keep nil. In encoding, call `encodeNil(forKey: .ukuleleTuning)` when nil so a new unknown-profile session remains distinguishable from legacy. Preserve all other fields and existing guest/account store keys. `choose(_:)` and `resetTuning()` both clear the profile and checks.

```swift
// Inside init(from:), after decoding instrument, completion, checks, and lesson step:
if !container.contains(.ukuleleTuning), instrument == .ukulele {
    if tutorialComplete || completedTuning.count == 4 { ukuleleTuning = .highG }
    else { ukuleleTuning = nil; completedTuning = [] }
} else {
    ukuleleTuning = try container.decodeIfPresent(UkuleleTuning.self, forKey: .ukuleleTuning)
}
```

```swift
// Inside encode(to:), using a separate KeyedEncodingContainer:
var container = encoder.container(keyedBy: CodingKeys.self)
try container.encode(instrument, forKey: .instrument)
try container.encode(tutorialComplete, forKey: .tutorialComplete)
try container.encode(completedTuning, forKey: .completedTuning)
try container.encode(lessonStep, forKey: .lessonStep)
if let ukuleleTuning {
    try container.encode(ukuleleTuning, forKey: .ukuleleTuning)
} else {
    try container.encodeNil(forKey: .ukuleleTuning)
}
```

- [ ] **Step 4: Run the harness and simulator build.** Verify navigation remains `.ready` for finished legacy sessions, `.tuning` for new unknown-profile sessions, and `.tutorial` only when four checks and a profile exist.
- [ ] **Step 5: Commit only setup state and harness.** Use `git commit --only -m 'Persist inferred ukulele tuning safely' -- Gita/Setup/SetupState.swift Tests/GitaLogicTests.swift` after staging.

### Task 5: Wire the landscape tuner and profile-correct tutorial

**Files:** Modify `Gita/ContentView.swift`, `Gita/Views/TunerView.swift`, `Gita/Views/TutorialView.swift`, `Gita/Views/ArcadeTheme.swift`, `Gita/Views/InstrumentChoiceView.swift`, `Gita/Music/Instrument.swift`, `Tests/GitaLogicTests.swift`.

**Interfaces:** `TunerView` receives `initialTuning: UkuleleTuning?` and reports `(Set<Int>, UkuleleTuning?)` through `onProgress`. `TutorialView` receives `tuning: UkuleleTuning?` and reads `instrument.lessonTargets(tuning)`. `ContentView` owns persistence and route transitions as before. The guitar branch continues using `AutoTuner` and its six existing targets.

- [ ] **Step 1: Add failing integration-state checks.** Assert a ukulele with four checks but nil profile stays on `.tuning`; a low-G profile with four checks advances to `.tutorial`; `lessonTargets(.baritone)` has an open E4 first lesson and G-chord last lesson; changing instrument resets the profile; beginning retune resets profile and checks. Run the harness and confirm failure before UI edits.

```swift
precondition(SetupProgress(instrument: .ukulele, tutorialComplete: false, completedTuning: [0, 1, 2, 3]).destination == .tuning)
precondition(SetupProgress(instrument: .ukulele, tutorialComplete: false, completedTuning: [0, 1, 2, 3], ukuleleTuning: .lowG).destination == .tutorial)
precondition(Instrument.ukulele.lessonTargets(.baritone)[0].frequencies == [329.63])
```

- [ ] **Step 2: Implement UI wiring.** Initialize the ukulele state machine from saved profile/checks in `TunerView`; in `onReceive`, call `PitchDetector.estimate`, then `gOctaveEvidence` for near-G readings, then `UkuleleAutoTuner.ingest`. The guitar branch keeps the existing `AutoTuner.ingest` path. Display generic four slots while profile is unknown and profile note labels once confirmed; expose inferred profile text without Hz. Set `ArcadeTheme.green = Color(red: 0.34, green: 0.92, blue: 0.58)` for check borders, text, and “string tuned” confirmation. Use `UkuleleTunerStatus` to show “checking which string,” “Pluck the top open string,” or “Try one open string again.” Keep the meter and ±20 close zone; never expose a tap target on the headstock. On four checks, show the green all-tuned message and schedule `onComplete` after 1.5 seconds; cancel the task if the view disappears or the player backs out.

```swift
let reading = PitchDetector.estimate(samples, sampleRate: microphone.sampleRate)
let evidence = reading.map {
    PitchDetector.gOctaveEvidence(samples, sampleRate: microphone.sampleRate, estimatedFrequency: $0.frequency)
}
let result = ukuleleAutoTuner.ingest(reading, gEvidence: evidence, at: ProcessInfo.processInfo.systemUptime)
if result.completed != completed || result.confirmedTuning != currentTuning {
    completed = result.completed
    currentTuning = result.confirmedTuning
    onProgress(completed, currentTuning)
}
```

- [ ] **Step 3: Update route and lesson usage.** Pass `progress.ukuleleTuning` to tuner/tutorial; save profile together with checks; call `progress.resetTuning()` on Retune. Replace every ukulele `instrument.openStrings`/`.lesson` lookup with `tuningTargets(_:)`, `lessonTargets(_:)`, or `stringCount`. Change the ukulele instrument subtitle to “4 strings · automatic tuning.” Remove obsolete default-high-G accessors only after all call sites and tests use profile-aware access. Keep the guitar open-string order and lesson copy unchanged.

```swift
TunerView(instrument: instrument, initialTuning: progress.ukuleleTuning, microphone: microphone, completed: progress.completedTuning) { tuned, profile in
    progress.completedTuning = tuned
    progress.ukuleleTuning = profile
    saveProgress()
} onComplete: {
    route = returningFromReadyRetune ? .ready : .tutorial
    returningFromReadyRetune = false
} onBack: {
    route = .instrumentChoice
}
```

- [ ] **Step 4: Run tests, build, and inspect.** The harness and simulator build must pass. Launch iPhone landscape simulator; check the headstock never requires a tap, no Hz appears, green checks persist, ambiguous audio copy is readable, the last check remains visible for 1.5 seconds, and tutorial titles/notes match high-G, low-G, and baritone data. Inspect a narrow iPad window for clipping. Treat microphone and true tuning accuracy as unverified in simulator.
- [ ] **Step 5: Commit only task-owned paths.** Use `git commit --only -m 'Show automatic four-string ukulele tuning' -- Gita/ContentView.swift Gita/Views/TunerView.swift Gita/Views/TutorialView.swift Gita/Views/ArcadeTheme.swift Gita/Views/InstrumentChoiceView.swift Gita/Music/Instrument.swift Tests/GitaLogicTests.swift` after staging.

### Task 6: Acceptance and handoff

**Files:** Review all task-owned changes; change only defects demonstrated by tests or inspection.

- [ ] **Step 1: Rebuild the logic harness from source and run it.** Record the exit code and final “Gita logic tests passed” output. Test a rich G3 harmonic fixture, pure G4, and each four-string synthetic sequence.
- [ ] **Step 2: Run a fresh simulator build.** Record the `xcodebuild` exit code. Verify `git diff d4c02fb..HEAD --name-only` contains only the plan and task-owned paths and `git status --short` still shows the user's signing edits untouched.
- [ ] **Step 3: Review every spec section.** Confirm no preset picker, no string taps, no Hz, green four-string completion, ambiguity rather than wrong checks, profile-specific lessons, migration, and unchanged guitar behavior. Report any device-only or audio-fixture limitations honestly.
- [ ] **Step 4: Field verification if a matching instrument and device are available.** On a real high-G ukulele, pluck each open string individually and compare green checks against a trusted tuner. Repeat on actual low-G and baritone instruments or labeled recordings before claiming those modes field-accurate. If access is unavailable, list these as remaining verification, not passed tests.
