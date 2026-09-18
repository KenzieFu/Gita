import Foundation

enum ArrangementTier: String, Codable, CaseIterable, Identifiable {
    case noob
    case guitaristWannabe
    case superstar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .noob: "Easy"
        case .guitaristWannabe: "Medium"
        case .superstar: "Pro"
        }
    }

    /// Presentation label for the selected arrangement, independent of the
    /// imported song's overall authored difficulty.
    var selectionDifficulty: SongDifficulty {
        switch self {
        case .noob: .easy
        case .guitaristWannabe: .medium
        case .superstar: .hard
        }
    }

    var chordLimit: Int? {
        switch self {
        case .noob: 3
        case .guitaristWannabe: 4
        case .superstar: nil
        }
    }

    /// Fixed learning vocabulary for the simplified modes. The raw enum values
    /// stay unchanged so previously exported `.gita.json` files still decode.
    var learningChordIDs: [String]? {
        switch self {
        case .noob: ["C", "G", "Am"]
        case .guitaristWannabe: ["C", "G", "Am", "Dm"]
        case .superstar: nil
        }
    }

    var playXP: Int {
        switch self {
        case .noob: 5
        case .guitaristWannabe: 10
        case .superstar: 20
        }
    }

    var playGems: Int {
        switch self {
        case .noob: 1
        case .guitaristWannabe: 2
        case .superstar: 3
        }
    }
}

struct ChordDefinition: Codable, Hashable, Identifiable {
    var id: String
    var displayName: String
    /// One value per string: nil means muted, 0 means open, and positive values are frets.
    var frets: [Int?]
}

struct TimedLyricToken: Codable, Hashable, Identifiable {
    var id: String
    var text: String
    var startSeconds: Double
    var endSeconds: Double
}

struct TimedLyricLine: Codable, Hashable, Identifiable {
    var id: String
    var sectionID: String
    var tokens: [TimedLyricToken]

    var startSeconds: Double { tokens.first?.startSeconds ?? 0 }
    var endSeconds: Double { tokens.last?.endSeconds ?? 0 }
}

struct ChordCue: Codable, Hashable, Identifiable {
    var id: String
    var chordID: String
    var lyricTokenID: String?
    var onsetSeconds: Double
}

struct SongArrangement: Codable, Hashable, Identifiable {
    var id: String
    var tier: ArrangementTier
    var chordIDs: [String]
    var cues: [ChordCue]
}

struct SongExperience: Codable, Hashable {
    var chords: [ChordDefinition]
    var lyricLines: [TimedLyricLine]
    var arrangements: [SongArrangement]

    var availableTiers: [ArrangementTier] {
        ArrangementTier.allCases.filter { arrangement(for: $0) != nil }
    }
    var defaultTier: ArrangementTier? { availableTiers.contains(.noob) ? .noob : availableTiers.first }

    func arrangement(for tier: ArrangementTier) -> SongArrangement? {
        if let exact = arrangements.first(where: { $0.tier == tier }) {
            if let requiredChordIDs = tier.learningChordIDs {
                let definedChordIDs = Set(chords.map(\.id))
                // Upgrade older saved two/four-chord modes when the chart has
                // the new fixed learning vocabulary available.
                if !requiredChordIDs.allSatisfy(definedChordIDs.contains) || exact.chordIDs == requiredChordIDs {
                    return exact
                }
            } else {
                return exact
            }
        }

        // Imported charts can contain only their full/pro arrangement. Generate
        // the learning modes from that source so every installation gets the
        // same Easy / Medium / Pro choices without duplicating the whole chart.
        guard tier != .superstar else { return nil }
        guard let source = arrangements.first(where: { $0.tier == .superstar })
                ?? arrangements.max(by: { $0.chordIDs.count < $1.chordIDs.count }) else {
            return nil
        }
        guard let learningChordIDs = tier.learningChordIDs else { return nil }

        let definedChordIDs = Set(chords.map(\.id))
        guard learningChordIDs.allSatisfy(definedChordIDs.contains) else { return nil }

        // Preserve each selected cue exactly as authored in the JSON. Chords
        // outside the learning set are omitted; they are never renamed or
        // substituted with one of the easier chords.
        let simplifiedCues = source.cues.filter { cue in
            learningChordIDs.contains(cue.chordID)
        }.map { cue in
            return ChordCue(
                id: "\(tier.rawValue)-\(cue.id)",
                chordID: cue.chordID,
                lyricTokenID: cue.lyricTokenID,
                onsetSeconds: cue.onsetSeconds
            )
        }
        return SongArrangement(
            id: "\(source.id)-\(tier.rawValue)-generated",
            tier: tier,
            chordIDs: learningChordIDs,
            cues: simplifiedCues
        )
    }

    func chord(id: String) -> ChordDefinition? {
        chords.first { $0.id == id }
    }

