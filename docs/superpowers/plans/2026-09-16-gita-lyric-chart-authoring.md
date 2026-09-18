# Gita Lyric Chart Authoring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Author line, word, and chord-cue timings in local Gita-Chart-Studio and play an imported schema-2 chart as a scrolling lyric block synchronized to the matching song audio.

**Architecture:** The web editor owns a resumable, local-only timing draft and exports the already-supported native `SongExperience` schema 2 only after validation. The iPhone importer continues to pair JSON with an identical audio hash; the lyric view reads source seconds and scrolls within the active practice section. The current schema-1 note editor and non-lyric note highway stay intact.

**Tech Stack:** React 19, TypeScript 5.9, Vite 8, Node 22 tests; Swift, SwiftUI, AVFoundation, CryptoKit, Xcode iOS Simulator build.

**Spec:** `Mobile-App/Gita/docs/superpowers/specs/2026-09-16-gita-lyric-chart-authoring-design.md`

## Global Constraints

- Both `Gita-Chart-Studio` and `Mobile-App/Gita` currently lack `.git`; do not initialize repositories or claim commits. Each task ends with a scoped-file inventory, fresh tests, and a saved checkpoint. If the owner later places these projects under Git, commit only task-owned files.
- User-supplied lyrics and the private Count on Me MP3 stay in local files, never in public/tracked web assets or network requests. Export JSON only; Gita imports JSON followed by the same MP3/M4A and rejects SHA-256 mismatches.
- Use schema 1 for existing non-lyric charts and schema 2 with the existing `SongExperience` shape for lyric chord charts. Do not add transcription, model training, cloud persistence, or percentage scoring.
- Store all authored onset/end values in source-recording seconds. Neither BPM nor slower practice speed changes saved timing.
- Every cue has a real token anchor and an onset inside that token interval. No silent chord substitutions or tiers; a new lyric chart starts with one authored tier. Existing three-tier Count on Me drafts retain all tiers on import.
- Uneven singing means evenly seeded word windows are drafts, never verified timing. Export requires checked included lines and cues plus native-compatible structural validation. Word-by-word correction remains optional.
- Preserve the existing six supported chord shapes (C, Em, Am, G, F, Dm) for this first editor slice. Show a clear unsupported-chord error; do not invent fret shapes.
- Keep the existing note/chord timeline, local file picker, step flow, responsive layout, and iPhone import flow working.

## File Structure

- `Gita-Chart-Studio/src/song-experience.ts`: schema-2 JSON types, validation and conversion from chord cues to required string notes.
- `Gita-Chart-Studio/src/song-experience.test.ts`: native parity, schema-1 preservation, cue/tier/section validation.
- `Gita-Chart-Studio/src/lyric-draft.ts`: resumable draft format, line/token/cue timing operations, checked status and pure save/load checks.
- `Gita-Chart-Studio/src/lyric-draft.test.ts`: deterministic authoring transitions and non-silent retime checks.
- `Gita-Chart-Studio/src/lyric-files.ts` and `.test.ts`: pure private draft/schema-2 import checks, selected-audio digest binding and verified export handoff.
- `Gita-Chart-Studio/src/LyricEditor.tsx`: line list, audio-playhead marking, selected token/chord anchor, numeric/drag timing controls and advanced word edits.
- `Gita-Chart-Studio/src/App.tsx`: lyric-mode step, draft import/export, verified schema-2 export and stable audio fingerprint binding.
- `Gita-Chart-Studio/src/editor-flow.ts` and `.test.ts`: lyric step readiness without changing schema-1 flow.
- `Gita-Chart-Studio/src/style.css`: readable, touch-friendly local authoring layout.
- `Mobile-App/Gita/Gita/Practice/SongExperience.swift`: pure section/line/cue lookup as needed by the block view; no schema rewrite.
- `Mobile-App/Gita/Gita/Views/LyricPlayerSurface.swift`: multi-line section block, anchored chord labels, active line/word emphasis and follow-scroll.
- `Mobile-App/Gita/Gita/Views/GuidedPracticeView.swift`: pass selected section to lyric surface; preserve non-lyric note highway.
- `Mobile-App/Gita/Gita/Views/SongExperiencePreviewView.swift`: show and default to only arrangements present in imported charts.
- `Mobile-App/Gita/Tests/GitaSongExperienceTests.swift`: section lookup, source-time boundaries and arrangement availability.
- `Mobile-App/Gita/Tests/GitaChartEditorInteropTests.swift` and `Tests/Fixtures/lyric-interop-chart.json`: invented-text schema-2 fixture decoded and imported with matching generated audio bytes.
- `Gita-Chart-Studio/README.md` and `Mobile-App/Gita/Gita/docs/count-on-me-local-prototype.md`: private recording workflow and verified-versus-draft limitations.
- `Mobile-App/Gita/Tests/ExportCountOnMeChart.swift`: local test-only exporter for the existing private prototype chart; output goes to an owner-selected private path, not an app/web asset.

