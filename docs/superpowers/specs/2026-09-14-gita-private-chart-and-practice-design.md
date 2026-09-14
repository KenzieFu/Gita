# Gita private charts and focused practice — design

Date: 2026-09-14
Status: draft for user review; no implementation authorized by this document

## Purpose

Let a beginner learn a chosen passage of their own guitar or four-string ukulele song without repeatedly searching and replaying a video. A web editor creates a verified, osu!-like playable chart from user-provided audio and manually placed string/fret events. A private link opens that chart in the native landscape iPhone app. The first app action is **Continue practicing**; editing and challenge settings stay out of the live note screen.

The 10-day challenge records real practice on ten distinct, not necessarily consecutive, local dates. A player can stay with one song and passage or switch songs/sections between entries. Each completed entry has at least one saved microphone audio take; camera video is optional. The challenge is about musical progress, not XP, accessories, or collecting cosmetic items.

## Agreed product decisions

- Web chart authoring and iOS practice are separate experiences. The web editor may expose precise timing and note controls; the learner view does not.
- User-owned song import is part of the first release. The tab is entered or checked by a person; automatic transcription is not a trusted answer key.
- The first release uses private account-bound links. Guests can play built-in lessons, but private chart creation/import asks for Sign in with Apple. A public chart catalog and publicly shared song audio are deferred.
- Practice begins with the last song and passage in one tap. **Change song or part** opens a small selection sheet. After a take, **Practice another part** is available. There is no up-front multi-block session builder.
- A new passage has a simple **Hear it → Learn it slowly → Play with the song** progression. In Learn, a clean guide made from the verified chart is prominent while the original song stays quietly audible. Gita may suggest a faster pace after a good attempt but never increases speed automatically.
- **Fingerstyle — Coming soon** is visible but disabled in an advanced/library area, not in the one-tap beginner path. It is a feature-availability label, not a level or XP lock. First-release scoring covers supported single-note passages and basic strum/chord events only; it does not claim accurate independent simultaneous-string fingerstyle detection.
- The note highway prioritizes notes, string labels, fret numbers, timing and a small feedback signal. Challenge recaps and any future rewards appear after play, not over incoming notes.

## Alternatives considered

1. **Private web chart plus one-tap account link — chosen.** The website is comfortable for precise authoring; the app stays focused on practice. This requires authenticated metadata and audio storage, a versioned chart contract, and Apple Universal Links.
2. **Export a chart file and import it manually.** Less server work, but does not provide the requested immediate handoff and makes returning to updated charts awkward. A file round-trip may still be useful as a development and recovery tool.
3. **Public osu!-style catalog.** Attractive later, but adds audio distribution, rights review, moderation and discovery before the core learning loop is validated. It is outside this release.

For listening, an original-mix-only player preserves familiarity but can bury the part a beginner is trying to learn. Automatic guitar-stem separation is a possible later aid, but its output may bleed or distort and must not be the only reference. The chosen first-release approach is a **chart-derived clean guide plus a quiet original-song bed**: it uses the notes the author verified, needs no source-separation model, and keeps the song recognizable without a visible mixer of controls.

## Web creator experience

The existing `Website-Proto` is currently an audio-detection lab. A dedicated chart-creator route should keep that testing UI separate. The creator's first task is deliberately small: author one playable passage, not transcribe an entire song.

1. Sign in with Apple and create a private song draft. Upload an MP3 or M4A; show upload progress and a clear size/duration limit before transfer. Keep the draft private.
2. Choose standard guitar or four-string ukulele, the tuning, and the instrument's playable fret range. The chart uses exactly six or four string lanes respectively, while maximum fret is chart-specific rather than assuming every ukulele has 20 frets.
3. Suggest a beat grid/BPM from audio, but let the author correct the first beat and timing. The original audio timeline in seconds is the source of truth; a nominal BPM is for display, snapping and count-in. Note positions can be fine-adjusted when the recording drifts from a rigid grid.
4. Place notes directly on a string lane at a time and fret. Notes sharing an onset form a chord. Support edit, delete, undo, short-loop playback, and synchronized preview. Add named sections such as “Verse 1, bars 1–4” and allow a section to cover only a few bars.
5. Run lightweight validation before publishing: nonempty chart, supported tuning, legal string/fret values, note times within audio, nonempty section bounds, unique event IDs, and a preview that plays in sync. Publish an immutable chart version and copy its private import URL. Editing later creates a new version without rewriting the history used to score earlier takes.

The first release does **not** automatically turn arbitrary mixed music into a correct tab. The existing Basic Pitch experiment may later offer an explicitly labeled *draft* for a clean solo-instrument passage, but every suggested note must be reviewable before the chart becomes scoreable. The creator may save a private fingerstyle idea as a draft, but cannot publish it as a first-release *scoreable* chart; supported chart types are single-note passages and basic strum/chord events.

## Chart contract and data ownership

