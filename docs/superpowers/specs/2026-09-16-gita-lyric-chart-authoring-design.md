# Gita lyric chart authoring and synchronized song player

## Goal

Let the player follow a readable verse/chorus lyric block with chords anchored to the words they accompany, rather than a single changing line. Give the owner a local Gita-Chart-Studio workflow to correct lyric and chord timings against the exact MP3 used in Gita. Timings are authored data, not predictions from a chord sheet or evenly divided words.

## Current state and root cause

`CountOnMePrototype.swift` stores rough line windows for only 11–97 seconds of a 197.7-second recording. It sets every token duration to `(line.end - line.start) / wordCount` and derives chord onset from a token start. Real singing has unequal word and phrase lengths, so both lyric highlighting and chord changes drift. `LyricPlayerSurface.swift` shows the active line plus one next line. Gita-Chart-Studio exports schema-1 note charts and has no lyric editing; Gita already decodes schema-2 `SongExperience` charts and imports JSON paired with audio through a SHA-256 match.

## Scope and product behavior

1. Preserve the existing single-note/chart editor behavior and schema-1 export for charts without lyrics. A lyric-enabled chord chart exports schema 2 using the existing `SongExperience`, `TimedLyricLine`, `TimedLyricToken`, `ChordCue`, and `SongArrangement` shapes.
2. In Gita-Chart-Studio, the default lyric workflow is line and chord-change timing: load MP3/M4A, enter or import sectioned lyric lines, play/pause/scrub, tap to mark a line start and a chord change at the audio playhead, and drag/enter precise times for corrections. Individual token start/end edits are optional and accessible through an advanced control.
3. Newly split words have explicitly labeled **draft** timings in the editable draft until checked. Draft spacing may help seed editing but must never be described as verified or accurate. A line end is constrained by its section and the next line. A chord cue must anchor to a selected token; its onset is kept inside that token's interval as required by the iPhone schema. Reassigning a cue to a different word is an explicit edit.
4. The current chord timeline and fretboard editing remain available. Chord cue editing and fretboard shapes refer to the same chord definitions, so export does not silently create a different chord progression. Each schema-2 chord cue produces the required simultaneous string notes at its onset. Practice sections contain at least one such cue and stay within the audio duration.
5. The first authoring target is the owner's private Count on Me recording and existing six-chord chart. The editor can import an existing schema-2 JSON draft to preserve its three authored arrangement tiers and upgrade timings without re-entering all chords. A new lyric chart starts with one authored arrangement; extra tiers may be copied and edited, but the editor does not silently simplify chords. Gita's preview offers only tiers actually present.
6. The editor exports JSON only. The matching audio remains local in the browser; the existing iPhone flow imports chart JSON and then the identical MP3/M4A. It rejects an audio hash mismatch. Draft save/load uses a local downloadable JSON file, not a cloud account, remote API, or browser storage of private lyrics/audio.
7. In Gita, the active section appears as a vertically readable lyric block. The current line/word is highlighted from song source time, nearby lines remain visible, and the scroll position follows the active line without replacing the whole block on each word. Chord labels sit above their anchored tokens; the top rail still emphasizes current and next chord. No percentage score is shown for this uncalibrated arrangement.
8. Existing imported song versions and the rough built-in prototype are not overwritten. The refined chart uses a new version so the user can compare and revert. Do not put the full copyrighted song text or private MP3 into a tracked or published website asset; the owner loads private material into the local editor and imports the resulting private JSON to Gita.

## Data and lifecycle

The selected audio file is fingerprinted using the browser's SHA-256 implementation. The chart draft stores section, line, token and chord-cue IDs plus seconds in the source recording; playback speed changes presentation time, not saved source times. An imported chart must have a matching audio fingerprint before its timings can be exported for that audio. Changing audio invalidates old timing validation, rather than silently binding it to a new recording.

The editor validates ordered, finite, in-range line/token intervals; nonoverlap within lines; unique IDs; section ownership; tier chord limits; cue token references; cue onset inside its token; generated note bounds; and practice-section coverage. It gives a local, specific error near the offending line/cue. Editor-only timing status (`draft`/`checked`) is stored in the resumable draft, not in schema 2. Saving a draft is allowed while incomplete; iPhone export is blocked until the included lines and chord cues are checked and schema-2 validation passes.

The iPhone lyric view computes the active section/line/token and current/next cue from source time. Scrolling changes only the view; it never changes cue onset or the song clock. Pause, replay, speed change and section restart reposition the highlight from source time. If source time is unavailable, the UI pauses progression and does not fabricate a score or cue hit.

## Implementation boundaries

- Gita-Chart-Studio: extend authoring domain/schema validation, add focused lyric/anchor timing modules and tests, add a separate lyric-and-cue editing section to the existing step flow, and support local draft import/export. Avoid adding model inference or automatic transcription in this slice.
- Gita: use the already-supported schema-2 import path; change only song-tier availability and the lyric surface/scroll behavior plus tests. Preserve non-lyric note highway and calibrated tuner/model experiments.
- Private Count on Me data: use the user's local MP3 and existing rough prototype as a starter for a playback-assisted timing pass. Correct line and chord boundaries first, then refine words where the highlight noticeably drifts. Unverified regions remain visibly marked as drafts in the editor and cannot be exported to Gita as a verified chart; do not claim exact synchronization from pasted chord/lyric text alone.

## Acceptance checks

1. A schema-1 chart still exports and imports as before.
2. A lyric-enabled chart from the editor is accepted by `SongChart.decodeValidated` and `LocalSongLibrary.importChart` with the same audio, and rejected with different audio.
3. Chord labels remain anchored to the intended word across narrow/large text layouts; changing a word time changes its highlight but does not silently shift a different cue.
4. At normal and slower playback, paused/restarted/looped playback returns the correct active word and chord from source time.
5. The Count on Me private draft can be loaded, corrected, saved, reloaded and exported as a new version. Its current rough timestamps are not presented as verified.
6. The player shows multiple lines of the current section together and scrolls/highlights rather than swapping in one line at a time.