---

### Task 1: Web schema-2 contract and chord-cue export

**Files:**
- Create: `Gita-Chart-Studio/src/song-experience.ts`
- Create: `Gita-Chart-Studio/src/song-experience.test.ts`
- Modify: `Gita-Chart-Studio/src/chart-authoring.ts`

**Interfaces:**
- Consumes: `ChartDraft`, `buildChart`, `CHORD_SHAPES`, `ChartTuning` and `ChordName`.
- Produces: `TimedLyricTokenJSON`, `TimedLyricLineJSON`, `ChordCueJSON`, `SongArrangementJSON`, `SongExperienceJSON`, `SongChartJSONV2`, `validateSongChartJSONV2(value: unknown): SongChartJSONV2`, and `buildLyricChart(draft: ChartDraft, experience: SongExperienceJSON): SongChartJSONV2`.

- [ ] **Step 1: Write red tests for exact native JSON and unchanged schema 1.** Use invented text, a 4-second fake audio digest and C at 0.5 seconds. Assert `buildChart(singleNoteDraft).schemaVersion === 1`, `buildLyricChart(...).schemaVersion === 2`, C notes `[0,0,0,3]` share one onset, and `experience.arrangements[0].cues[0].lyricTokenID` is unchanged.

```ts
const chart = buildLyricChart(chordDraft, {
  chords: [{ id: 'C', displayName: 'C', frets: [0, 0, 0, 3] }],
  lyricLines: [{ id: 'l1', sectionID: 'part', tokens: [
    { id: 'w1', text: 'Hello', startSeconds: 0.5, endSeconds: 1.5 }
  ] }],
  arrangements: [{ id: 'superstar', tier: 'superstar', chordIDs: ['C'], cues: [
    { id: 'c1', chordID: 'C', lyricTokenID: 'w1', onsetSeconds: 0.5 }
  ] }]
});
assert.equal(chart.schemaVersion, 2);
assert.deepEqual(chart.notes.map((note) => note.fret), [0, 0, 0, 3]);
```

- [ ] **Step 2: Run `node --test src/song-experience.test.ts` in `Gita-Chart-Studio`; confirm missing-export failure.**
- [ ] **Step 3: Define the schema-2 types and minimal builder.** Make `SongChartJSONV2 = Omit<SongChartJSON, 'schemaVersion'> & { schemaVersion: 2; experience: SongExperienceJSON }`. Derive notes from the `superstar` arrangement if present, otherwise the first arrangement, and emit one note per non-muted fret with stable `${cue.id}-s${index}` IDs and 0.35-second duration capped at the audio end. Call the existing `buildChart` with those notes and deduplicated chord display names before attaching `experience`.

