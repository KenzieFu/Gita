# Gita Landscape First-Run Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the approved landscape-first native iOS journey from welcome through Apple sign-in, instrument choice, live tuning, three microphone-guided exercises, and a ready screen.

**Architecture:** A SwiftUI root coordinator owns the route and local progress. Foundation-only music and detector logic is tested with deterministic PCM fixtures; an AVAudioEngine service supplies live microphone windows. AuthenticationServices owns real Apple authorization, with the opaque user ID in Keychain and account-scoped setup state in UserDefaults.

**Tech Stack:** Swift 5, SwiftUI, AuthenticationServices, Security/Keychain, AVFoundation, XCTest-free Swift command-line logic harness, Xcode 26.5 iOS SDK.

**Spec:** `docs/superpowers/specs/2026-09-13-gita-first-run-flow-design.md`

## Global Constraints

- iPhone declares landscape-left/right only. iPad supports all orientations and resizable windows under iPadOS 26, with a landscape-first two-column layout that stacks in a narrow window.
- Apple sign-in is the system button and real credential state; no mock bypass, remote profile, or cloud sync.
- The tuner handles a single open string at a time, not polyphonic transcription. Use standard high-G G4/C4/E4/A4 and standard guitar E2/A2/D3/G3/B3/E4.
- The lesson is open string, named fret, then beginner chord. Its last check is an approximate **sound match**, not physical finger placement proof.
- No song import, library, full rhythm-game level, or six-string transcription model.
- Do not overwrite or stage the user's existing signing/entitlement edits in the original checkout. Do not push or deploy.
- Execute inline in this thread unless the user explicitly requests subagents. Use focused commits only after fresh verification.

## File map

- `Gita/Music/Instrument.swift`: instrument, open strings, tutorial targets and display labels.
- `Gita/Music/PitchDetector.swift`: Foundation-only single-fundamental and cents calculations.
- `Gita/Music/ChordMatcher.swift`: conservative, approximate onset/pitch-content score.
- `Gita/Audio/Microphone.swift`: microphone permission, AVAudioEngine capture, interruption and errors.
- `Gita/Auth/AppleSession.swift`: native authorization, Keychain ID, credential-state recheck.
- `Gita/Setup/SetupState.swift`: local per-Apple-ID instrument and completion persistence.
- `Gita/ContentView.swift`, `Gita/Views/*.swift`, `Gita/GitaApp.swift`: coordinator and stages.
- `Gita.xcodeproj/project.pbxproj`: landscape declarations and microphone usage text, preserving signing lines.
- `Tests/GitaLogicTests.swift`: executable PCM and flow-state regression checks.

---

### Task 1: Music targets and navigation state

**Files:** Create `Gita/Music/Instrument.swift`, `Gita/Setup/SetupState.swift`, `Tests/GitaLogicTests.swift`.

**Interfaces:** `enum Instrument: String, Codable, CaseIterable`; `struct StringTarget { let label: String; let frequency: Double }`; `Instrument.openStrings: [StringTarget]`; `Instrument.lesson: [LessonTarget]`; `struct SetupProgress: Codable { var instrument: Instrument?; var tutorialComplete: Bool }`; `SetupProgress.destination: SetupRoute`.

- [ ] Write a failing harness assertion for the musical and resume contract:

```swift
@main struct GitaLogicTests {
    static func main() {
        precondition(Instrument.ukulele.openStrings.map(\.label) == ["G", "C", "E", "A"])
        precondition(abs(Instrument.guitar.openStrings[0].frequency - 82.4069) < 0.02)
        precondition(SetupProgress(instrument: nil, tutorialComplete: false).destination == .instrumentChoice)
        precondition(SetupProgress(instrument: .ukulele, tutorialComplete: true).destination == .ready)
        print("Gita logic tests passed")
    }
}
```

- [ ] Run `swiftc Gita/Music/Instrument.swift Gita/Setup/SetupState.swift Tests/GitaLogicTests.swift -o /tmp/gita-logic-tests` and confirm missing source/API failure.
- [ ] Define all six standard guitar and four high-G ukulele targets, the three lesson targets per instrument, and the `destination` mapping. Keep these files Foundation-only.
- [ ] Re-run the compile command and `/tmp/gita-logic-tests`; expect exit 0 and `Gita logic tests passed`.
- [ ] Commit only task-owned files with `git add Gita/Music/Instrument.swift Gita/Setup/SetupState.swift Tests/GitaLogicTests.swift` then `git commit -m "Add Gita music targets and setup state"`.

