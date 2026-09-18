# Gita Practice and Video Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the current Gita first-run prototype open a playable, looping four-/six-lane starter riff, persist a performance take, and offer a first shareable Day N video template.

**Architecture:** Keep deterministic chart/timing/attempt logic in pure Foundation Swift under `Gita/Practice/`, using the existing standalone logic harness. A SwiftUI practice screen renders that state and passes microphone observations into it; capture/export remains a separate AVFoundation component so it can be replaced without changing scoring. This is a first vertical slice, not arbitrary-song transcription or camera-verified placement.

**Tech Stack:** Swift 5, SwiftUI, AVFAudio/AVFoundation, UserDefaults for metadata, local app-container files for media, existing Xcode 26.5 iOS deployment.

**Spec:** `docs/Gita-product-technical-research-2026-09-13.md` (approved by the user's “execute the plan” request). This slice covers Milestones A and a bounded first version of B. Later plans cover the separate computer-vision, broad challenge, and import subsystems.

**Progress (13 September 2026):** Tasks 1–2 have logic tests and simulator builds. Task 3's practice UI is implemented and builds, but landscape visual QA and real-instrument timing calibration remain. Task 4 has device-local challenge metadata and an editable result screen, but no synchronized camera capture, video export, or physical-device verification. A touch-only Fret Finder and a lenient score-constrained starter strum were added as early pieces of later milestones; neither verifies physical finger placement or every string independently.

## Global Constraints

- Native Gita landscape app; four-string ukulele and six-string guitar; no third-party dependencies.
- Preserve existing `Gita.xcodeproj/project.pbxproj` and `Gita/Gita.entitlements` user changes; do not stage or commit them.
- Use original starter melodies, not commercial song audio.
- Do not claim audio confirms exact finger/string placement; timing grades are provisional until physical-device calibration.
- New behavior is test-first. Baseline command: `swiftc Gita/Music/*.swift Gita/Setup/*.swift Tests/GitaLogicTests.swift -o /tmp/gita-logic-tests && /tmp/gita-logic-tests`; simulator build: `xcodebuild -project Gita.xcodeproj -scheme Gita -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`.

---

### Task 1: Authored starter chart

**Files:** Create `Gita/Practice/PracticeChart.swift`; modify `Tests/GitaLogicTests.swift`.

**Interfaces:** `PracticeNote(id: Int, beat: Double, stringIndex: Int, fret: Int, lengthBeats: Double)`; `PracticeChart(id: String, title: String, bpm: Double, beatsPerBar: Int, notes: [PracticeNote], stringLabels: [String], openFrequencies: [Double])`; `PracticeChart.starter(for:tuning:) -> PracticeChart?`; `PracticeChart.frequency(for:) -> Double`.

- [ ] Add test assertions that ukulele high-G chart has four lanes, guitar has six, each chart note maps to `openFrequencies[stringIndex] * pow(2, fret/12)`, and unknown ukulele tuning yields `nil`.
- [ ] Run the harness with `Gita/Practice/*.swift` and observe missing type/API compilation failure.
- [ ] Implement the smallest original four-bar starter charts using the existing `Instrument.tuningTargets` and `UkuleleTuning`; validate note indices and sorted beats in the constructor. No MP3 dependency.
- [ ] Run the harness and simulator build. Review that no existing tuning/lesson behavior changed.

### Task 2: Deterministic practice judgment and looping

**Files:** Create `Gita/Practice/PracticeSession.swift`; modify `Tests/GitaLogicTests.swift`.

**Interfaces:** `PracticeGrade` (`perfect`, `good`, `miss`); `PracticeHit(noteID: Int, grade: PracticeGrade, timingError: Double?)`; `PracticeSession(chart: PracticeChart, speed: Double)` with `start(at:)`, `observe(frequency:at:)`, `advance(to:)`, `restart(at:)`, `setLoop(startBeat:endBeat:at:)`, `hits`, `currentBeat(at:)`, `isComplete`.

- [ ] Add tests for an on-time expected note, a wrong pitch not passing, an early/late note outside the provisional 0.35-second window, one observation never satisfying two notes, and loop reset at its end.
- [ ] Run harness and observe missing `PracticeSession` compilation failure.
- [ ] Implement a single-note score-constrained matcher. Pitch tolerance is ±40 cents; timing grades are provisional `perfect <= 0.12 s`, `good <= 0.35 s`, otherwise miss. Store one outcome per note. A manual loop defines a beat interval and restarts with a fresh count-in. Avoid falsely crediting a chord as a single note when `PitchDetector` clarity is low.
- [ ] Run harness and simulator build; document that microphone-buffer latency is not yet calibrated.

### Task 3: Landscape practice screen and navigation

**Files:** Create `Gita/Views/PracticeView.swift`; modify `Gita/Views/ReadyView.swift`, `Gita/ContentView.swift`, and if necessary `Gita/Audio/Microphone.swift`.

**Interfaces:** `ReadyView` adds `onPractice: () -> Void`; `PracticeView(instrument:tuning:microphone:onClose:onSave:)` renders the starter chart and passes a completed `PracticeTake` to the parent. Pure practice state stays in Task 2; SwiftUI contains no scoring policy.

- [ ] Add harness checks for a `PracticeTake` summary and completed hit counts before creating the screen. Run harness and observe missing API failure.
- [ ] Implement `PracticeTake` in `PracticeSession.swift`: `chartID`, `playedAt`, `speed`, hits, and note accuracy, with literal expected outcomes in tests. Run harness green.
- [ ] Add a “Play starter riff” button to Ready and present Practice in landscape. Render four/six labelled string lanes, numbered fret notes travelling right-to-left toward a hit line, a three-beat count-in, current feedback, speed buttons, and full/first-bar loop control. Feed microphone data through `PitchDetector` only on a new attack; show provisional timing copy and clear mic permission/retry state. Do not show exact finger correctness.
- [ ] Run simulator build and inspect an iPhone 17 landscape simulator. Verify lane count, navigation back, progress, and no clipping. Physical pitch and timing accuracy remain unverified until device testing.

### Task 4: First saved take and Day N video template

**Files:** Create `Gita/Practice/PracticeTakeStore.swift`, `Gita/Views/TakeResultView.swift`, `Gita/Video/PerformanceRecorder.swift`, `Gita/Video/ChallengeVideoRenderer.swift`; modify `Gita/ContentView.swift`, `Gita.xcodeproj/project.pbxproj` only if camera permission is unavoidable and the existing user edits can be preserved exactly; modify `Tests/GitaLogicTests.swift`.

**Interfaces:** `PracticeTakeStore(defaults:)` saves/loads take metadata in guest or Apple-specific namespace; `PerformanceRecorder` captures the opted-in camera/mic take locally; `ChallengeVideoRenderer` builds a 9:16 video from a recorded take, title/day/instrument/accuracy, and returns a local URL for preview/share. No automatic social upload.

- [ ] Add harness tests proving two songs/days can have distinct takes, guest and Apple scopes do not leak, and invalid Day N outside 1...100 is rejected. Run the harness and observe missing API failure.
- [ ] Implement metadata and test until green. Do not store raw audio/video bytes in UserDefaults; media lives under the app's documents directory with delete controls.
- [ ] Add opt-in camera/mic recording and one template: title/day intro, performance, score outro. Use AVFoundation capture and offline export; do not include copyrighted backing audio. Present preview, edit Day N/song title, Save Video and Share via the system share sheet. Gracefully explain a denied camera permission and offer an animation-plus-mic-only export where feasible.
- [ ] Run simulator build and inspect result/share UI. Verify export on a physical iPhone before claiming video capture or sync accuracy works; if unavailable, report that validation explicitly and do not call this task complete.

## Final verification

- [ ] Fresh standalone logic harness passes.
- [ ] Fresh simulator build passes.
- [ ] Check user signing changes remained untouched, and report all plan tasks as complete/incomplete individually.
- [ ] No commitment or push unless only task-owned files are staged and user-owned changes remain excluded.
