# Gita first-run flow — design

Date: 2026-09-13
Status: approved in chat; awaiting written-spec review

## Purpose and scope

Build the first playable, landscape-first flow in the existing native SwiftUI iOS app. The journey follows the supplied sketch: short welcome → native Sign in with Apple → choose ukulele or guitar → tune the chosen instrument → interactive one-time tutorial. The UI takes inspiration from the energy of Japanese rhythm games without copying a particular game's assets, layout, or branding.

The deliverable ends on a compact “Ready to play” screen with controls to retune, replay the tutorial, or switch instruments. There is no song import, song library, six-string transcription model, account-backed cloud sync, or full rhythm-game level in this phase.

## Approach and rationale

Use native SwiftUI and AuthenticationServices for low-friction iOS interaction. Use an on-device single-pitch tuner rather than Basic Pitch: tuning is a monophonic task, while Basic Pitch is a polyphonic note-transcription model. Build the lesson from guided targets and microphone feedback, not an untrained universal string/fret classifier. A heavier transcription model or custom training remains a later research decision, informed by real performance data.

## Navigation and saved state

One root flow coordinator owns these states:

1. `welcome`
2. `signIn`
3. `instrumentChoice`
4. `tuning`
5. `tutorial` with three ordered exercises
6. `ready`

The player can go back within setup without losing completed tuning strings. A successful Apple authorization unlocks instrument choice. The app stores Apple's opaque user identifier securely on the device, checks its credential state at launch, and returns to sign-in if authorization is revoked or unavailable. A successful prior sign-in and completed tutorial take the player directly to `ready`; incomplete setup resumes at the last meaningful step. Instrument choice and tutorial completion are local, keyed to the Apple user identifier, so a different account does not inherit another player's progress. No remote profile or cross-device sync is implied.

The existing starter's timestamp-list/SwiftData example is unrelated to Gita and will be replaced, not shown alongside the new flow. Existing user changes to the Xcode signing settings and entitlements must be preserved. The current checkout already has an Apple sign-in entitlement and a development team configured, but the provisioning/App ID capability and on-device authorization still require verification.

## Screen experience

The app supports landscape-left and landscape-right on iPhone and iPad. Each stage uses a wide two-column composition: concise instructions and progress on one side, the active control or practice surface on the other. The visual system is an original arcade practice stage: deep indigo/near-black base, high-contrast cyan, magenta, and warm-yellow highlights, oversized note/fret targets, clear progress marks, and restrained beat-driven motion. Important text and targets remain readable at larger text sizes, and all steps work with touch and VoiceOver.

- **Welcome:** one short statement explaining that the player will choose an instrument, tune it, and play a few notes. One “Start” action; no lengthy onboarding carousel.
- **Sign-in:** Apple's unmodified native Sign in with Apple button. Show an in-context retry message on cancellation, credential failure, or missing capability; never replace failed sign-in with a pretend account.
- **Instrument choice:** two equal, large cards for standard high-G ukulele and standard six-string guitar. The player can revise the choice before or after the tutorial.
- **Tuning:** show one string at a time, target pitch, current detected frequency, sharp/flat direction, and a cents meter. The player can select a string manually; a stable in-tune reading marks it complete. Explain microphone permission clearly and offer retry when input is unavailable. The tuner must not mistake a strummed chord for a clean single string.
- **Tutorial:** three short, playable steps: (1) pluck a named open string, (2) press a named fret and pluck, (3) strum a beginner chord on the beat. Each step has a count-in, large note/string/fret diagram, immediate success/retry feedback, and a replayable instruction. Ukulele examples use the A string and C chord; guitar examples use the high E string and E-minor chord. The chord step checks a strum onset plus approximate expected pitch content. It must say “sound match” rather than claim verification of exact finger placement or all physical strings.
- **Ready:** confirm setup completion and expose “Tune again,” “Replay tutorial,” and “Switch instrument.” It does not pretend a song-playing feature exists yet.

## Audio and detection

Use `AVAudioSession` and `AVAudioEngine` to request microphone input and process small PCM windows on-device. The tuner estimates one fundamental with an autocorrelation/YIN-style algorithm, rejects quiet/noisy frames, and reports cents as `1200 × log2(detectedHz / targetHz)`. It accepts a string after a configurable short stable interval within roughly ±10 cents. A capture session stops when leaving the tuner or lesson and handles interruption/permission errors without crashing.

Standard targets are:

| Instrument | Open-string pitches in displayed string order |
| --- | --- |
| High-G ukulele | G4 392.00 Hz, C4 261.63 Hz, E4 329.63 Hz, A4 440.00 Hz |
| Standard guitar | E2 82.41 Hz, A2 110.00 Hz, D3 146.83 Hz, G3 196.00 Hz, B3 246.94 Hz, E4 329.63 Hz |

The first two tutorial checks reuse the single-pitch detector and a musical-cent tolerance. The chord check is deliberately weaker: compare the attack and energy near the expected chord fundamentals/harmonics over a short window, and require a reasonable match. It does not grade an exact string/fret transcription. Audio remains on the device; no recording upload or storage is required.

## Authentication and privacy

Use `SignInWithAppleButton`, request only the minimum account information, handle the `ASAuthorizationAppleIDCredential`, and check credential state with `ASAuthorizationAppleIDProvider` on later launches. Store the opaque account identifier in Keychain, not a public preference. Do not log tokens or personal details. Since there is no server, the app authenticates locally with Apple but does not create a cloud-backed Gita account or synchronize progress. This limitation is explicit in the app's account/setup explanation.

## Error and edge states

- If Apple sign-in is cancelled, remain at sign-in with an unobtrusive retry option.
- If authorization fails or credential is revoked, return to sign-in and keep prior local progress isolated under the former identifier.
- If microphone access is denied or hardware is missing, explain how to enable it and keep the player on tuning or tutorial; do not advance on fabricated readings.
- If audio is silent, noisy, polyphonic, or unstable, show a neutral “Play one string”/“Try again” state instead of an incorrect success.
- If the player switches instruments, clear that instrument's in-progress tuning/lesson state and present the new instrument's targets.
- At narrow landscape sizes and enlarged text, allow vertical scrolling within the stage rather than clipping controls.

## Verification and acceptance

- Xcode builds for the iOS target and both supported landscape orientations are declared.
- Native Apple sign-in presents the system authorization UI on a properly signed device; no mock fallback is shown as real authentication.
- A first-time player can traverse all screens and complete both instrument variants.
- A returning authorized player lands on `ready`, and revoked credentials lead back to sign-in.
- Tuning math is checked against known open-string frequencies and ±cent offsets. Silence and implausible/noisy pitch cannot complete a string.
- Tutorial single-note tasks use actual microphone input; chord feedback is described as approximate and can be retried.
- Permission denial and audio interruption are recoverable.
- Final visual check covers iPhone and iPad landscape, touch targets, Dynamic Type, and VoiceOver labels.

Apple references: [Sign in with Apple configuration](https://developer.apple.com/documentation/xcode/configuring-sign-in-with-apple), [SwiftUI SignInWithAppleButton](https://developer.apple.com/documentation/authenticationservices/signinwithapplebutton/init%28_%3Aonrequest%3Aoncompletion%3A%29), [credential state](https://developer.apple.com/documentation/authenticationservices/asauthorizationappleidprovider), [AVAudioEngine microphone input](https://developer.apple.com/documentation/AVFAudio/AVAudioEngine/inputNode).
