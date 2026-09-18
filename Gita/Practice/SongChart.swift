import Foundation

enum SongPlayStyle: String, Codable {
    case singleNote
    case basicStrum
}

enum SongDifficulty: String, Codable {
    case easy
    case medium
    case hard
}

struct SongNote: Codable, Hashable, Identifiable {
    var id: String
    var onsetSeconds: Double
    var durationSeconds: Double
    var stringIndex: Int
    var fret: Int
}

struct SongSection: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var startSeconds: Double
    var endSeconds: Double
}

enum SongChartError: Error {
    case invalid(String)
}

struct SongChart: Codable, Identifiable {
    var schemaVersion: Int
    var id: String
    var version: Int
    var title: String
    var style: SongPlayStyle
    var difficulty: SongDifficulty
    var chordNames: [String]
    var instrument: Instrument
    var stringLabels: [String]
    var openFrequencies: [Double]
    var maxFret: Int
    var nominalBPM: Double
    var beatsPerBar: Int
    var firstBeatOffsetSeconds: Double
    var audioDurationSeconds: Double
    var audioSHA256: String
    var notes: [SongNote]
    var sections: [SongSection]
    var experience: SongExperience? = nil

    static func decodeValidated(_ data: Data) throws -> SongChart {
        let chart = try JSONDecoder().decode(SongChart.self, from: data)
        try chart.validate()
        return chart
    }

    func section(id sectionID: String) -> SongSection? {
        sections.first { $0.id == sectionID }
    }

    /// Normal song play always uses the entire imported audio timeline. Saved
    /// sections remain available to future focused-practice features.
    var fullSongSection: SongSection {
        SongSection(id: "__full-song__", title: "Full Song", startSeconds: 0, endSeconds: audioDurationSeconds)
    }

    func practiceChart() -> PracticeChart {
        PracticeChart(
            id: "\(id)-v\(version)",
            title: title,
            bpm: nominalBPM,
            beatsPerBar: beatsPerBar,
            notes: notes.enumerated().map { index, note in
                PracticeNote(
                    id: index,
                    beat: note.onsetSeconds * nominalBPM / 60,
                    stringIndex: note.stringIndex,
                    fret: note.fret,
                    lengthBeats: note.durationSeconds * nominalBPM / 60
                )
            },
            stringLabels: stringLabels,
            openFrequencies: openFrequencies
        )
    }

    func practiceChart(experience: SongExperience, arrangement: SongArrangement) -> PracticeChart {
        let practiceNotes = arrangement.cues.flatMap { cue -> [(Double, Int, Int)] in
            guard let chord = experience.chord(id: cue.chordID) else { return [] }
            return chord.frets.enumerated().compactMap { stringIndex, fret in
                fret.map { (cue.onsetSeconds, stringIndex, $0) }
            }
        }
        return PracticeChart(
            id: "\(id)-v\(version)-\(arrangement.id)",
            title: title,
            bpm: nominalBPM,
            beatsPerBar: beatsPerBar,
            notes: practiceNotes.enumerated().map { index, item in
                PracticeNote(id: index, beat: item.0 * nominalBPM / 60, stringIndex: item.1, fret: item.2, lengthBeats: 0.35 * nominalBPM / 60)
            },
            stringLabels: stringLabels,
            openFrequencies: openFrequencies
        )
    }

    func validate() throws {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw SongChartError.invalid(message) }
        }

        try require((1...2).contains(schemaVersion), "Unsupported chart schema")
        try require(!id.isEmpty && !id.contains("/") && !id.contains("\\") && id != "." && id != "..", "Invalid chart ID")
        try require(version > 0 && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Invalid version or title")
        try require(stringLabels.count == instrument.stringCount && openFrequencies.count == instrument.stringCount, "Wrong lane count")
        try require(stringLabels.allSatisfy { !$0.isEmpty } && openFrequencies.allSatisfy { $0.isFinite && $0 > 0 }, "Invalid tuning")
        try require((1...30).contains(maxFret) && nominalBPM.isFinite && nominalBPM > 0, "Invalid fret limit or tempo")
        try require((1...12).contains(beatsPerBar), "Invalid beat grouping")
        try require(audioDurationSeconds.isFinite && audioDurationSeconds > 0, "Invalid audio duration")
        try require(firstBeatOffsetSeconds.isFinite && firstBeatOffsetSeconds >= 0 && firstBeatOffsetSeconds < audioDurationSeconds, "Invalid first beat")
        try require(audioSHA256.count == 64 && audioSHA256.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }, "Invalid audio digest")
        try require(!notes.isEmpty && !sections.isEmpty, "Chart needs notes and sections")
        try require(chordNames.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }, "Invalid chord name")
        try require(Set(chordNames).count == chordNames.count, "Duplicate chord name")
        try require(style == .basicStrum || chordNames.isEmpty, "Single-note chart cannot advertise chords")
        try require(style == .singleNote || !chordNames.isEmpty, "Basic strum chart needs authored chord names")
        try require(Set(notes.map(\.id)).count == notes.count && notes.allSatisfy { !$0.id.isEmpty }, "Duplicate note ID")
        try require(Set(sections.map(\.id)).count == sections.count && sections.allSatisfy { !$0.id.isEmpty }, "Duplicate section ID")

        for note in notes {
            try require(note.onsetSeconds.isFinite && note.durationSeconds.isFinite && note.onsetSeconds >= 0 && note.durationSeconds > 0 && note.onsetSeconds + note.durationSeconds <= audioDurationSeconds, "Note outside audio")
            try require(stringLabels.indices.contains(note.stringIndex) && (0...maxFret).contains(note.fret), "Invalid string or fret")
        }
        for (previous, next) in zip(notes, notes.dropFirst()) {
            try require(previous.onsetSeconds <= next.onsetSeconds, "Notes out of order")
            if style == .singleNote {
                try require(previous.onsetSeconds + previous.durationSeconds <= next.onsetSeconds, "Overlapping single notes")
            }
        }
        for section in sections {
            try require(!section.id.isEmpty && !section.title.isEmpty && section.startSeconds.isFinite && section.endSeconds.isFinite, "Invalid section")
            try require(section.startSeconds >= 0 && section.startSeconds < section.endSeconds && section.endSeconds <= audioDurationSeconds, "Section outside audio")
            try require(notes.contains { $0.onsetSeconds >= section.startSeconds && $0.onsetSeconds < section.endSeconds }, "Empty section")
        }
        if schemaVersion == 2 {
            guard let experience else { throw SongChartError.invalid("Schema 2 needs a song experience") }
            try experience.validate(stringCount: instrument.stringCount, duration: audioDurationSeconds, sectionIDs: Set(sections.map(\.id)))
        }
    }
}
