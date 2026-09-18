# Gita Gamified Ukulele Song Flow — Implementation Plan

## Goal

Refocus Gita on beginner ukulele chord learning. A returning player lands on Home, completes a progress-aware daily path, learns the chord set for a new song, then plays a karaoke-style chord chart for XP and gems. Progress caps at level 20 for the first release, and rewards are cosmetic.

The supplied sketch and chord-sheet screenshots are layout references only. Song lyrics and recordings must be licensed, public-domain, or supplied with permission; the plan does not embed the referenced song's lyrics.

## Product decisions for the first release

1. **Ukulele only.** Preserve the existing instrument setup code, but hide guitar entry points from the primary experience.
2. **A streak advances after one qualifying daily task.** Completing the whole daily path grants a bonus. This keeps the habit achievable while still rewarding deeper practice.
3. **Difficulty means an authored arrangement, not hidden chords.**
   - `Noob`: at most 2 unique chords.
   - `Guitarist Wannabe`: at most 4 unique chords.
   - `Superstar`: the complete authored chord progression.
4. **A new-song tutorial is tracked per song version and arrangement.** If the arrangement changes, the tutorial can be shown again.
5. **Song scoring evaluates chord correctness and chord-change timing only.** Up/down strumming patterns are out of scope.
6. **The player previews both the next lyric and next chord.** The next chord is the stronger cue; the next lyric line is a quieter orientation hint.
7. **Audio detection is expected-chord validation.** At each authored cue Gita asks “does this sound like the expected chord?” It does not need unconstrained transcription for this release.
8. **Shop items are cosmetic only.** No paid power, randomized loot box, or reward that changes scoring.
9. **Local-first persistence.** Extend the existing local stores before adding cloud sync.

## End-to-end user flow

```text
First launch
  → Sign in/guest
  → Choose ukulele + tune
  → Basic ukulele tutorial
  → Home

Returning launch
  → Home
  → Recommended daily task
  → Song/skill preview
  → New-song chord tutorial when required
  → Arrangement selection
  → Song player
  → Results + XP/gems
  → Home progress update

Secondary navigation
  → Songs
  → Shop
  → Backpack
  → Profile/settings
```

## Screen plan

### 1. Main application shell

Replace `ReadyView` as the post-onboarding destination with `MainTabView` inside a `NavigationStack`.

Tabs:

- **Home:** streak, level/XP, gems, daily path, continue song.
- **Songs:** song catalog and arrangement progress.
- **Shop:** cosmetic catalog.
- **Backpack:** owned/equipped cosmetics.

Keep tuning, settings, history, and account actions under a profile/menu destination rather than making them equal-weight Home actions.

### 2. Home

Top area:

- streak flame and consecutive-day count;
- level badge (`1...20`) and XP progress to the next level;
- gem balance;
- equipped mascot/accessory preview.

Daily path:

- one large **Continue** card for the next recommended task;
- two smaller follow-up tasks;
- progress such as `1 of 3 complete`;
- visible XP/gem reward on each task;
- daily-completion reward chest presented as a deterministic bundle, not a random loot box.

Recommended task selection:

1. unfinished chord tutorial required by the next song;
2. weakest recently attempted chord or transition;
3. continue current song arrangement;
4. introduce the next unlocked song;
5. fallback five-minute review.

Streak behavior:

- the first completed qualifying task on a local calendar date advances the streak once;
- repeating tasks on the same date never advances it again;
- a missed date resets the current streak on the next qualifying completion;
- store `longestStreak` separately;
- streak freeze is explicitly deferred.

### 3. Song library and arrangement selection

Each song card shows:

- title/artwork;
- unique chords for the selected arrangement;
- best score and earned stars;
- tutorial state;
- locked/unlocked state when progression requires it.

The song detail screen shows the three arrangement cards. Validate authoring rules so Noob never contains more than two unique chords and Guitarist Wannabe never contains more than four. Superstar uses the full chart.

The simpler arrangements must have their own chord cue sequence. They may hold or substitute a chord by author choice; the app must never silently remove a chord from the full arrangement while leaving incompatible audio instructions.

### 4. New-song chord tutorial

Before the first play of a song arrangement:

1. Show all chord shapes in the arrangement.
2. Teach one chord at a time with a large diagram.
3. Ask for a deliberate strum and validate only the expected chord.
4. Practice the authored chord transitions in order.
5. Show a short readiness summary and proceed to the song.

Provide **Try again**, **See fingering**, and **Continue without score**. Audio confidence must never permanently block the learner.

Track completion with `(songID, chartVersion, arrangementID)`. A Replay tutorial action remains available from song details.

### 5. Song player

Use landscape as the preferred playing orientation, while retaining a usable portrait fallback.

#### Persistent top bar