```ts
export type ChordCueJSON = { id: string; chordID: string; lyricTokenID: string; onsetSeconds: number };
export type SongArrangementJSON = { id: string; tier: 'noob' | 'guitaristWannabe' | 'superstar'; chordIDs: string[]; cues: ChordCueJSON[] };
export type SongChartJSONV2 = Omit<SongChartJSON, 'schemaVersion'> & { schemaVersion: 2; experience: SongExperienceJSON };
const noteDuration = Math.min(0.35, draft.audioDurationSeconds - cue.onsetSeconds);
```
- [ ] **Step 4: Write red validation tests one case at a time.** Reject duplicate token/cue IDs, missing anchors, cue outside its anchor interval, unsorted cue onset, line outside the referenced section/audio, unknown chord shape, `noob` with three chord IDs, `guitaristWannabe` with five, and a practice section without a cue-generated note. Use exact error strings that identify the line or cue.
- [ ] **Step 5: Implement only these validations and run `npm test && npm run build`.** Expect all tests and TS/Vite build PASS; confirm existing schema-1 fixture tests unchanged.
- [ ] **Step 6: Record a Task 1 checkpoint:** list the three scoped files and test totals in the plan execution ledger; no Git commit in these non-repository folders.

### Task 2: Local timing draft domain

**Files:**
- Create: `Gita-Chart-Studio/src/lyric-draft.ts`
- Create: `Gita-Chart-Studio/src/lyric-draft.test.ts`

**Interfaces:**
- Consumes: Task 1's `SongExperienceJSON` and `buildLyricChart`.
- Produces: `LyricDraft` with `formatVersion: 1`, `audioSHA256`, `experience: SongExperienceJSON`, line/cue checked ID sets, `createLyricDraft(audioSHA256, chordDefinitions)`, `seedLine(id, sectionID, text, start, end)`, `setDraftLineWindow(draft, lineID, start, end)`, `setTokenWindow(draft, tokenID, start, end)`, `markCueAt(draft, tier, chordID, tokenID, onset)`, `markLineChecked(draft, lineID)`, `markCueChecked(draft, cueID)`, `getExportIssues(draft)`, `parseLyricDraftJSON(text)`, `serializeLyricDraftJSON(draft)`, and `importSchema2AsDraft(chart: SongChartJSONV2): LyricDraft`.

- [ ] **Step 1: Write red tests for seed status and playhead edits.** A line `"Bright sky"` seeded over 2–4 seconds gets two nonoverlapping tokens but `checkedLineIDs` remains empty; calling `setDraftLineWindow` while unchecked rescales only that line; calling it after marking checked throws instead of moving a checked cue silently.

```ts
const line = seedLine('l1', 'verse', 'Bright sky', 2, 4);
assert.equal(line.tokens.length, 2);
assert.deepEqual(line.tokens.map((token) => token.startSeconds), [2, 3]);
assert.equal(draft.checkedLineIDs.includes(line.id), false);
```
- [ ] **Step 2: Run `node --test src/lyric-draft.test.ts`; confirm missing-module failure.**
- [ ] **Step 3: Implement draft types, stable generated IDs and pure operations.** `createLyricDraft` creates one empty `superstar` arrangement referencing the selected existing chord definitions. Use `crypto.randomUUID()` only at UI creation boundaries; pure operations accept IDs and return new objects. `setTokenWindow` checks neighboring intervals and anchored cue membership before returning. `markCueAt` requires `token.startSeconds <= onset < token.endSeconds`, an existing tier and chord, and inserts in onset order.

```ts
export type LyricDraft = {
  formatVersion: 1;
  audioSHA256: string;
  experience: SongExperienceJSON;
  checkedLineIDs: string[];
  checkedCueIDs: string[];
};
if (!(token.startSeconds <= onset && onset < token.endSeconds)) {
  throw new Error(`Cue must be inside word ${token.id}.`);
}
```
- [ ] **Step 4: Write red tests for private draft save/load and export gate.** Draft JSON round-trips checked IDs and original audio digest; malformed JSON, wrong `formatVersion`, a different selected audio digest, unchecked lines/cues, and duplicate IDs yield specific issues without altering the current editor state.
- [ ] **Step 5: Add a red schema-2 import test:** `importSchema2AsDraft` copies all three Count-on-Me-shaped invented arrangements, tokens and cues with stable IDs, keeps the chart's audio digest, and marks every imported line/cue unchecked. Implement this conversion without auto-simplifying the chord IDs.
- [ ] **Step 6: Implement `parseLyricDraftJSON` as a validated parse and `getExportIssues` as a complete list, then run `npm test && npm run build`.** Allow incomplete draft serialization; require all included line IDs and cue IDs checked before verified chart export. Word edits are optional, not an extra export blocker.
- [ ] **Step 7: Record Task 2's two-file checkpoint and test totals.**

