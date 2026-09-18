import Foundation

struct PracticeNote: Codable, Hashable, Identifiable {
    let id: Int
    let beat: Double
    let stringIndex: Int
    let fret: Int
    let lengthBeats: Double
}

struct PracticeChart: Codable {
    let id: String
    let title: String
    let bpm: Double
    let beatsPerBar: Int
    let notes: [PracticeNote]
    let stringLabels: [String]
    let openFrequencies: [Double]

    init(id: String, title: String, bpm: Double, beatsPerBar: Int, notes: [PracticeNote], stringLabels: [String], openFrequencies: [Double]) {
        precondition(bpm > 0 && beatsPerBar > 0)
        precondition(!notes.isEmpty && stringLabels.count == openFrequencies.count)
        precondition(notes.allSatisfy { $0.beat >= 0 && $0.lengthBeats > 0 && $0.fret >= 0 && stringLabels.indices.contains($0.stringIndex) })
        precondition(zip(notes, notes.dropFirst()).allSatisfy { $0.beat <= $1.beat })
        self.id = id
        self.title = title
        self.bpm = bpm
        self.beatsPerBar = beatsPerBar
        self.notes = notes
        self.stringLabels = stringLabels
        self.openFrequencies = openFrequencies
    }

    var totalBeats: Double { (notes.last?.beat ?? 0) + (notes.last?.lengthBeats ?? 0) }

    func frequency(for note: PracticeNote) -> Double {
        openFrequencies[note.stringIndex] * pow(2, Double(note.fret) / 12)
    }

    static func starter(for instrument: Instrument, tuning: UkuleleTuning?) -> PracticeChart? {
        let targets = instrument.tuningTargets(tuning)
        guard targets.count == instrument.stringCount else { return nil }
        let pattern: [(Int, Int)] = instrument == .ukulele
            ? [(3, 0), (3, 3), (2, 0), (1, 0)]
            : [(5, 0), (5, 1), (4, 0), (3, 0)]
        var notes = (0..<16).map { index in
            let (stringIndex, fret) = pattern[index % pattern.count]
            return PracticeNote(id: index, beat: Double(index), stringIndex: stringIndex, fret: fret, lengthBeats: 1)
        }
        let finalChord = instrument == .ukulele ? [0, 0, 0, 3] : [0, 2, 2, 0, 0, 0]
        notes += finalChord.enumerated().map { lane, fret in
            PracticeNote(id: 16 + lane, beat: 16, stringIndex: lane, fret: fret, lengthBeats: 1)
        }
        return PracticeChart(
            id: instrument == .ukulele ? "original-ukulele-starter-\(tuning!.rawValue)" : "original-guitar-starter",
            title: "First Light",
            bpm: 80,
            beatsPerBar: 4,
            notes: notes,
            stringLabels: targets.map(\.label),
            openFrequencies: targets.map(\.frequency)
        )
    }
}