A published chart contains a stable chart ID, immutable version number, owner ID, title, supported play style (single-note or basic strum/chord), instrument, string count/order, tuning/open pitches, chart-specific maximum fret, source-audio reference and hash, nominal BPM, first-beat offset, ordered note events, and named sections. Each event has a stable ID, source-audio onset and duration in seconds, string index, and fret. Simultaneous events are permitted for an explicitly marked basic strum/chord; they do not by themselves enable fingerstyle scoring. A section has an ID, label, start and end time. The import format is versioned and validated on both web and iOS; an unknown schema or unsupported play style is rejected with a useful message instead of being misread.

The private service stores chart metadata and uploaded audio under the account. The import link contains an opaque chart/version identifier, **not** an Apple token, storage credential, or public audio URL. The app authenticates, requests the chart and authorized audio download, validates the package, and stores an offline copy in its sandbox. A linked chart remains private if its URL is forwarded to someone signed into a different account. The owner can delete a chart and its server-side audio; the app must explain whether a previously downloaded offline copy remains and offer local deletion separately.

The current app's `AppleSession` is a local device sign-in check, not a cross-device Gita backend account. The web and native clients therefore need a real server-side identity exchange/verification that resolves to the same Gita account. Guest onboarding remains available; following a private import link while in guest mode prompts sign-in and resumes the pending import afterward. No raw identity token or uploaded audio is logged.

## One-tap import and practice experience

An HTTPS Universal Link points to the chart's web preview and, on an installed iPhone app, opens an import preview in Gita. The preview states the title, instrument/tuning, chart version, number of sections, audio download size and owner. The player confirms import; the app downloads the chart/audio, checks integrity and saves them for offline practice. If the app is absent, the link stays on the web preview. A failed, deleted, unsupported, offline or wrong-account import presents a recoverable explanation and never creates a half-imported chart.

Home shows one primary action: **Continue practicing**. It resumes the most recent imported/built-in chart and selected section at the last comfortable speed and learning stage. **Change song or part** allows a different chart and named section; a compact custom A/B trim is available within that sheet, not as a required setup step. The learner can retry, stop, save a take, or practice another part. Starting a different part does not erase the last take.

The song library shows a non-interactive **Fingerstyle — Coming soon** card below available practice, with a short explanation: independent multi-string note scoring is not ready. It must not appear as an apparently tappable mode, require XP to unlock, or block supported melody and basic strum practice. A fingerstyle draft can be listened to on the website, but the app does not offer a misleading scored fingerstyle session.

### Beginner listening and tempo progression

The app shows one next action at a time, rather than asking a beginner to choose a playback mix, BPM and exercise mode before playing. Each stage works on the selected short passage; the learner may go back, repeat, or skip a familiar stage.

1. **Hear it.** Play the original passage while its notes are highlighted. Before scrolling begins, show a still preview of the first fingering/chord and the next few notes. This is listening and orientation, not a scored take.
2. **Learn it slowly.** A clean guitar/ukulele guide plays the chart's verified note events; the original song remains quieter underneath. A short count-in and visible beat pulse make the entry clear. Start with only a few notes or one to two bars, loop hands-free, and use a slow preset (approximately 70% of original speed as a usability-test starting point, not a universal teaching threshold). The player may choose **Slower**. This stage encourages repetition without forcing an accuracy verdict after every pass.
3. **Play with the song.** Bring the original song forward and turn the clean guide down/off so the player hears how their part fits. The selected passage, not the whole song, remains the default. The player can stay slow, repeat, or save a microphone take. This is the stage where calibrated note/timing feedback and the challenge entry are offered.

The song, guide, click/beat pulse and moving notes follow one playback clock and the same source-audio event times. Pitch-preserving time stretching slows the song without lowering its musical key; the guide and note timing scale to match. The website's estimated BPM/beat grid must be author-checked before a scored chart is published. For a performance with tempo changes, event timestamps are authoritative and the app can show “70% song speed” rather than implying a single exact BPM. Count-in aligns to the verified first beat of the chosen passage.

After an attempt, Gita may offer **Try a little faster** when feedback is sufficiently confident, but choosing it is always the player's action; there is no automatic speed increase, forced full-speed gate, or punishment for saving a slow take. If analysis is uncertain, the learner can still save effort and decide when to advance. The prior speed is remembered per section. The initial UI exposes only **Slower**, **Repeat**, and an optional **Try faster** suggestion, not several volume sliders or tempo parameters.

Scored microphone practice with the source song playing needs a headset route or another validated separation strategy, because a phone speaker can leak the reference audio into the microphone and falsely appear to be the player's notes. Hear/Learn remain usable over a speaker without a score. For the initial reliable scored path, Gita should request headphones and offer a clearly labeled unscored practice/review path without them. A route change during a take invalidates or lowers scoring confidence; the player can retry rather than receive a false result.

## Challenge entry, audio take and feedback

A **challenge day** is the next distinct local date on which the player completes and saves at least one real practice take. Thus “Day 4/10” means the fourth completed practice date, not four consecutive dates since joining. Missing a date does not erase earlier entries. Multiple takes or songs on the same date attach to that day's entry; the player may select one highlight take. The next distinct qualifying date advances the challenge by one. The calendar practice streak, if later added, is a separate counter.

