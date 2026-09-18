import Foundation

/// One short cue adapted to the same chart/timeline used by song gameplay.
enum TutorialPlayChart {
    static func make(for instrument: Instrument, tuning: UkuleleTuning?, target: LessonTarget) -> SongChart {
        let strings = instrument.tuningTargets(tuning ?? .highG)
        let labels = strings.map(\.label)
        let stringIndex = labels.lastIndex(of: target.stringLabel) ?? max(0, labels.count - 1)
        var frets: [Int?] = Array(repeating: nil, count: labels.count)
        if target.kind == .chord {
            if instrument == .guitar {
                frets = [0, 2, 2, 0, 0, 0]
            } else {
                frets = [0, 0, 0, 3]
            }
        } else {
            frets[stringIndex] = target.fret ?? 0
        }
        let name = target.kind == .chord
            ? "\(instrument == .guitar ? "Em" : (tuning == .baritone ? "G" : "C")) CHORD"
            : "\(target.stringLabel) · FRET \(target.fret ?? 0)"
        let chord = ChordDefinition(id: "lesson", displayName: name, frets: frets)
        let notes = frets.enumerated().compactMap { index, fret -> SongNote? in
            guard let fret else { return nil }
            return SongNote(id: "lesson-\(index)", onsetSeconds: 4, durationSeconds: 0.35, stringIndex: index, fret: fret)
        }
        return SongChart(
            schemaVersion: 2,
            id: "tutorial-\(instrument.rawValue)-\(target.kind.rawValue)",
            version: 1,
            title: target.title,
            style: .basicStrum,
            difficulty: .easy,
            chordNames: [name],
            instrument: instrument,
            stringLabels: labels,
            openFrequencies: strings.map(\.frequency),
            maxFret: 12,
            nominalBPM: 120,
            beatsPerBar: 4,
            firstBeatOffsetSeconds: 0,
            audioDurationSeconds: 8,
            audioSHA256: String(repeating: "0", count: 64),
            notes: notes,
            sections: [SongSection(id: "tutorial", title: "Tutorial", startSeconds: 0, endSeconds: 8)],
            experience: SongExperience(
                chords: [chord],
                lyricLines: [],
                arrangements: [SongArrangement(
                    id: "lesson-pro",
                    tier: .superstar,
                    chordIDs: ["lesson"],
                    cues: [ChordCue(id: "lesson-cue", chordID: "lesson", lyricTokenID: nil, onsetSeconds: 4)]
                )]
            )
        )
    }
}