### Task 3: Playback-assisted lyric/chord editor

**Files:**
- Create: `Gita-Chart-Studio/src/LyricEditor.tsx`
- Create: `Gita-Chart-Studio/src/lyric-files.ts`
- Create: `Gita-Chart-Studio/src/lyric-files.test.ts`
- Modify: `Gita-Chart-Studio/src/App.tsx`
- Modify: `Gita-Chart-Studio/src/editor-flow.ts`
- Modify: `Gita-Chart-Studio/src/editor-flow.test.ts`
- Modify: `Gita-Chart-Studio/src/style.css`

**Interfaces:**
- Consumes: Tasks 1–2's draft operations and schema-2 builder; existing `<audio ref={audioRef}>` currentTime, chord cards and section editor.
- Produces: a `lyrics` step available only in lyric chord mode; local Draft JSON load/save; schema-2 verified export paired to the selected audio fingerprint.

- [ ] **Step 1: Write red flow tests.** `getStepBlocker('lyrics', { ... , lyricLineCount: 0, uncheckedTimingCount: 0 })` returns a line-required message; one unchecked line or cue blocks verified continuation; schema-1 steps never require lyrics. Extend `StepReadiness` with `lyricLineCount` and `uncheckedTimingCount` rather than hiding conditions inside `App.tsx`.

```ts
assert.equal(getStepBlocker('lyrics', { title: 'A', audioReady: true, entryCount: 1, sectionCount: 1, lyricLineCount: 0, uncheckedTimingCount: 0 }), 'Add at least one lyric line.');
assert.equal(getStepBlocker('notes', { title: 'A', audioReady: true, entryCount: 1, sectionCount: 1 }), null);
```
- [ ] **Step 2: Run `node --test src/editor-flow.test.ts`; confirm the new lyric assertions fail.**
- [ ] **Step 3: Implement the conditional step map and focused editor component.** The Song step has a `Timed lyrics & chords` toggle only for `basicStrum`. A lyric step shows section selector, editable line list, a selected word/chord card, `Mark line start at ${audio.currentTime.toFixed(3)}s`, `Mark chord at playhead`, precise numeric onset/end inputs, and a collapsible per-word timing editor. Buttons call Task 2 pure operations and show the exact validation error next to the offending item. In lyric mode, the existing chord timeline's displayed events are derived from the active arrangement cues and its drag/edit callback writes back to those cue IDs and anchored definitions; do not retain a second independent `chordEvents` list for schema-2 export. No waveform/model inference is required.

```tsx
const activeSteps = lyricMode && draft.style === 'basicStrum'
  ? ['song', 'notes', 'lyrics', 'practice', 'review'] as const
  : ['song', 'notes', 'practice', 'review'] as const;
<button type="button" onClick={() => markSelectedLine(audioRef.current?.currentTime ?? 0)}>
  Mark line at playhead
</button>
```
- [ ] **Step 4: Add red tests in `lyric-files.test.ts` for `loadLocalTimingFile(text, selectedAudioSHA256)`, `makeVerifiedLyricExport(chartDraft, lyricDraft)`, and a cue↔timeline mapping.** Saving a draft produces `formatVersion: 1` without WAV/MP3 bytes. Loading a Draft JSON or existing schema-2 chart after its MP3 produces the same line/cue IDs; loading either with a different digest throws before replacing state; verified export calls `buildLyricChart` and emits `schemaVersion: 2` while standard `buildChart` still emits `schemaVersion: 1`. Moving one timeline chord updates only its matching cue onset and preserves its token anchor; if the new onset leaves the token, reject with a word-anchor error.
- [ ] **Step 5: Implement local file actions.** Use a Draft JSON `<input type=file>` and Blob download for `serializeLyricDraftJSON`; use the existing audio SHA-256 and `audioLoadVersion` guard. On audio change clear current lyric timing or require exact-digest draft reload. Set chart version to an explicitly entered positive integer (default 2 for a refined imported prototype), never overwrite version 1 silently.

