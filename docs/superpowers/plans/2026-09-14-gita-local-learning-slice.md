# Gita Local Learning Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make one verified song chart playable offline in Gita through Hear it, Learn it slowly, and Play with the song, with player-controlled tempo, saved audio takes, a ten-date challenge, and Fingerstyle visibly coming soon.

**Architecture:** A versioned Foundation-only chart model and local store feed the existing `PracticeChart`/`PracticeSession` through a seconds-to-virtual-beats adapter. A single AVAudioEngine playback clock schedules source audio, a chart-generated guide and beat cues; SwiftUI renders learning stages without owning scoring policy. Local media and challenge records are separate from the existing metadata-only `PracticeTakeStore` so user changes remain intact.

**Tech Stack:** Swift 5, SwiftUI, AVFAudio/AVFoundation, Foundation, CryptoKit, existing iOS 26.5 target; no third-party dependencies.

**Spec:** `docs/superpowers/specs/2026-09-14-gita-private-chart-and-practice-design.md`. This plan implements its local iPhone learning subsystem. Separate plans implement the web editor/private chart service and account-bound Universal Link handoff.

## Global Constraints

- Preserve all pre-existing dirty `Gita.xcodeproj/project.pbxproj`, `Gita/Gita.entitlements`, `Gita/ContentView.swift`, `Gita/Views/*`, `Gita/Practice/*`, and `Tests/GitaLogicTests.swift` changes; inspect overlapping changes before editing and stage only task-owned paths.
- The first playable styles are single-note and basic strum/chord. Fingerstyle is a disabled Coming soon card, never an XP lock or a secretly scored chord.
- Guest built-in practice remains available. Private account import is a separate subsystem.
- Audio cannot prove physical string/fret placement. Low-confidence microphone readings never create a confident accuracy claim.
- At every speed, source audio, guide, beat cues and notes share one source timeline. Score-backed playback with original audio requires headphones; speaker mode stays unscored.
- Test first: standalone Swift logic harness and `xcodebuild -project Gita.xcodeproj -scheme Gita -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`.

---

### Task 1: Validated Versioned Song Chart

**Files:** Create `Gita/Practice/SongChart.swift`, `Tests/Fixtures/short-ukulele-chart.json`, `Tests/GitaSongChartTests.swift`.

**Interfaces:** `SongChart.decodeValidated(_ data: Data) throws -> SongChart`; `SongChart.practiceChart() -> PracticeChart`; `SongChart.section(id:) -> SongSection?`. `SongNote` stores `id`, `onsetSeconds`, `durationSeconds`, `stringIndex`, `fret`; `SongSection` stores `id`, `title`, `startSeconds`, `endSeconds`.

- [ ] **Step 1: Write a failing round-trip/validation test.** Use a standalone `@main` test entry containing:

```swift
let data = try Data(contentsOf: URL(fileURLWithPath: "Tests/Fixtures/short-ukulele-chart.json"))
let chart = try SongChart.decodeValidated(data)
precondition(chart.notes.count == 2 && chart.sections[0].id == "intro")
precondition(chart.practiceChart().notes[0].beat == chart.notes[0].onsetSeconds * chart.nominalBPM / 60)
var bad = chart
bad.notes[0].fret = bad.maxFret + 1
precondition((try? SongChart.decodeValidated(JSONEncoder().encode(bad))) == nil)
```

- [ ] **Step 2: Verify red.** Run `swiftc Gita/Music/*.swift Gita/Setup/*.swift Gita/Practice/*.swift Tests/GitaSongChartTests.swift -o /tmp/gita-song-chart-tests && /tmp/gita-song-chart-tests`; expect missing `SongChart` compilation failure.
- [ ] **Step 3: Implement exact schema and validation.** Define mutable-value fields on `SongNote` and `SongChart` with `schemaVersion: Int = 1`, `id: String`, `version: Int`, `title: String`, `style: SongPlayStyle`, `difficulty: SongDifficulty`, `chordNames: [String]`, `instrument: Instrument`, `stringLabels: [String]`, `openFrequencies: [Double]`, `maxFret: Int`, `nominalBPM: Double`, `beatsPerBar: Int`, `firstBeatOffsetSeconds: Double`, `audioDurationSeconds: Double`, `audioSHA256: String`, `notes: [SongNote]`, `sections: [SongSection]`. Difficulty and chord names are verified author metadata shown before a song is played, not guesses from MP3. Require style `.singleNote` or `.basicStrum`, 4/6 lanes matching instrument, finite positive BPM/duration/frequencies, unique note/section IDs, in-range frets, positive durations, note/section bounds within audio duration, sorted onset times and no unsupported schema. Only `.basicStrum` permits simultaneous events. Convert seconds to virtual beats as `seconds * nominalBPM / 60`; this preserves event-time alignment even if the recording tempo varies. Beat cues use `firstBeatOffsetSeconds` separately.
- [ ] **Step 4: Verify green and build.** Re-run the standalone harness, then run the simulator build. Commit only the chart model, fixture and new test.

