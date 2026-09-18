# Gita Local Chart Authoring Plan

**Goal:** Build a separate local website in `CH6/Gita-Chart-Studio` without altering `Website-Proto` or its pitch-model lab. Export a versioned chart JSON whose notes, difficulty, chord names, sections and audio digest match the native `SongChart` schema. Add an explicit local iPhone chart/audio import for end-to-end testing. This is not the private account-bound link yet.

**Constraints:** Preserve the dirty website model lab and dirty iOS prototype. Do not upload copyrighted audio or charts to an unconfigured public service. No guessed tabs are marked verified. Test pure chart construction before UI and run web tests/build plus native chart tests/build.

## Task 1: Chart builder and tests

- [ ] Add `src/chart-authoring.test.ts` first, asserting a valid GCEA single-note JSON matches the native schema and invalid fret, lane, section, chord metadata and digest fail. Run `npm test` and observe missing builder failure.
- [ ] Add `src/chart-authoring.ts` with `buildChart`, tuning presets and validation. Export deterministic seconds and 64-hex audio digest; author enters BPM, first beat offset, difficulty and chord names.
- [ ] Run `npm test` and `npm run build`.

## Task 2: Manual browser editor

- [ ] Add `src/App.tsx` and scoped CSS. Upload MP3/M4A locally, inspect duration, audition with native audio controls, mark notes using current playback time plus selected string/fret, add named sections, choose single notes/basic chords and easy/medium/hard, and export matching JSON after SHA-256 hashing the uploaded bytes.
- [ ] Show a warning that manual chart events are author-verified; no automatic MP3 transcription or private upload is claimed.
- [ ] Run lint/build and inspect a desktop/mobile preview.

## Task 3: Native local pairing

- [ ] Add a `LocalChartImport` pure state test before implementation: chart JSON and audio must be paired; wrong SHA is rejected without a library entry.
- [ ] Add a native Files import control to the song library: select chart JSON then matching MP3/M4A; use `LocalSongLibrary.importChart`, list sections, preview difficulty/chords, and play a section.
- [ ] Run Swift harnesses, simulator build and a local smoke test. Do not label this a private share link.

## Deferred, separate integration plan

Private account-bound authoring and Universal Link import require a configured storage/auth backend. Before enabling, design Apple identity verification, private object storage, access checks, expiry/revocation, and real-device associated-domain validation. No public URL should expose arbitrary user MP3 content.