```ts
export function loadLocalTimingFile(text: string, selectedAudioSHA256: string): LyricDraft {
  const source = JSON.parse(text) as unknown;
  const loaded = typeof source === 'object' && source !== null && 'formatVersion' in source
    ? parseLyricDraftJSON(text)
    : importSchema2AsDraft(validateSongChartJSONV2(source));
  if (loaded.audioSHA256 !== selectedAudioSHA256) throw new Error('This timing file belongs to different audio.');
  return loaded;
}
```
- [ ] **Step 6: Add responsive CSS for a full-width lyric work area, selected line/word states, 44px touch targets, visible keyboard focus, ≥16px lyric text, and ≥14px control labels.** Keep the existing chord timeline and note-only view unchanged.
- [ ] **Step 7: Run `npm test && npm run build` and manually verify local editor with an invented two-line fixture:** upload a short owned audio file, mark line/cue times, save/reload draft, and export schema 2. Do not publish or upload the owner's MP3.
- [ ] **Step 8: Record the seven scoped files, test totals and manual fixture result.**

### Task 4: iPhone lyric block and source-time follow-scroll

**Files:**
- Modify: `Mobile-App/Gita/Gita/Practice/SongExperience.swift`
- Modify: `Mobile-App/Gita/Gita/Views/LyricPlayerSurface.swift`
- Modify: `Mobile-App/Gita/Gita/Views/GuidedPracticeView.swift`
- Modify: `Mobile-App/Gita/Tests/GitaSongExperienceTests.swift`

**Interfaces:**
- Consumes: existing `SongExperience`, `LyricTimeline`, `SongSection.id`, and `GuidedSongPlayer.sourceTime`.
- Produces: `LyricTimeline.lines(in sectionID: String) -> [TimedLyricLine]`, `activeLineID(in: sectionID, at: Double) -> String?`, and a section-scoped `LyricPlayerSurface(experience:arrangement:sectionID:position:)`.

- [ ] **Step 1: Write red Swift logic assertions** in `GitaSongExperienceTests.swift`: a section with three lines returns all three in order; at a gap the active line is nil but the current cue remains the last source-time cue; source times 1.99 and 2.00 choose the correct adjacent token; a section restart at 1.0 returns the first line again.

```swift
precondition(timeline.lines(in: "verse").map(\.id) == ["line-1", "line-2", "line-3"])
precondition(timeline.activeLineID(in: "verse", at: 1.0) == "line-1")
precondition(timeline.activeLineID(in: "verse", at: 4.0) == "line-2")
```
- [ ] **Step 2: Compile/run the harness from `Mobile-App/Gita`:** `swiftc Gita/Music/UkuleleTuning.swift Gita/Music/Instrument.swift Gita/Music/PitchDetector.swift Gita/Music/ChordMatcher.swift Gita/Practice/PracticeChart.swift Gita/Practice/PracticeSession.swift Gita/Practice/SongExperience.swift Gita/Practice/SongChart.swift Tests/GitaSongExperienceTests.swift -o /tmp/gita-lyric-tests && /tmp/gita-lyric-tests`. Confirm the new API is missing before implementation. This exact source list passes the existing harness at baseline.
- [ ] **Step 3: Add the pure section lookups.** Filter `experience.lyricLines` by `sectionID`, sort by startSeconds, and resolve active IDs using `startSeconds <= position < endSeconds`. Do not use a visual scroll offset or BPM as the timing clock.