- close/pause;
- song progress and score;
- combo only after scoring is calibrated;
- visible chord rail derived from the current and next lyric lines;
- current chord large and bright;
- next chord smaller with a countdown/progress indicator;
- optional third upcoming chord only when space permits.

Do not show every chord in the song. The rail should show the actionable cue sequence associated with the visible lyric window.

#### Lyrics area

Render three semantic layers:

- previous line: dimmed;
- current line: largest and karaoke-highlighted word by word;
- next line: visible at lower contrast as a reading-ahead hint.

Chord labels sit above the lyric token they are anchored to. They must be token anchors, not fixed spaces or absolute character columns, so Dynamic Type and different screen widths remain correct.

Approximately 1.5–2 beats before a chord change:

- emphasize the next chord in the top rail;
- reveal its label above the upcoming lyric token;
- use a restrained haptic at the change only if enabled.

The word highlight follows the song source clock even when scoring is unavailable. This gives users the lyrics progression they requested without making microphone accuracy responsible for navigation.

### 6. Results

Show:

- overall score out of 100%;
- counts for Miss, Good, Great, and Perfect;
- XP and gems earned;
- level progress and any level-up reward;
- best-score comparison only when chart version, arrangement, playback rate, and scorer version match;
- Retry, Practice missed changes, and Continue buttons.

Never show a confident score when microphone confidence or the audio route makes the take unscorable. In that case show completion and practice feedback without awarding performance-grade bonuses.

### 7. Shop and Backpack

Catalog item types:

- mascot;
- mascot accessory;
- keychain;
- sticker;
- profile frame.

Level rewards can either grant an item or unlock it for purchase. Each item declares this behavior explicitly.

The Backpack is a stable grid of owned items with category filters and an Equipped section. “Boxed/backpack” refers to this visual inventory grid; no randomized opening mechanic is planned.

## Song content and timeline schema

The current `SongChart` schema is note-lane oriented. Introduce schema version 2 while retaining a version-1 decoder/migration for imported local charts.

```swift
enum ArrangementTier: String, Codable {
    case noob
    case guitaristWannabe
    case superstar
}

struct ChordDefinition: Codable, Identifiable {
    let id: String                 // "C", "Am", "Em"
    let displayName: String
    let frets: [Int?]              // G C E A; nil means muted
    let expectedFrequencies: [Double]
}

struct TimedLyricToken: Codable, Identifiable {
    let id: String
    let text: String
    let startSeconds: Double
    let endSeconds: Double
}

struct TimedLyricLine: Codable, Identifiable {
    let id: String
    let sectionID: String
    let tokens: [TimedLyricToken]
}

struct ChordCue: Codable, Identifiable {
    let id: String
    let chordID: String
    let onsetSeconds: Double
    let durationSeconds: Double
    let anchorTokenID: String?
    let scoreable: Bool
}

struct SongArrangement: Codable, Identifiable {
    let id: String
    let tier: ArrangementTier
    let chordIDs: [String]
    let cues: [ChordCue]
}
```

`SongChart` version 2 owns shared song metadata, sections, timed lyric lines, chord definitions, and arrangements. Chord cues are arrangement-specific; lyric timings are normally shared.

Validation must reject:

- unknown chord IDs or lyric token anchors;
- overlapping/out-of-order token timings;
- cues outside the audio duration;
- duplicate IDs;
- Noob arrangements with more than two unique chords;
- Guitarist Wannabe arrangements with more than four;
- empty sections or arrangements;
- unsupported tuning or malformed fret arrays.

## Authoring and configuration flow

The chart creator should produce the same visual relationship as the reference chord sheets without storing whitespace-based placement.

1. Import the exact song audio.
2. Enter song metadata and licensed lyrics.
3. Split lyrics into sections and lines.
4. Play the audio and tap to mark each line/word timing.
5. Select a lyric token and attach a chord cue above it.
6. Fine-adjust cue onset and duration on a timeline.
7. Author the Superstar progression first.
8. Duplicate and deliberately simplify it into Guitarist Wannabe and Noob arrangements.
9. Preview the exact mobile layout at supported sizes and playback rates.
10. Validate and export immutable chart JSON plus its matching audio digest.

The editor preview uses the same rules as the app:

```text
sourceTime
  → active lyric token
  → active/next lyric lines
  → current/next chord cues
  → karaoke highlight + chord rail
```

Add a Count-on-Me-shaped fixture with invented placeholder words and the same timing/chord density as the reference. Do not place copyrighted lyrics in the repository unless licensing is confirmed.

## Scoring specification

Each scoreable `ChordCue` is one rhythm-game judgment. There is no down/up pattern requirement.

Processing:

1. Detect a fresh strum attack.
2. Analyze the short sustain after the attack.
3. Match against the cue's expected chord frequencies.
4. Calculate timing error against the cue onset on the shared source timeline.
5. Emit exactly one judgment for the cue.

