import Foundation

/// A provisional, private chart for the user-supplied recording. Word timings should be
/// refined in a chart editor before any scored or public release.
enum CountOnMePrototype {
    static let audioResourceName = "count-on-me-prototype"

    private struct LineSpec {
        let id: String
        let sectionID: String
        let text: String
        let start: Double
        let end: Double
        let changes: [(word: Int, chord: String)]
    }

    static func makeChart() -> SongChart {
        let chords = [
            ChordDefinition(id: "C", displayName: "C", frets: [0, 0, 0, 3]),
            ChordDefinition(id: "Em", displayName: "Em", frets: [0, 4, 3, 2]),
            ChordDefinition(id: "Am", displayName: "Am", frets: [2, 0, 0, 0]),
            ChordDefinition(id: "G", displayName: "G", frets: [0, 2, 3, 2]),
            ChordDefinition(id: "F", displayName: "F", frets: [2, 0, 1, 0]),
            ChordDefinition(id: "Dm", displayName: "Dm", frets: [2, 2, 1, 0])
        ]
        let sections = [
            SongSection(id: "verse-1", title: "Verse 1 · timing draft", startSeconds: 11, endSeconds: 39),
            SongSection(id: "pre-chorus", title: "Pre-chorus · timing draft", startSeconds: 39, endSeconds: 51),
            SongSection(id: "chorus", title: "Chorus · timing draft", startSeconds: 51, endSeconds: 97)
        ]
        let lines: [LineSpec] = [
            .init(id: "v1-1", sectionID: "verse-1", text: "If you ever find yourself stuck in the middle of the sea", start: 12, end: 19, changes: [(0, "C"), (10, "Em")]),
            .init(id: "v1-2", sectionID: "verse-1", text: "I'll sail the world to find you", start: 19, end: 25, changes: [(0, "Am"), (3, "G"), (5, "F")]),
            .init(id: "v1-3", sectionID: "verse-1", text: "If you ever find yourself lost in the dark and you can't see", start: 25, end: 33, changes: [(0, "C"), (12, "Em")]),
            .init(id: "v1-4", sectionID: "verse-1", text: "I'll be the light to guide you", start: 33, end: 39, changes: [(0, "Am"), (4, "G"), (6, "F")]),
            .init(id: "pre-1", sectionID: "pre-chorus", text: "Find out what we're made of", start: 39, end: 44, changes: [(0, "Dm"), (5, "Em")]),
            .init(id: "pre-2", sectionID: "pre-chorus", text: "When we are called to help our friends in need", start: 44, end: 51, changes: [(0, "F"), (9, "G")]),
            .init(id: "ch-1", sectionID: "chorus", text: "You can count on me like one two three", start: 51, end: 58, changes: [(0, "C"), (5, "Em")]),
            .init(id: "ch-2", sectionID: "chorus", text: "I'll be there", start: 58, end: 61, changes: [(0, "Am"), (2, "G")]),
            .init(id: "ch-3", sectionID: "chorus", text: "And I know when I need it", start: 61, end: 66, changes: [(0, "F")]),
            .init(id: "ch-4", sectionID: "chorus", text: "I can count on you like four three two", start: 66, end: 74, changes: [(0, "C"), (6, "Em")]),
            .init(id: "ch-5", sectionID: "chorus", text: "And you'll be there", start: 74, end: 77, changes: [(0, "Am"), (3, "G")]),
            .init(id: "ch-6", sectionID: "chorus", text: "'cos that's what friends are s'posed to do", start: 77, end: 85, changes: [(0, "F")]),
            .init(id: "ch-7", sectionID: "chorus", text: "Oh yeah", start: 85, end: 88, changes: [(0, "C")]),
            .init(id: "ch-8", sectionID: "chorus", text: "Ooh ooh ooh ooh ooh", start: 88, end: 97, changes: [(0, "Em"), (3, "Am"), (4, "G")])
        ]

        var lyricLines: [TimedLyricLine] = []
        var superstarCues: [ChordCue] = []
        for line in lines {
            let words = line.text.split(separator: " ").map(String.init)
            let wordDuration = (line.end - line.start) / Double(words.count)
            let tokens = words.enumerated().map { index, word in
                TimedLyricToken(
                    id: "\(line.id)-w\(index)",
                    text: word,
                    startSeconds: line.start + Double(index) * wordDuration,
                    endSeconds: line.start + Double(index + 1) * wordDuration
                )
            }
            lyricLines.append(TimedLyricLine(id: line.id, sectionID: line.sectionID, tokens: tokens))
            for change in line.changes where tokens.indices.contains(change.word) {
                let token = tokens[change.word]
                superstarCues.append(ChordCue(
                    id: "superstar-\(token.id)",
                    chordID: change.chord,
                    lyricTokenID: token.id,
                    onsetSeconds: token.startSeconds
                ))
            }
        }

        func arrangement(_ tier: ArrangementTier, chordIDs: [String]) -> SongArrangement {
            SongArrangement(
                id: tier.rawValue,
                tier: tier,
                chordIDs: chordIDs,
                cues: superstarCues.filter { chordIDs.contains($0.chordID) }.map { cue in
                    ChordCue(id: "\(tier.rawValue)-\(cue.lyricTokenID ?? cue.id)", chordID: cue.chordID, lyricTokenID: cue.lyricTokenID, onsetSeconds: cue.onsetSeconds)
                }
            )
        }
        let arrangements = [
            arrangement(.noob, chordIDs: ["C", "G", "Am"]),
            arrangement(.guitaristWannabe, chordIDs: ["C", "G", "Am", "Dm"]),
            arrangement(.superstar, chordIDs: ["C", "Em", "Am", "G", "F", "Dm"])
        ]

        let notes: [SongNote] = superstarCues.flatMap { cue -> [SongNote] in
            guard let chord = chords.first(where: { $0.id == cue.chordID }) else { return [] }
            return chord.frets.enumerated().compactMap { stringIndex, fret in
                guard let fret else { return nil }
                return SongNote(id: "\(cue.id)-s\(stringIndex)", onsetSeconds: cue.onsetSeconds, durationSeconds: 0.35, stringIndex: stringIndex, fret: fret)
            }
        }

        return SongChart(
            schemaVersion: 2,
            id: "count-on-me-local-prototype",
            version: 1,
            title: "Count on Me · Prototype",
            style: .basicStrum,
            difficulty: .easy,
            chordNames: chords.map(\.displayName),
            instrument: .ukulele,
            stringLabels: ["G", "C", "E", "A"],
            openFrequencies: [392, 261.63, 329.63, 440],
            maxFret: 12,
            nominalBPM: 88,
            beatsPerBar: 4,
            firstBeatOffsetSeconds: 1.06,
            audioDurationSeconds: 197.736979,
            audioSHA256: "99ea24ecb040b42b1079d350de6764ec051fede6d1120c5cdd2aef22bec3f5f0",
            notes: notes,
            sections: sections,
            experience: SongExperience(chords: chords, lyricLines: lyricLines, arrangements: arrangements)
        )
    }
}