```swift
func lines(in sectionID: String) -> [TimedLyricLine] {
    experience.lyricLines.filter { $0.sectionID == sectionID }.sorted { $0.startSeconds < $1.startSeconds }
}
func activeLineID(in sectionID: String, at time: Double) -> String? {
    lines(in: sectionID).first { $0.startSeconds <= time && time < $0.endSeconds }?.id
}
```
- [ ] **Step 4: Replace one-line swapping with a section block.** Pass `section.id` from `GuidedPracticeView`. In `LyricPlayerSurface`, render the section's lines in an inner `ScrollViewReader`/`ScrollView` with a bounded height; each line keeps tokens and token-anchored chord labels. Give the active line stronger contrast, the active word a small highlight, and call `proxy.scrollTo(activeLineID, anchor: .center)` only when the active line ID changes. Keep NOW/NEXT chord cards from source-time `LyricTimeline`.

```swift
ScrollViewReader { proxy in
    ScrollView {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(timeline.lines(in: sectionID)) { line in tokenLine(line).id(line.id) }
        }
    }
    .frame(maxHeight: 360)
    .onChange(of: timeline.activeLineID(in: sectionID, at: position)) { _, id in
        if let id { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) } }
    }
}
```
- [ ] **Step 5: Run the Swift harness and `xcodebuild -project Gita.xcodeproj -scheme Gita -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`.** Preserve the non-lyric note highway and check that paused/stopped source time does not advance the lyric block.
- [ ] **Step 6: Record scoped files, harness/build exit codes and a simulator screenshot only if the owner requests visual QA.**

### Task 5: Imported arrangement availability and format parity

**Files:**
- Modify: `Mobile-App/Gita/Gita/Views/SongExperiencePreviewView.swift`
- Modify: `Mobile-App/Gita/Tests/GitaSongExperienceTests.swift`
- Modify: `Gita-Chart-Studio/src/song-experience.test.ts`
- Create: `Mobile-App/Gita/Tests/GitaChartEditorInteropTests.swift`
- Create: `Mobile-App/Gita/Tests/Fixtures/lyric-interop-chart.json`

**Interfaces:**
- Consumes: Task 1's one-or-more arrangement export and `SongExperience.arrangement(for:)`.
- Produces: available-tier default/selection that never asks Gita to play a tier absent from the imported chart.

- [ ] **Step 1: Add a red pure Swift test** for a chart with only `.superstar`: selected/default tier is `.superstar`; with all three arrangements it starts at `.noob`; an absent tier cannot be sent to `onPlay`.

```swift
precondition(oneTierExperience.availableTiers == [.superstar])
precondition(oneTierExperience.defaultTier == .superstar)
precondition(threeTierExperience.defaultTier == .noob)
```
- [ ] **Step 2: Run the Task 4 harness and confirm the new availability function/test fails.**
- [ ] **Step 3: Implement `SongExperience.availableTiers` and normalized selection.** In `SongExperiencePreviewView`, initialize/repair selection from the first present arrangement, render only present arrangements, and disable Play until selection resolves. Do not fabricate simpler tiers from Superstar cues.

```swift
var availableTiers: [ArrangementTier] { arrangements.map(\.tier) }
var defaultTier: ArrangementTier? { availableTiers.contains(.noob) ? .noob : availableTiers.first }
```
- [ ] **Step 4: Add cross-format contract tests using invented two-line text.** Create `Tests/Fixtures/lyric-interop-chart.json` from a Task 1 web builder fixture with audio digest equal to SHA-256 of bytes `[1, 2, 3]`. In the web test, deep-compare the fixture with `buildLyricChart(...)` output so it cannot silently diverge. Create `GitaChartEditorInteropTests.swift` to decode that fixture and verify the exact `tier`, `lyricTokenID`, frets, notes and section; use `LocalSongLibrary.importChart` with temporary matching `[1, 2, 3]` audio and confirm `[9, 9, 9]` is rejected.

