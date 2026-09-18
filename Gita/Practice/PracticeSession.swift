import Foundation

enum PracticeGrade: String, Codable {
    case perfect
    case great
    case good
    case miss
}

struct PracticeHit: Codable, Equatable {
    let noteID: Int
    let grade: PracticeGrade
    let timingError: Double?
}

struct PracticeTake: Codable, Identifiable {
    let id: UUID
    let chartID: String
    let playedAt: Date
    let speed: Double
    let noteCount: Int
    let hits: [PracticeHit]

    var hitCount: Int { hits.filter { $0.grade != .miss }.count }
    var accuracy: Double { noteCount == 0 ? 0 : Double(hitCount) / Double(noteCount) }
}

struct PracticeSession {
    let chart: PracticeChart
    let speed: Double
    private(set) var loopStartBeat: Double = 0
    private(set) var loopEndBeat: Double
    private(set) var hits: [PracticeHit] = []
    private(set) var isComplete = false
    private var startedAt: Double?

    init(chart: PracticeChart, speed: Double) {
        precondition(speed > 0)
        self.chart = chart
        self.speed = speed
        self.loopEndBeat = chart.totalBeats
    }

    var secondsPerBeat: Double { 60 / (chart.bpm * speed) }
    var activeNotes: [PracticeNote] { chart.notes.filter { $0.beat >= loopStartBeat && $0.beat < loopEndBeat } }

    mutating func start(at time: Double) {
        startedAt = time
        hits = []
        isComplete = false
    }

    mutating func restart(at time: Double) { start(at: time) }

    mutating func setLoop(startBeat: Double, endBeat: Double, at time: Double) {
        precondition(startBeat >= 0 && endBeat > startBeat && endBeat <= chart.totalBeats)
        loopStartBeat = startBeat
        loopEndBeat = endBeat
        start(at: time)
    }

    func currentBeat(at time: Double) -> Double {
        guard let startedAt else { return loopStartBeat }
        let progressed = max(0, (time - startedAt) / secondsPerBeat)
        return min(loopEndBeat, loopStartBeat + progressed)
    }

    @discardableResult mutating func observe(frequency: Double, at time: Double) -> PracticeHit? {
        guard frequency.isFinite && frequency > 0 else { return nil }
        advance(to: time)
        guard let startedAt, !isComplete else { return nil }
        let candidate = activeNotes
            .filter { note in
                !hits.contains(where: { $0.noteID == note.id }) &&
                activeNotes.filter { $0.beat == note.beat }.count == 1 &&
                abs(time - expectedTime(for: note, startedAt: startedAt)) <= 0.35 &&
                abs(PitchDetector.cents(frequency, target: chart.frequency(for: note))) <= 40
            }
            .min { left, right in
                abs(time - expectedTime(for: left, startedAt: startedAt)) < abs(time - expectedTime(for: right, startedAt: startedAt))
            }
        guard let note = candidate else { return nil }
        let error = time - expectedTime(for: note, startedAt: startedAt)
        let hit = PracticeHit(noteID: note.id, grade: Self.grade(for: error), timingError: error)
        hits.append(hit)
        return hit
    }

    @discardableResult mutating func observeChord(samples: [Float], sampleRate: Double, at time: Double) -> [PracticeHit]? {
        advance(to: time)
        guard let startedAt, !isComplete else { return nil }
        let groups = Dictionary(grouping: activeNotes, by: \.beat)
        guard let group = groups.values
            .filter({ notes in
                notes.count >= 3 &&
                notes.allSatisfy { note in !hits.contains(where: { $0.noteID == note.id }) } &&
                abs(time - expectedTime(for: notes[0], startedAt: startedAt)) <= 0.35
            })
            .min(by: {
                abs(time - expectedTime(for: $0[0], startedAt: startedAt)) < abs(time - expectedTime(for: $1[0], startedAt: startedAt))
            }) else { return nil }
        guard ChordMatcher.matches(samples, sampleRate: sampleRate, targets: group.map { chart.frequency(for: $0) }) else { return nil }
        let error = time - expectedTime(for: group[0], startedAt: startedAt)
        let grade = Self.grade(for: error)
        let chordHits = group.map { PracticeHit(noteID: $0.id, grade: grade, timingError: error) }
        hits.append(contentsOf: chordHits)
        return chordHits
    }

    mutating func advance(to time: Double) {
        guard let startedAt, !isComplete else { return }
        for note in activeNotes where !hits.contains(where: { $0.noteID == note.id }) {
            if time > expectedTime(for: note, startedAt: startedAt) + 0.35 {
                hits.append(PracticeHit(noteID: note.id, grade: .miss, timingError: nil))
            }
        }
        let endTime = startedAt + (loopEndBeat - loopStartBeat) * secondsPerBeat
        if time > endTime + 0.35 { isComplete = true }
    }

    func makeTake(playedAt: Date) -> PracticeTake? {
        guard isComplete else { return nil }
        return PracticeTake(id: UUID(), chartID: chart.id, playedAt: playedAt, speed: speed, noteCount: activeNotes.count, hits: hits)
    }

    private func expectedTime(for note: PracticeNote, startedAt: Double) -> Double {
        startedAt + (note.beat - loopStartBeat) * secondsPerBeat
    }

    private static func grade(for timingError: Double) -> PracticeGrade {
        switch abs(timingError) {
        case ...0.09: .perfect
        case ...0.17: .great
        case ...0.32: .good
        default: .miss
        }
    }
}
