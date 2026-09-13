# Automatic four-string ukulele tuner

## Goal and scope

The native Gita onboarding tuner should mark four open ukulele strings as tuned from microphone audio alone. The player does not select a tuning preset or tap a string. They pluck open strings individually, in any order. The app infers one of the agreed four-string layouts: high-G G4-C4-E4-A4, low-G G3-C4-E4-A4, or baritone D3-G3-B3-E4. Guitar tuning and guitar lessons remain unchanged. Custom and other alternate ukulele tunings are outside this version.

This is a tuner for individual open-string plucks, not a polyphonic strum detector or a way to identify physical finger placement. It must prefer an explicit uncertain state over an incorrect string or green check.

## User experience

After choosing Ukulele, the existing landscape headstock opens directly in automatic listening mode. No tuning-profile picker or string button is required. The screen shows four string slots, a low/center/high needle, plain-language direction, and microphone status; it does not show Hz. A slot becomes green with a check and a brief “G tuned!”-style message only after that string passes the stable in-tune rule. Checks remain visible while the player tunes the others. After the fourth check, show “All four strings tuned” for about 1.5 seconds before advancing to the tutorial so the last success is visible.

Before the layout is known, Gita may display the heard note and hold an ambiguous observation pending. It may mark a string shared at the same physical position across all remaining plausible layouts; it must not assign a note such as E4 or G3 while that note maps to different physical slots in the remaining layouts. Once observations narrow the layouts enough, pending valid observations may be assigned. If the layout remains uncertain, prompt “Pluck the top open string” without asking for screen interaction. If the sound is too noisy, harmonic-conflicted, or too far from every supported open-string target, show “Try one open string again” rather than a guessed direction or check. A struck chord must not complete a tuning slot.

## Components and data flow

`UkuleleTuning` is a small domain type containing the three supported layouts and their ordered `StringTarget` values. `Instrument` keeps the guitar targets; the ukulele target list comes from the inferred layout rather than a hardcoded high-G list. A dedicated ukulele inference unit consumes stable pitch events and returns: the remaining plausible layouts, any unambiguous physical string index, per-string target offset, and a confirmed layout when evidence is sufficient. `TunerView` renders that state and sends confirmed checks to `SetupProgress`. The tuner analysis is separate from the view so it can be tested with synthetic audio.

Use the existing `PitchDetector` as the starting point; a large trained model is not required for this single-note tuner. Keep its noise/clarity rejection. Smooth the displayed needle with the median of a short history of valid readings for the *same candidate string*; never blend readings from two strings. A brief invalid frame should not make the needle swing back to empty, but an actual new string or clear off-target pitch should replace the old display. Add an octave-conflict guard for G: before deciding G3 versus G4, compare the fundamental and octave candidates in the audio. If the evidence is inconclusive, keep the tuning unresolved and request another G pluck. This addresses the reported swinging G without promising that every microphone recording can be disambiguated.

Inference uses separate, stable open-string plucks rather than treating every audio buffer as independent evidence. An event within the existing ±80-cent acquisition range can support a candidate layout; it cannot receive a check until it is within the existing ±10-cent in-tune range for about 0.5 seconds. The ±20-cent “close” region remains guidance only. Require corroboration from at least two different string targets before confirming a layout, with at least one observation that differentiates it from the other layouts. Repeated plucks of one string do not count as two targets. A clearly out-of-tune observation or an octave-conflicted G cannot lock a layout. Silence or a short low-clarity gap can pause a candidate briefly; it must never count as in-tune time.

## Tutorial and saved progress

After four confirmed strings, the tutorial receives the inferred layout. High-G and low-G retain the existing A-string and A-fret-3 exercises; their C-chord target uses G4 or G3 respectively. Baritone uses its E string open, E fret 3, and an easy G chord (D3-G3-B3-G4, with E-string fret 3), so the shown fingering and expected sound agree. The lesson continues to state that microphone sound cannot prove finger placement.

Store the inferred layout with setup progress. Changing instruments or starting a fresh ukulele retune clears old ukulele checks and re-infers the layout from sound. Existing saved data must decode safely: completed legacy high-G onboarding remains complete and uses high-G lessons if replayed before a retune, while an unfinished legacy tuning session discards only its old tuning checks and re-enters the automatic tuner. Do not overwrite or merge guest and Apple-account progress. The existing user signing changes in the working tree are unrelated and must be preserved.

## Verification and acceptance

Logic tests cover the three target sets, profile inference from plucks in different orders, ambiguous shared notes, repeated plucks, G3/G4 harmonic conflict, noisy/silent/chord input, ±10 completion versus ±20 guidance, short dropouts, progress migration, and profile-specific lesson targets. Build the iOS app, then test on a real four-string ukulele with high-G first and compare each completed check to a trusted tuner. Low-G and baritone should be tested on matching instruments or labeled audio before claiming field accuracy. Success means no taps or preset choice, each supported layout can yield four correct checks, and uncertain audio never produces a confident wrong check.

## Reference behavior

GuitarTuna describes automatic *string suggestion* within a selected tuning, while a chromatic tuner identifies any audible note without knowing a physical string. Gita’s cross-layout inference is an additional behavior, not a claim that those apps infer a layout without selection. See [Yousician’s tuner modes](https://support.yousician.com/hc/en-us/articles/360014233198-How-to-change-tunings-and-other-tuner-options), [Yousician’s ukulele tuning guide](https://support.yousician.com/hc/en-us/articles/206620359-Tuning-your-ukulele), and [Simply Guitar’s chromatic tuner description](https://www.simplyguitar.com/tuner/).