```swift
let fixture = URL(fileURLWithPath: "Tests/Fixtures/lyric-interop-chart.json")
let data = try Data(contentsOf: fixture)
let chart = try SongChart.decodeValidated(data)
precondition(chart.schemaVersion == 2 && chart.experience?.arrangements.first?.tier == .superstar)
let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
defer { try? FileManager.default.removeItem(at: root) }
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
let matchingURL = root.appendingPathComponent("matching.mp3")
let wrongURL = root.appendingPathComponent("wrong.mp3")
try Data([1, 2, 3]).write(to: matchingURL)
try Data([9, 9, 9]).write(to: wrongURL)
let library = LocalSongLibrary(root: root.appendingPathComponent("matched"))
let imported = try library.importChart(data: data, audio: matchingURL)
precondition(imported.id == chart.id)
let wrongLibrary = LocalSongLibrary(root: root.appendingPathComponent("wrong"))
do {
    _ = try wrongLibrary.importChart(data: data, audio: wrongURL)
    preconditionFailure("Wrong audio must be rejected")
} catch LocalSongLibraryError.audioMismatch {}
```
- [ ] **Step 5: Run `npm test && npm run build` in Chart Studio and compile/run the native interop harness:** `swiftc Gita/Music/UkuleleTuning.swift Gita/Music/Instrument.swift Gita/Music/PitchDetector.swift Gita/Music/ChordMatcher.swift Gita/Practice/PracticeChart.swift Gita/Practice/PracticeSession.swift Gita/Practice/SongExperience.swift Gita/Practice/SongChart.swift Gita/Practice/LocalSongLibrary.swift Tests/GitaChartEditorInteropTests.swift -o /tmp/gita-chart-interop-tests && /tmp/gita-chart-interop-tests`. Then run the simulator build. Record schema-1 unchanged, schema-2 accepted, wrong-audio rejected and tier default evidence.
- [ ] **Step 6: Record Task 5 checkpoint files and compatibility evidence.**

### Task 6: Private Count on Me timing workflow and handoff

**Files:**
- Modify: `Gita-Chart-Studio/README.md`
- Modify: `Mobile-App/Gita/Gita/docs/count-on-me-local-prototype.md`
- Create: `Mobile-App/Gita/Tests/ExportCountOnMeChart.swift`
- Private local output (not committed/published): user-authored Count on Me draft JSON and verified chart JSON beside the owner's MP3.

**Interfaces:**
- Consumes: complete local editor, existing private `count-on-me-prototype.mp3`, schema-2 Gita importer.
- Produces: repeatable owner workflow to correct Count on Me and import a new version without replacing the rough prototype.

- [ ] **Step 1: Write a local test-only exporter** whose `@main` entry calls `CountOnMePrototype.makeChart()`, validates it, encodes JSON and writes it atomically to the exact private path passed as one command-line argument. Reject missing arguments or a destination inside `Gita-Chart-Studio/public`, `dist`, or an app bundle. Do not add the output JSON to the project.