Each take stores chart ID/version, section ID or exact A/B bounds, playback speed, capture date and timezone, audio-file reference, score-engine version, event-level feedback and confidence. Audio is saved in app-private local storage and can be replayed or deleted. It is not uploaded to the chart service by default. Optional camera footage has a separate permission, local preview and deletion path. A recording interruption or failed disk write cannot silently mark a challenge day complete. If microphone access is denied, the learner may review a chart but cannot save a purported recorded take.

The results screen summarizes practiced tempo, note/pitch matches, timing, and uncertain/unjudged events separately. It does **not** claim that a microphone confirmed the exact physical string or fret, since identical pitches may exist at multiple positions. A chord result must say sound/pitch match with confidence, not “all strings and fingers correct.” A take with low-confidence analysis can still be saved as genuine effort, but should not receive a falsely precise accuracy claim. Before-versus-after numeric comparisons require the same chart version, passage, comparable speed, and scoring rules; otherwise show two recordings without a quantitative improvement claim.

The detailed timing and note errors are on the post-take screen. While playing, show only immediate, non-obstructing feedback. No XP, level bars, accessory previews, mascot chatter or video effects are included in this release.

## Error handling and privacy boundaries

- A save or import is atomic: failure keeps the previous local chart/take and offers retry.
- A draft can be resumed after browser refresh or interrupted upload; published versions remain immutable.
- Incorrect tuning, unsupported fret range, malformed timings, duplicate note IDs, missing audio or incompatible schema prevent publication/import with specific errors.
- A private link alone grants no access; authorization is checked server-side for every chart and audio request. Sign-out removes temporary credentials, not another user's local takes.
- Source-song audio is not publicly redistributed in this phase. Any later public sharing of charts containing music needs a separate rights, moderation and takedown design.
- Device-local take files and optional video are deletable independently of a chart. The app should explain that local recordings are not automatically backed up by web chart sync.

## Acceptance and validation

1. An author can create a short guitar and a short four-string ukulele chart on the web, place a chord, mark a section, preview synchronized audio/notes, and publish a private version.
2. The same Apple-signed-in iPhone opens the private link, previews it, imports chart plus audio, and practices offline. A different account cannot read it; a guest is offered sign-in and returned to the pending import.
3. **Continue practicing** resumes a section and pace in one tap. A new section can be heard with the original song, rehearsed with a louder clean guide and quieter original at a slower pace, then played with the song. Changing song or part is discoverable but not required. Notes stay visually dominant throughout scored play.
4. Ten separate practice dates produce Day 1–10 with a saved audio take each; two songs on one date stay in one entry, and a missed calendar date does not reset the challenge.
5. The original song, guide, beat pulse and note highway remain synchronized through count-in, loop, and speed changes; slowing playback preserves pitch. A successful pass may suggest faster practice, but speed never changes without a player action. Tempo and note/timing feedback remain understandable and calibrated. Silence, speaker bleed, uncertain chord analysis and route changes do not produce confident false-perfect results.
6. Prior results stay tied to their chart version when the author edits a tab. Saved local audio is replayable and deletable; camera video is never required.
7. Fingerstyle is visibly marked **Coming soon** outside the main beginner action and cannot enter a scored mode. Supported single-note and basic strum/chord charts remain playable; an unsupported fingerstyle chart cannot be mis-scored as a chord chart.
8. Test chart serialization round-trips, malformed imports, authorization failures, interrupted uploads/downloads, low storage, audio-session interruptions, iPhone landscape layouts, Dynamic Type, VoiceOver, and the web creator's keyboard/touch editing.

## Delivery slices

1. Define and test the chart schema, validation, local import and offline playback using fixtures; do not start with public sharing or transcription AI.
2. Add the small web chart editor and synchronized preview, then private authenticated storage and immutable publish versions.
3. Add the Universal Link handoff and resilient iOS import, including guest-to-Apple sign-in continuation.
4. Replace the starter-only practice entry with **Continue / Change song or part**, synchronized source-song and chart-guide playback, short-section looping, the three-stage beginner path, player-controlled speed, audio take capture, the ten-date history, and a disabled **Fingerstyle — Coming soon** card outside the main practice action.
5. Calibrate timing/pitch results with real guitar/ukulele recordings and speaker/headphone routes before showing accuracy as a confident percentage.

The existing `PracticeView` only offers first-bar versus whole-riff looping, and `PracticeTakeStore` saves score metadata without an audio file. `Website-Proto` has model tests but no private chart/audio storage configured. These are starting-state observations, not completed features.

References: [osu! beatmapping concept](https://osu.ppy.sh/wiki/en/Beatmapping), [Apple Universal Links](https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app), [Basic Pitch's audio-to-MIDI scope](https://github.com/spotify/basic-pitch), [Apple's independent rate/pitch playback unit](https://developer.apple.com/documentation/avfaudio/avaudiounittimepitch), [librosa on changing-tempo beat tracking](https://librosa.org/doc/latest/auto_tutorials/03-advanced/plot_dynamic_beat.html), and [Demucs' experimental guitar separation](https://github.com/facebookresearch/demucs).