### Task 2: Atomic Local Chart and Audio Import

**Files:** Create `Gita/Practice/LocalSongLibrary.swift`; extend `Tests/GitaSongChartTests.swift`.

**Interfaces:** `LocalSongLibrary(root: URL)`; `importChart(data: Data, audio: URL) throws -> SongChart`; `load(chartID: String, version: Int) throws -> (SongChart, URL)`; `list() throws -> [SongChart]`; `delete(chartID: String, version: Int) throws`.

- [ ] **Step 1: Write failing storage tests.** In a fresh temporary directory, create an audio fixture and set the chart's digest from its bytes; import it, read it back, then try different audio and assert that no partial chart directory remains:

```swift
let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
let matchingAudioURL = temporaryDirectory.appendingPathComponent("matching.mp3")
let wrongAudioURL = temporaryDirectory.appendingPathComponent("wrong.mp3")
try Data([1, 2, 3]).write(to: matchingAudioURL)
try Data([9, 9, 9]).write(to: wrongAudioURL)
var importable = chart
importable.audioSHA256 = SHA256.hash(data: Data([1, 2, 3])).map { String(format: "%02x", $0) }.joined()
let chartData = try JSONEncoder().encode(importable)
let library = LocalSongLibrary(root: temporaryDirectory)
_ = try library.importChart(data: chartData, audio: matchingAudioURL)
precondition(try library.load(chartID: "test-song", version: 1).0.id == "test-song")
precondition((try? library.importChart(data: chartData, audio: wrongAudioURL)) == nil)
```

- [ ] **Step 2: Verify red.** Run the standalone harness and expect missing `LocalSongLibrary` failure.
- [ ] **Step 3: Implement atomic import.** `decodeValidated`, stream/copy the audio into a UUID-named staging directory under `root`, compute `SHA256.hash(data:)` over the copied bytes, compare against `audioSHA256`, write `chart.json`, then move the staging directory atomically to `<chartID>/<version>`. Refuse traversal in IDs and an existing different version; remove only the exact staging path on failure. `list` decodes only valid chart files. Never store raw audio in UserDefaults.
- [ ] **Step 4: Verify green/build; commit exact files.**

### Task 3: Deterministic Learning Stages and Speed Ladder

**Files:** Create `Gita/Practice/LearningFlow.swift`, `Gita/Practice/SongPlaybackTimeline.swift`; extend `Tests/GitaSongChartTests.swift`.

**Interfaces:** `LearningFlow(stage: LearningStage = .hear, rate: Double = 0.7)` with `advance()`, `slower()`, `acceptFasterSuggestion()`, `shouldSuggestFaster(score: Double?, confidence: Double) -> Bool`; `SongPlaybackTimeline(sourceStart: Double, rate: Double)` with `elapsed(forSourceSeconds:)` and `sourceSeconds(forElapsed:)`.

- [ ] **Step 1: Write failing flow and sync tests.** Check stage order, rate bounds, no auto-increase after a score, low-confidence no suggestion, and timeline mapping:

```swift
var flow = LearningFlow()
precondition(flow.stage == .hear && flow.rate == 0.7)
flow.advance(); precondition(flow.stage == .learn)
precondition(flow.shouldSuggestFaster(score: 0.9, confidence: 0.95))
precondition(flow.rate == 0.7)
flow.acceptFasterSuggestion(); precondition(flow.rate > 0.7)
let clock = SongPlaybackTimeline(sourceStart: 30, rate: 0.5)
precondition(clock.elapsed(forSourceSeconds: 31) == 2)
```