    func validate(stringCount: Int, duration: Double, sectionIDs: Set<String>) throws {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw SongChartError.invalid(message) }
        }

        let chordIDs = Set(chords.map(\.id))
        let tokens = lyricLines.flatMap(\.tokens)
        let tokenIDs = Set(tokens.map(\.id))
        let tokensByID = tokens.reduce(into: [String: TimedLyricToken]()) { result, token in result[token.id] = token }
        try require(!chords.isEmpty && chordIDs.count == chords.count, "Chord definitions must be unique")
        try require(chords.allSatisfy { !$0.id.isEmpty && !$0.displayName.isEmpty && $0.frets.count == stringCount }, "Invalid chord definition")
        try require(chords.flatMap(\.frets).compactMap { $0 }.allSatisfy { (0...30).contains($0) }, "Invalid chord fret")
        try require(tokenIDs.count == tokens.count, "Lyric tokens must be unique")
        try require(lyricLines.allSatisfy { sectionIDs.contains($0.sectionID) && !$0.tokens.isEmpty }, "Invalid lyric line section")

        for line in lyricLines {
            for token in line.tokens {
                try require(!token.id.isEmpty && !token.text.isEmpty, "Invalid lyric token")
                try require(token.startSeconds.isFinite && token.endSeconds.isFinite && token.startSeconds >= 0 && token.startSeconds < token.endSeconds && token.endSeconds <= duration, "Lyric token outside audio")
            }
            for (previous, next) in zip(line.tokens, line.tokens.dropFirst()) {
                try require(previous.endSeconds <= next.startSeconds, "Overlapping lyric tokens")
            }
        }
        for sectionID in sectionIDs {
            let sectionLines = lyricLines.filter { $0.sectionID == sectionID }.sorted { $0.startSeconds < $1.startSeconds }
            for (previous, next) in zip(sectionLines, sectionLines.dropFirst()) {
                try require(previous.endSeconds <= next.startSeconds, "Overlapping lyric lines")
            }
        }

        try require(Set(arrangements.map(\.id)).count == arrangements.count, "Arrangement IDs must be unique")
        try require(Set(arrangements.map(\.tier)).count == arrangements.count, "Arrangement tiers must be unique")
        for arrangement in arrangements {
            let uniqueChordIDs = Set(arrangement.chordIDs)
            try require(!arrangement.id.isEmpty && !arrangement.cues.isEmpty, "Invalid arrangement")
            try require(uniqueChordIDs.count == arrangement.chordIDs.count && uniqueChordIDs.isSubset(of: chordIDs), "Arrangement references an invalid chord")
            if let limit = arrangement.tier.chordLimit {
                try require(uniqueChordIDs.count <= limit, "Arrangement exceeds its chord limit")
            }
            try require(Set(arrangement.cues.map(\.id)).count == arrangement.cues.count, "Chord cue IDs must be unique")
            for cue in arrangement.cues {
                try require(uniqueChordIDs.contains(cue.chordID), "Chord cue has an invalid chord")
                try require(cue.onsetSeconds.isFinite && cue.onsetSeconds >= 0 && cue.onsetSeconds <= duration, "Chord cue outside audio")
                if let lyricTokenID = cue.lyricTokenID {
                    try require(tokenIDs.contains(lyricTokenID), "Chord cue has an invalid lyric reference")
                }
                if let lyricTokenID = cue.lyricTokenID, let token = tokensByID[lyricTokenID] {
                    try require(cue.onsetSeconds >= token.startSeconds && cue.onsetSeconds < token.endSeconds, "Chord cue does not align with its lyric token")
                }
            }
            for (previous, next) in zip(arrangement.cues, arrangement.cues.dropFirst()) {
                try require(previous.onsetSeconds <= next.onsetSeconds, "Chord cues out of order")
            }
        }
    }
}

struct LyricTimeline {
    let experience: SongExperience
    let arrangement: SongArrangement

    func lines(in sectionID: String) -> [TimedLyricLine] {
        experience.lyricLines.filter { $0.sectionID == sectionID }.sorted { $0.startSeconds < $1.startSeconds }
    }

    func activeLineID(in sectionID: String, at time: Double) -> String? {
        lines(in: sectionID).first { $0.startSeconds <= time && time < $0.endSeconds }?.id
    }

    func activeTokenID(at time: Double) -> String? {
        experience.lyricLines.lazy.flatMap(\.tokens).first {
            time >= $0.startSeconds && time < $0.endSeconds
        }?.id
    }

    func activeLine(at time: Double) -> TimedLyricLine? {
        experience.lyricLines.first { time >= $0.startSeconds && time < $0.endSeconds }
    }

    func currentCue(at time: Double) -> ChordCue? {
        arrangement.cues.last { $0.onsetSeconds <= time }
    }

    func nextCue(after time: Double) -> ChordCue? {
        arrangement.cues.first { $0.onsetSeconds > time }
    }
}

struct ChordCueJudgement: Equatable {
    let cueID: String
    let grade: PracticeGrade
    let timingError: Double?
    let points: Int
}

enum ChordCueJudge {
    static func judge(cue: ChordCue, detectedChordID: String?, detectedAt time: Double?) -> ChordCueJudgement {
        guard let detectedChordID, let time, detectedChordID == cue.chordID else {
            return ChordCueJudgement(cueID: cue.id, grade: .miss, timingError: nil, points: 0)
        }
        let error = time - cue.onsetSeconds
        let magnitude = abs(error)
        let grade: PracticeGrade
        let points: Int
        switch magnitude {
        case ...0.09: (grade, points) = (.perfect, 100)
        case ...0.17: (grade, points) = (.great, 80)
        case ...0.32: (grade, points) = (.good, 55)
        default: (grade, points) = (.miss, 0)
        }
        return ChordCueJudgement(cueID: cue.id, grade: grade, timingError: error, points: points)
    }

    static func score(_ judgements: [ChordCueJudgement]) -> Int {
        guard !judgements.isEmpty else { return 0 }
        return Int((Double(judgements.map(\.points).reduce(0, +)) / Double(judgements.count)).rounded())
    }
}
