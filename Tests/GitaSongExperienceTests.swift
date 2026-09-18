import Foundation

@main
enum GitaSongExperienceTests {
    static func main() throws {
        let experience = fixture()
        try experience.validate(stringCount: 4, duration: 8, sectionIDs: ["verse"])

        let arrangement = experience.arrangement(for: .noob)!
        let timeline = LyricTimeline(experience: experience, arrangement: arrangement)
        precondition(timeline.activeTokenID(at: 1.2) == "hello")
        precondition(timeline.currentCue(at: 2.6)?.chordID == "am")
        precondition(timeline.nextCue(after: 2.6)?.chordID == "c")
        precondition(timeline.lines(in: "verse").map(\.id) == ["line-1", "line-2"])
        precondition(timeline.activeLineID(in: "verse", at: 1.99) == "line-1")
        precondition(timeline.activeLineID(in: "verse", at: 3.5) == nil)
        precondition(timeline.activeLineID(in: "verse", at: 4) == "line-2")
        precondition(timeline.activeLineID(in: "verse", at: 1) == "line-1")
        precondition(experience.availableTiers == [.noob])
        precondition(experience.defaultTier == .noob)
        var singleTier = experience
        singleTier.arrangements[0].tier = .superstar
        precondition(singleTier.defaultTier == .superstar)

        let manualProgression = SongExperience(
            chords: [ChordDefinition(id: "c", displayName: "C", frets: [0, 0, 0, 3])],
            lyricLines: [],
            arrangements: [SongArrangement(id: "superstar", tier: .superstar, chordIDs: ["c"], cues: [
                ChordCue(id: "manual-c", chordID: "c", lyricTokenID: nil, onsetSeconds: 1.25)
            ])]
        )
        try manualProgression.validate(stringCount: 4, duration: 8, sectionIDs: ["verse"])
        precondition(LyricTimeline(experience: manualProgression, arrangement: manualProgression.arrangements[0]).currentCue(at: 1.3)?.id == "manual-c")

        var overlapping = experience
        overlapping.lyricLines[1].tokens[0].startSeconds = 2.8
        do {
            try overlapping.validate(stringCount: 4, duration: 8, sectionIDs: ["verse"])
            preconditionFailure("Lyric lines in one part must not overlap")
        } catch SongChartError.invalid {
            // Expected.
        }

        var wrongAnchor = experience
        wrongAnchor.arrangements[0].cues[0].lyricTokenID = "friend"
        do {
            try wrongAnchor.validate(stringCount: 4, duration: 8, sectionIDs: ["verse"])
            preconditionFailure("A chord cue must be anchored at its timed lyric token")
        } catch SongChartError.invalid {
            // Expected.
        }

        let cue = arrangement.cues[0]
        precondition(ChordCueJudge.judge(cue: cue, detectedChordID: "c", detectedAt: 1.06).grade == .perfect)
        precondition(ChordCueJudge.judge(cue: cue, detectedChordID: "c", detectedAt: 1.15).grade == .great)
        precondition(ChordCueJudge.judge(cue: cue, detectedChordID: "c", detectedAt: 1.27).grade == .good)
        precondition(ChordCueJudge.judge(cue: cue, detectedChordID: "am", detectedAt: 1.02).grade == .miss)
        precondition(ChordCueJudge.score([
            .init(cueID: "1", grade: .perfect, timingError: 0, points: 100),
            .init(cueID: "2", grade: .great, timingError: 0.1, points: 80)
        ]) == 90)

        var invalid = experience
        invalid.arrangements[0].chordIDs.append("missing")
        do {
            try invalid.validate(stringCount: 4, duration: 8, sectionIDs: ["verse"])
            preconditionFailure("Invalid chord reference should fail validation")
        } catch SongChartError.invalid {
            // Expected.
        }

        print("Gita song experience tests passed")
    }

    private static func fixture() -> SongExperience {
        SongExperience(
            chords: [
                ChordDefinition(id: "c", displayName: "C", frets: [0, 0, 0, 3]),
                ChordDefinition(id: "am", displayName: "Am", frets: [2, 0, 0, 0])
            ],
            lyricLines: [
                TimedLyricLine(id: "line-1", sectionID: "verse", tokens: [
                    TimedLyricToken(id: "hello", text: "Hello", startSeconds: 1, endSeconds: 2),
                    TimedLyricToken(id: "friend", text: "friend", startSeconds: 2, endSeconds: 3)
                ]),
                TimedLyricLine(id: "line-2", sectionID: "verse", tokens: [
                    TimedLyricToken(id: "play", text: "Play", startSeconds: 4, endSeconds: 5),
                    TimedLyricToken(id: "along", text: "along", startSeconds: 5, endSeconds: 6)
                ])
            ],
            arrangements: [
                SongArrangement(id: "noob", tier: .noob, chordIDs: ["c", "am"], cues: [
                    ChordCue(id: "cue-1", chordID: "c", lyricTokenID: "hello", onsetSeconds: 1),
                    ChordCue(id: "cue-2", chordID: "am", lyricTokenID: "friend", onsetSeconds: 2.5),
                    ChordCue(id: "cue-3", chordID: "c", lyricTokenID: "play", onsetSeconds: 4)
                ])
            ]
        )
    }
}