- [ ] **Step 2: Verify red** with the standalone harness.
- [ ] **Step 3: Implement pure state.** Use `.hear`, `.learn`, `.play`; `advance()` never alters rate. `slower()` subtracts `0.1` and `acceptFasterSuggestion()` adds `0.1`, both clamped to `0.5...1.0`. `shouldSuggestFaster` returns true only for score at least `0.85`, confidence at least `0.9`, and rate below `1.0`; it never mutates rate. Source time maps as `(sourceSeconds - sourceStart) / rate`. Store rates in local section preferences keyed by chart ID/version/section ID when wiring the view; do not invent a fixed-BPM assumption.
- [ ] **Step 4: Verify green/build; commit exact files.**

### Task 4: Synchronized Song, Guide, and Beat Playback

**Files:** Create `Gita/Audio/GuidedSongPlayer.swift`, `Gita/Audio/GuideToneRenderer.swift`; extend `Tests/GitaSongChartTests.swift` for renderer/timeline logic.

**Interfaces:** `GuidedSongPlayer.prepare(chart: SongChart, audioURL: URL, section: SongSection) throws`; `play(stage: LearningStage, rate: Double) throws`; `stop()`; `sourceTime: TimeInterval`; `GuideToneRenderer.render(frequency: Double, duration: Double, sampleRate: Double) -> [Float]`.

- [ ] **Step 1: Write failing guide tests.** Require a bounded, non-silent plucked tone of the requested duration, silence for invalid frequency, and note/chord event onsets matching `SongPlaybackTimeline` at 0.5 and 1.0 rates.

```swift
let tone = GuideToneRenderer.render(frequency: 440, duration: 0.2, sampleRate: 44_100)
precondition(tone.count == 8_820 && tone.contains(where: { abs($0) > 0.01 }))
precondition(GuideToneRenderer.render(frequency: -1, duration: 0.2, sampleRate: 44_100).isEmpty)
```

- [ ] **Step 2: Verify red** with the standalone harness.
- [ ] **Step 3: Implement tone and player.** Render a short decaying fundamental/harmonic tone with attack and bounded peak. Use `AVAudioEngine` with source player through `AVAudioUnitTimePitch` (`pitch = 0`, `rate = selectedRate`), guide player, and beat cue through separate mixer inputs:

```swift
engine.attach(songNode); engine.attach(timePitch); engine.attach(guideNode)
engine.connect(songNode, to: timePitch, format: sourceFormat)
engine.connect(timePitch, to: engine.mainMixerNode, format: sourceFormat)
engine.connect(guideNode, to: engine.mainMixerNode, format: guideFormat)
timePitch.pitch = 0
timePitch.rate = Float(rate)
songNode.volume = stage == .learn ? 0.25 : 1.0
guideNode.volume = stage == .hear ? 0.0 : (stage == .learn ? 1.0 : 0.0)
```

Schedule a count-in and section loop using one host-time anchor. Convert chart event source times to elapsed via `SongPlaybackTimeline`; publish the same source time to the note highway. Stop all nodes on interruption/route change, and expose a recoverable state. Verify source/guide sync with a short fixture on simulator and headphones on device before claiming scoring quality.
- [ ] **Step 4: Run pure tests and simulator build.** Inspect pitch at slowed speed by ear and with a synthetic test file; commit exact audio files/tests.

### Task 5: Quiet Beginner Practice Screen and Fingerstyle Card

**Files:** Create `Gita/Views/GuidedPracticeView.swift`, `Gita/Views/SongLibraryView.swift`; modify `Gita/ContentView.swift`, `Gita/Views/ReadyView.swift` only after preserving their current dirty content; extend `Tests/GitaSongChartTests.swift` for any extracted presentation state.

**Interfaces:** `GuidedPracticeView(chart: SongChart, section: SongSection, audioURL: URL, microphone: Microphone, onTake: (PracticeTake) -> Void, onClose: () -> Void)`; `SongLibraryView(songs: [SongChart], onSelect: (SongChart) -> Void)`.

