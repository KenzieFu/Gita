import Foundation

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

/// Presentation events use the selected arrangement's source-audio timestamps,
/// never an inferred lyric clock or rounded beat positions.
struct RhythmEvent: Identifiable {
    let id: String
    let onset: Double
    let name: String
    let frets: [Int?]
}

struct RhythmTimeline {
    let events: [RhythmEvent]

    init(chart: SongChart, tier: ArrangementTier, section: SongSection) {
        if let experience = chart.experience, let arrangement = experience.arrangement(for: tier) {
            events = arrangement.cues.filter {
                $0.onsetSeconds >= section.startSeconds && $0.onsetSeconds < section.endSeconds
            }.sorted { $0.onsetSeconds < $1.onsetSeconds }.compactMap { cue in
                guard let chord = experience.chord(id: cue.chordID) else { return nil }
                return RhythmEvent(id: cue.id, onset: cue.onsetSeconds, name: chord.displayName, frets: chord.frets)
            }
        } else {
            let groups = Dictionary(grouping: chart.notes.filter {
                $0.onsetSeconds >= section.startSeconds && $0.onsetSeconds < section.endSeconds
            }, by: \.onsetSeconds)
            events = groups.keys.sorted().map { onset in
                let notes = groups[onset]!.sorted { $0.stringIndex < $1.stringIndex }
                var frets = [Int?](repeating: nil, count: chart.stringLabels.count)
                for note in notes where frets.indices.contains(note.stringIndex) { frets[note.stringIndex] = note.fret }
                let name: String
                if notes.count == 1, let note = notes.first {
                    name = "\(chart.stringLabels[safe: note.stringIndex] ?? "String") · \(note.fret)"
                } else {
                    name = "STRUM"
                }
                return RhythmEvent(id: notes[0].id, onset: onset, name: name, frets: frets)
            }
        }
    }

    func targetIndex(at position: Double, rate: Double) -> Int? {
        // Keep the target visible for the same late window used by the judge.
        events.firstIndex { $0.onset + 0.35 * rate >= position }
    }

    static func approach(onset: Double, position: Double, rate: Double) -> Double {
        1 - (onset - position) / (4 * max(0.01, rate))
    }
}

struct RhythmPerformance {
    let accuracy: Double?
    let combo: Int

    init(session: PracticeSession?) {
        guard let session, !session.hits.isEmpty else { accuracy = nil; combo = 0; return }
        accuracy = Double(session.hits.filter { $0.grade != .miss }.count) / Double(session.hits.count)
        let hits = Dictionary(uniqueKeysWithValues: session.hits.map { ($0.noteID, $0) })
        let groups = Dictionary(grouping: session.activeNotes, by: \.beat)
        var streak = 0
        for beat in groups.keys.sorted() {
            let notes = groups[beat]!
            guard notes.allSatisfy({ hits[$0.id] != nil }) else { break }
            streak = notes.allSatisfy { hits[$0.id]?.grade != .miss } ? streak + 1 : 0
        }
        combo = streak
    }
}