### Task 2: Deterministic audio decisions

**Files:** Create `Gita/Music/PitchDetector.swift`, `Gita/Music/ChordMatcher.swift`; extend `Tests/GitaLogicTests.swift`.

**Interfaces:** `PitchDetector.estimate(_ samples: [Float], sampleRate: Double) -> PitchReading?`; `PitchReading.frequency: Double`, `PitchReading.clarity: Double`; `PitchDetector.cents(_ frequency: Double, target: Double) -> Double`; `ChordMatcher.matches(_ samples: [Float], sampleRate: Double, targets: [Double]) -> Bool`.

- [ ] Add failing hand-derived fixtures: a 440 Hz sine at 44,100 Hz estimates 440 ± 3 Hz, silence yields `nil`, A4 at 440 Hz is 0 ± 0.1 cents and 466.16 Hz is +100 ± 0.5 cents; a mixture of 261.63/329.63/392 Hz matches C-major-like expected content, but a lone 440 Hz tone does not.
- [ ] Run the same `swiftc` command with the two new music files added; confirm unresolved detector/matcher APIs.
- [ ] Implement a bounded, normalized autocorrelation/CMNDF single-fundamental estimator with energy/clarity gate, plus a separate Goertzel-based chord evidence check requiring multiple expected pitch bands and a non-silent onset. The matcher returns only an approximate sound-content decision.
- [ ] Compile all three music files and the harness; run `/tmp/gita-logic-tests`. Add fixture checks for low E2, ±10-cent boundary, white-noise rejection, and a two-note chord that must not count as the three-pitch target.
- [ ] Commit only the music files and harness after tests pass.

### Task 3: Apple account and account-scoped persistence

**Files:** Create `Gita/Auth/AppleSession.swift`, `Gita/Setup/ProgressStore.swift`; extend `Gita/Setup/SetupState.swift` and harness.

**Interfaces:** `@MainActor final class AppleSession: ObservableObject` exposes `userID`, `status`, `handle(_ result: Result<ASAuthorization, Error>)`, and `refreshCredentialState()`; `ProgressStore.load(for userID: String) -> SetupProgress`; `ProgressStore.save(_:for:)`; `ProgressStore.resetInstrument(for:)`.

- [ ] Add a failing harness assertion that storing progress for Apple ID `account-A` does not appear under `account-B`, using an injected isolated `UserDefaults(suiteName: "GitaLogicTests")` and removing that suite in the harness after the check.
- [ ] Compile the Foundation-only harness and confirm the missing `ProgressStore` API fails.
- [ ] Add `ProgressStore` with a namespaced key derived from the opaque account identifier, JSON-encoded `SetupProgress`, and a safe default for absent/corrupt data. Add Keychain store/read/delete of the opaque identifier to `AppleSession`; after launch, call `ASAuthorizationAppleIDProvider.getCredentialState(forUserID:)` and accept only `.authorized`. Request no unnecessary scopes. Failure/cancellation remains on sign-in.
- [ ] Run the harness, then run `xcodebuild -project Gita.xcodeproj -scheme Gita -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`. Confirm both exit 0 before the next task.
- [ ] Commit only task-owned files; preserve user entitlement changes.

### Task 4: Live microphone service and tuner decision

**Files:** Create `Gita/Audio/Microphone.swift`, `Gita/Music/TuningJudge.swift`; extend harness; modify `Gita.xcodeproj/project.pbxproj` only for microphone usage text and orientation.

**Interfaces:** `@MainActor final class Microphone: ObservableObject` exposes `state: MicrophoneState`, `latestSamples: [Float]`, `sampleRate: Double`, `start() async`, `stop()`; `TuningJudge.ingest(_ reading: PitchReading?, target: Double, at time: TimeInterval) -> Bool`.