- [ ] **Step 1: Write failing presentation-state tests.** Assert built-in starter practice remains available to guests, `SongChart.decodeValidated` rejects `"fingerstyle"` style, and **Continue practicing** resolves the last available section or falls back to the starter.
- [ ] **Step 2: Verify red** in the standalone harness for pure selection state.
- [ ] **Step 3: Implement UI.** Keep Ready/Home primary action **Continue practicing** and one **Change song or part** sheet. New passages show a still fingering preview, then Hear/Learn/Play; Play uses the existing note-highway visual and `PracticeSession` through `SongChart.practiceChart()`. Show only Repeat, Slower, and player-chosen Try faster as appropriate; show source track quietly under the guide in Learn. Add a non-tappable `Fingerstyle — Coming soon` card below playable library content; no XP or unlock action. In Play, require headphones for confident song-backed scoring; speaker mode remains explicitly unscored. The disabled card must not be a `Button`:

```swift
VStack(alignment: .leading) {
    Text("Fingerstyle")
    Text("Coming soon · multi-string note scoring is not ready")
}.accessibilityElement(children: .combine)
```
- [ ] **Step 4: Build and visually inspect** iPhone landscape, long title, four/six lanes, Dynamic Type, VoiceOver, and the disabled card. Commit only task-owned changes, preserving all unrelated working-tree edits.

### Task 6: Recorded Takes and Ten Distinct Practice Dates

**Files:** Create `Gita/Practice/ChallengeDayStore.swift`, `Gita/Audio/PracticeAudioRecorder.swift`, `Gita/Views/ChallengeHistoryView.swift`; modify `Gita/Views/TakeResultView.swift` and `Gita/ContentView.swift` carefully; extend `Tests/GitaSongChartTests.swift`.

**Interfaces:** `ChallengeDayStore(root: URL)` with `save(take: PracticeTake, audioURL: URL, chart: SongChart, section: SongSection, at: Date, timeZone: TimeZone) throws -> ChallengeDay` and `days() throws -> [ChallengeDay]`; `PracticeAudioRecorder.start() throws`, `stop() throws -> URL`, `cancel()`.

- [ ] **Step 1: Write failing date/media tests.** Save two takes on the same local date and one after a gap; require challenge labels Day 1 and Day 2, both same-day takes under Day 1, no reset after the gap, and no day if audio-file copy fails.

```swift
let first = try store.save(take: takeA, audioURL: audioA, chart: chart, section: section, at: dateA, timeZone: zone)
let second = try store.save(take: takeB, audioURL: audioB, chart: chart, section: section, at: dateA.addingTimeInterval(3600), timeZone: zone)
precondition(first.ordinal == 1 && second.ordinal == 1)
```

- [ ] **Step 2: Verify red** with the standalone harness.
- [ ] **Step 3: Implement file-backed recording and day store.** Record microphone PCM to an app-private audio file while Play runs; write an entry only after the complete file exists. Group by captured local date and original timezone, append extra same-day takes, and store chart version, section bounds, rate, score version and confidence. Save JSON atomically:

```swift
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = timeZone
let components = calendar.dateComponents([.year, .month, .day], from: at)
let dayKey = String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)
let existing = days.firstIndex { $0.localDate == dayKey }
let ordinal = existing.map { days[$0].ordinal } ?? (days.count + 1)
try JSONEncoder().encode(days).write(to: metadataURL, options: .atomic)
```

Expose replay/delete of a local take, and do not upload audio by default. Keep optional camera separate; it never gates a challenge day.
- [ ] **Step 4: Add a restrained result/history view** with practiced speed, note match, timing, unjudged count and audio replay. Numerical before/after requires identical chart version/section/speed/scorer; otherwise show takes without an improvement percentage. Run tests, simulator build and microphone/route smoke test, then commit exact files.

## Final verification

- [ ] New standalone chart/learning tests pass and the existing `GitaLogicTests` harness remains green.
- [ ] Fresh simulator build passes; inspect iPhone landscape for small and large text.
- [ ] On physical iPhone, confirm one short chart imports locally, Hear/Learn/Play stay in sync at 0.7 and 1.0 rate, Play does not award false-perfect from speaker leakage, and recorded audio replays.
- [ ] Report any physical-device validation that could not be run rather than calling the accuracy calibrated.
- [ ] Confirm pre-existing staged/untracked files were preserved and only task-owned changes were committed.
