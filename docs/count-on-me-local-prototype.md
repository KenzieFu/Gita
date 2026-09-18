# Count on Me local playtest song

This prototype uses the MP3 supplied by the project owner. The app contains a private local copy at `Gita/count-on-me-prototype.mp3`; that file is Git-ignored and must not be published or redistributed without appropriate rights.

The app installs the song into its local song library when the player opens Songs. Open **Songs → Browse songs and parts → Count on Me · Prototype**, then choose Verse 1, Pre-chorus, or Chorus. Select Noob (2 chords), Guitarist Wannabe (4), or Superstar (all 6), learn the shapes, and start the part.

The current chart covers approximately 11–97 seconds of the 197.7-second recording. Its original word timings were evenly interpolated from rough line windows, and the chord changes come from the owner's chord-sheet screenshots. Gameplay now ignores word highlighting and follows the manually authored chord seconds directly. These times remain authoring drafts—not verified transcription or karaoke alignment.

The chart configuration lives in `Gita/Practice/CountOnMePrototype.swift`. On first install, the app serializes it as schema-2 JSON and stores it beside the MP3 in the local song library. A local test-only exporter in `Tests/ExportCountOnMeChart.swift` writes that native draft as JSON outside the app bundle. Its current output is `count-on-me-local-prototype.gita.json` at the project root; keep it private.

To rebuild this particular recording with the simplified workflow, run Chart Studio on `http://127.0.0.1:3001/`, load the exact `Gita/count-on-me-prototype.mp3`, choose each chord and manually place its second, then add the practice-part boundaries. Use the optional tempo snap only when a chord really lands on that beat. Export the schema-2 chart and use Gita's **Import chart + audio** with the same MP3/M4A. The imported version coexists with the built-in prototype rather than silently replacing it.

The current 11–97-second windows are seeds only. A chord sheet provides chord order but not recording timestamps. Author chord seconds manually in Chart Studio; BPM is only an optional beat-snapping guide. During Play, Gita shows Perfect, Great, Good, or Miss from the chord match and timing error. Use headphones so the backing audio does not contaminate the microphone; speaker playback remains unscored. Do not claim calibrated accuracy before playtesting the real ukulele at original and slower practice speeds.