- [ ] Add failing judge checks: in-tune readings within ±10 cents for 0.5 seconds complete; one in-tune frame, silence, and off-target pitch do not.
- [ ] Compile/run the harness and confirm missing `TuningJudge`.
- [ ] Implement the stable timer and reset on invalid readings. Implement `AVAudioApplication.requestRecordPermission`, configure `AVAudioSession` for measurement input, install one input-node tap, send copied Float PCM windows to the main actor, and remove the tap/stop the engine on exit. Publish permission denied, hardware/error, and interruption states rather than fabricated readings.
- [ ] Set `NSMicrophoneUsageDescription` and left/right landscape entries for iPhone and iPad without changing `CODE_SIGN_ENTITLEMENTS` or team values. Run harness and simulator `xcodebuild`; review the diff of `project.pbxproj` for signing preservation.
- [ ] Commit only the new audio/judge files, harness, and exact configuration hunks.

### Task 5: Landscape stage and native sign-in

**Files:** Replace `Gita/ContentView.swift`, `Gita/GitaApp.swift`; create `Gita/Views/ArcadeTheme.swift`, `Gita/Views/WelcomeView.swift`, `Gita/Views/SignInView.swift`, `Gita/Views/InstrumentChoiceView.swift`, `Gita/Views/ReadyView.swift`.

**Interfaces:** `ContentView` owns `AppleSession`, `Microphone`, `SetupProgress`, and `SetupRoute`; stage views receive explicit closures. `SignInView` uses the native `SignInWithAppleButton(.signIn, onRequest:onCompletion:)` and forwards the real result to `AppleSession.handle`.

- [ ] Add a failing pure flow-state harness check: without an authorized ID the route is `.signIn`; an authorized ID with saved completed progress becomes `.ready`; switching instrument becomes `.tuning` with fresh tuning state.
- [ ] Run harness, confirm route-policy API failure, then implement that policy in `SetupState.swift` and make the harness pass.
- [ ] Replace the starter SwiftData timestamp UI and model container with a high-contrast, scrollable landscape two-column stage. Welcome has one Start action; sign-in has Apple's unmodified button plus retry message; instrument cards save selected instrument under the authorized ID; Ready has Retune, Replay lesson and Switch instrument actions. Use clear VoiceOver labels.
- [ ] Run simulator `xcodebuild`; launch on iPhone and iPad landscape simulators to inspect clipping and stage order.
- [ ] Commit only task-owned files after build and visual check.

### Task 6: Guided tuning and three playable lessons

**Files:** Create `Gita/Views/TunerView.swift`, `Gita/Views/TutorialView.swift`; modify `Gita/ContentView.swift`; extend harness if lesson-state rules are extracted to `Gita/Setup/LessonJudge.swift`.

**Interfaces:** `TunerView(instrument:microphone:onComplete:onBack:)`; `TutorialView(instrument:microphone:onComplete:onBack:)`; `LessonJudge` evaluates one open-string target, one fretted-note target, and one approximate chord sound match.

- [ ] Add failing harness checks for the exact open/fretted frequencies and lesson progression: unrelated note does not advance; correct note advances once; chord screen requires multiple target pitch bands, never a single pitch.
- [ ] Run harness, confirm failure, then implement minimum lesson-state logic and pass the harness.
- [ ] Build TunerView around explicit string selection, live Hz/cents, tuning direction, stable completion marks, mic permission retry, and no chord success. Build TutorialView with beat count-in, illustrated string/fret/chord target, Start Listening, immediate retry feedback, and copy saying “Approximate sound match” for the chord. Stop capture when either stage disappears.
- [ ] Run harness and simulator build. Inspect both instrument paths in landscape; physically verify Apple authorization and microphone interaction on a signed device when one is available.
- [ ] Commit only task-owned files after verification. Record any unavailable physical-device checks as unverified, not passing.

### Task 7: Final acceptance pass

**Files:** Review all touched files; modify only proven defects.

- [ ] Run `/tmp/gita-logic-tests` from a fresh `swiftc` build and record the exit code.
- [ ] Run `xcodebuild -project Gita.xcodeproj -scheme Gita -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` and record the exit code.
- [ ] Check the final diff against every spec section, especially native Apple sign-in, real microphone gating, account isolation, landscape declarations, permission/interruptions, no song feature, and honest chord copy.
- [ ] Review `git status --short`, verify no user-staged files were captured, and report the exact scope of device-only verification remaining.