Initial timing windows, to calibrate with real players:

| Judgment | Correct chord | Absolute timing error | Score weight |
|---|---:|---:|---:|
| Perfect | yes | up to 90 ms | 1.00 |
| Great | yes | 91–170 ms | 0.80 |
| Good | yes | 171–320 ms | 0.50 |
| Miss | no, absent, or too late | over 320 ms | 0.00 |

```text
scorePercent = 100 × sum(judgment weights) / scoreable cue count
```

These values are versioned scorer configuration, not permanent constants. The same cue cannot score twice. A held chord without a new attack cannot satisfy a later repeated cue.

Use headphones for scored play with the original song. Speaker playback can contaminate microphone input, so speaker mode remains lyrics/progression practice without confident chord scoring until acoustic echo rejection is proven.

## Gamification data model

```swift
struct PlayerProfile: Codable {
    var totalXP: Int
    var gems: Int
    var level: Int                 // derived, capped at 20
    var currentStreak: Int
    var longestStreak: Int
    var lastQualifiedLocalDate: String?
    var ownedItemIDs: Set<String>
    var equippedItemIDs: Set<String>
    var completedTutorialKeys: Set<String>
}

struct DailyPlan: Codable {
    let localDate: String
    let tasks: [DailyTask]
    var completedTaskIDs: Set<String>
    var bonusClaimed: Bool
}

struct RewardTransaction: Codable, Identifiable {
    let id: String                 // deterministic idempotency key
    let xp: Int
    let gems: Int
    let reason: String
    let createdAt: Date
}
```

Rewards must be ledger transactions with deterministic IDs such as `daily:2026-09-15:task-1` and `song:songID:v2:noob:runID`. Reopening a result screen must never grant rewards twice.

Keep XP thresholds and item catalog in versioned configuration rather than scattering numbers through views. Suggested initial values for playtesting:

- daily task: 20 XP + 5 gems;
- full daily path bonus: 30 XP + 10 gems;
- first clear of an arrangement: 40 XP + 10 gems;
- performance bonus: 0–20 XP based on the calibrated score;
- no gem penalty for mistakes.

Use an explicit 20-level threshold table. Continue tracking `totalXP` after level 20 so future cap increases do not discard progress.

## Architecture and file map

### Reuse

- `Audio/Microphone.swift`: microphone frames.
- `Music/ChordMatcher.swift`: expected-chord baseline; calibrate rather than replace immediately.
- `Audio/GuidedSongPlayer.swift`: shared song clock and playback-rate handling.
- `Practice/SongPlaybackTimeline.swift`: source-time conversion.
- `Practice/ChallengeDayStore.swift`: recorded day history; do not use its ordinal as the new streak.
- `Practice/LocalSongLibrary.swift`: local chart/audio pairing.

### Refactor

- `ContentView.swift`: onboarding coordinator only, then present `MainTabView`.
- `ReadyView.swift`: superseded by Home; retain temporarily until migration completes.
- `SongChart.swift`: add version-2 lyric, chord-cue, and arrangement structures.
- `PracticeSession.swift`: add `great`, cue-level judgments, score weights, and scorer version.
- `GuidedPracticeView.swift`: replace the note-highway-first layout for chord songs with lyric progression and chord rail.
- `TakeResultView.swift`: present four judgment counts and reward transaction results.

### Add

- `App/MainTabView.swift`
- `Home/HomeView.swift`
- `Home/HomeViewModel.swift`
- `Gamification/PlayerProfile.swift`
- `Gamification/PlayerProgressStore.swift`
- `Gamification/DailyPlanEngine.swift`
- `Gamification/RewardLedger.swift`
- `Gamification/LevelConfiguration.swift`
- `Songs/SongDetailView.swift`
- `Songs/ArrangementTier.swift`
- `Tutorial/ChordTutorialView.swift`
- `Player/ChordSongPlayerView.swift`
- `Player/LyricTimeline.swift`
- `Player/ChordCueJudge.swift`
- `Shop/ShopView.swift`
- `Shop/BackpackView.swift`
- `Shop/CosmeticCatalog.swift`

Keep policy/state logic in Foundation-only types. SwiftUI views render state and send actions; they must not calculate streaks, grant currency, or decide scoring windows.

## Delivery milestones

### Milestone 1 — Domain foundation

- [ ] Add version-2 song schema and version-1 migration.
- [ ] Add arrangement, lyric-token, chord-cue, player-profile, daily-plan, and reward-ledger models.
- [ ] Add validation and deterministic reward/streak tests.
- [ ] Add a legal placeholder song fixture shaped like the supplied reference.

Exit: schemas round-trip; duplicate rewards and invalid arrangements are rejected.

### Milestone 2 — Home and navigation

- [ ] Add `MainTabView` after onboarding.
- [ ] Build Home streak/XP/gems header.
- [ ] Build deterministic daily path and Continue routing.
- [ ] Keep existing tuning, history, and account access reachable.