```swift
guard CommandLine.arguments.count == 2 else { fatalError("Pass one private output path") }
let output = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
let path = output.path
guard !path.contains("/Gita-Chart-Studio/public/") && !path.contains("/Gita-Chart-Studio/dist/") && !path.contains(".app/") else {
    fatalError("Output must be a private file, not a public asset or app bundle")
}
let chart = CountOnMePrototype.makeChart()
try chart.validate()
try JSONEncoder().encode(chart).write(to: output, options: .atomic)
```
- [ ] **Step 1a: Compile and run that exporter** from `Mobile-App/Gita` with `swiftc Gita/Music/UkuleleTuning.swift Gita/Music/Instrument.swift Gita/Music/PitchDetector.swift Gita/Music/ChordMatcher.swift Gita/Practice/PracticeChart.swift Gita/Practice/PracticeSession.swift Gita/Practice/SongExperience.swift Gita/Practice/SongChart.swift Gita/Practice/CountOnMePrototype.swift Tests/ExportCountOnMeChart.swift -o /tmp/gita-export-private-chart`. Pass an exact validated private destination alongside the MP3 to `/tmp/gita-export-private-chart`; the exporter must not accept a web `public`/`dist` or app-bundle path.
- [ ] **Step 2: Document exact local actions:** run the exporter to a private file beside the owner's MP3; `cd Gita-Chart-Studio && npm run dev`; open `http://localhost:3001`; load the matching MP3 and that chart file, or enter private lyric lines; mark line starts and chord changes during playback; use numeric/word corrections; save Draft JSON; check each included line/cue; export version 2 chart JSON; in Gita choose Import chart + MP3/M4A with the same audio file.
- [ ] **Step 3: Document timing truth:** current built-in windows at 11–97 seconds are rough and word intervals are equally spaced. A chord sheet supplies order/words but not timestamps. Author each intended practice section against the owner's recording; do not claim full-song or word-level exactness before checking those regions. Imported version 2 coexists with built-in version 1.
- [ ] **Step 4: Run fresh automated checks:** `npm test && npm run build` in Chart Studio; Swift schema harness and `xcodebuild -project Gita.xcodeproj -scheme Gita -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` in Gita. Ensure no private song lyrics/MP3 appear in web `dist/` or any newly created tracked asset.
- [ ] **Step 5: Run a local, private end-to-end timing pass on one owned excerpt before claiming synchronization.** For at least one line with two chord changes, listen to the exact MP3, mark line/cue starts to ≤0.1-second authoring precision, export as a new version, import it, replay at 1.0× and 0.7×, and compare visual cue onset with audible change. Save any corrections back to the private Draft JSON. This is calibration evidence, not a model-accuracy score.
- [ ] **Step 6: Record the private output path and verified excerpt coverage, without copying MP3/lyrics into the plan ledger or final answer.** Remaining unchecked sections are described as drafts. No Git commit in the present non-repository folders.

## Execution and review

Run tasks sequentially because Tasks 2–3 consume Task 1's schema and Tasks 4–6 consume the exported timing semantics. Review each task's exact producer/consumer contract before advancing. Final review checks schema parity, private-data containment, duplicate/invalid anchor handling, audio hash binding, tier availability, lyric source-time behavior, and preservation of schema-1/non-lyric paths. There is no deployment in this plan.

## Execution ledger — 2026-09-15

- Tasks 1–3 implemented inline in `Gita-Chart-Studio`: schema-2 validation/build, private timing draft and audio-hash-bound load/save, lyric/chord playhead editor, checked export gate, linked tier retiming, practice-part editing. The lyric-mode step order is Song → Practice part → Lyrics & chords → Review because a lyric line must reference an existing practice part. Existing schema-1 authoring remains intact. Final `npm test` passed 50 tests and `npm run build` passed.
- Tasks 4–5 implemented in `Mobile-App/Gita`: section-scoped scrolling lyric block and arrangement availability; Swift source-time harness, native interop fixture, matching/wrong-audio import checks, and simulator build passed. The invented schema-2 web/native fixture matched exactly.
- Task 6 exporter and local handoff implemented. The owner’s matching private MP3 hash was confirmed, and a native rough chart was exported to `Mobile-App/Gita/count-on-me-local-prototype.gita.json` outside web/public and the app bundle. Local browser QA imported that chart, showed three practice parts and 14 unchecked lines, changed one draft line start from 12.000 to 12.100 with its linked cue, and confirmed unchecked timing blocks Review. That edit was intentionally left unsaved and the browser was reloaded.
- Remaining owner calibration: listen to the intended Count On Me excerpt, correct its actual line/chord onsets, check only heard timings, save a private Draft JSON, then export and replay at 1.0× and slower practice speed. The currently exported 11–97-second prototype is a timing seed, not an exact song alignment. No Git repositories exist for these two project folders, so there are no commits.