Exit: a returning user lands on Home and can complete mocked tasks without economy corruption.

### Milestone 3 — Song selection and tutorial

- [ ] Build song detail and three arrangement cards.
- [ ] Add tutorial completion keys.
- [ ] Build chord diagrams, expected-chord validation, transitions, skip, and replay.
- [ ] Route first play through tutorial and subsequent plays directly to preparation.

Exit: a new arrangement teaches only its authored chord set and never hard-blocks on microphone failure.

### Milestone 4 — Lyric timeline player

- [ ] Add timed tokens and chord anchors.
- [ ] Render previous/current/next lyric lines.
- [ ] Add karaoke word highlighting from source time.
- [ ] Add current/next chord rail and upcoming cue animation.
- [ ] Support pause, resume, restart, and playback-rate mapping.

Exit: lyrics, chord anchors, and original audio remain synchronized through a complete placeholder song.

### Milestone 5 — Scoring

- [ ] Extract cue-level `ChordCueJudge` from the current note-lane session.
- [ ] Add Miss/Good/Great/Perfect.
- [ ] Reject duplicate/held-chord credit.
- [ ] Version scoring windows and calculate 0–100%.
- [ ] Add explicit unscored speaker/microphone failure states.

Exit: synthetic tests are deterministic and physical-device calibration results are documented per chord.

### Milestone 6 — Rewards and results

- [ ] Connect qualified completion to reward ledger transactions.
- [ ] Update XP, gems, level, and streak exactly once.
- [ ] Build result breakdown and level-up presentation.
- [ ] Add retry and practice-missed-changes routes.

Exit: reopening/retrying cannot duplicate XP, gems, inventory, or streak days.

### Milestone 7 — Shop and Backpack

- [ ] Add versioned cosmetic catalog.
- [ ] Add purchase/grant transactions and insufficient-gems states.
- [ ] Build owned/equipped grid and Home mascot preview.
- [ ] Add level-20 cap behavior.

Exit: all cosmetics are deterministic, local, recoverable, and cosmetic-only.

### Milestone 8 — Authoring and calibration

- [ ] Extend the existing chart editor plan for lyric token timing, chord anchors, and arrangement duplication.
- [ ] Export schema-v2 JSON and validate it in iOS.
- [ ] Test iPhone portrait/landscape, Dynamic Type, VoiceOver, interruptions, and background/foreground transitions.
- [ ] Record multiple players, ukuleles, rooms, and devices for chord/timing calibration.

Exit: one legally usable full song completes authoring → tutorial → play → score → rewards end to end.

## Test matrix

### Pure logic

- streak same-day idempotency, consecutive day, missed day, and timezone travel;
- level threshold boundaries and level-20 cap;
- gem purchase/grant idempotency;
- daily task selection from progress;
- schema migration and invalid arrangement rejection;
- lyric token/cue lookup at boundaries and playback rates;
- one judgment per cue and four-grade thresholds;
- no reward for unscorable attempts.

### UI

- first launch versus returning Home;
- empty/new/completed daily path;
- long song titles and long translated lyric lines;
- chord labels anchored correctly at accessibility sizes;
- portrait fallback and landscape player;
- new tutorial, replay tutorial, and skip-without-score;
- shop empty/owned/equipped/insufficient-gems states.

### Physical device

- high-G and low-G ukulele handling;
- six supported beginner chords across quiet/noisy rooms;
- wired/Bluetooth headphones and speaker mode;
- microphone permission denial and audio interruptions;
- timing perception at supported playback rates;
- no false reward after aborted or low-confidence sessions.

## Explicitly deferred

- strumming direction/pattern scoring;
- arbitrary chord transcription;
- guitar and fingerstyle modes;
- leaderboards, friends, subscriptions, and cloud economy;
- randomized boxes/loot;
- streak freeze;
- AI-generated charts or automatic lyric/chord alignment;
- physical merchandise fulfillment.

## Recommended first implementation slice

Build Milestones 1 and 2 first using a placeholder song and fake-but-deterministic daily tasks. Then build the lyric timeline without microphone scoring. This validates whether learners prefer the lyric-led progression before spending more time calibrating chord detection. Add scoring only after the core song experience feels readable and synchronized.

## Product references

- [Duolingo 101](https://blog.duolingo.com/duolingo-101-how-to-learn-a-language-on-duolingo/) describes a streak increasing after a completed lesson, gems used for extras, and progress-aware practice. Gita should borrow the habit loop, not copy Duolingo's visual identity or punitive mechanics.
- [How Duolingo streaks build habit](https://blog.duolingo.com/how-duolingo-streak-builds-habit/) supports treating streak flexibility as a later retention feature; Gita's first release keeps the rule simple and defers streak freezes.
