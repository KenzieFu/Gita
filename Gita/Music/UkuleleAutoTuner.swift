import Foundation

enum UkuleleTunerStatus: Equatable {
    case listening
    case ambiguous
    case tryAgain
    case tracking
}

struct UkuleleTunerFeedback {
    let status: UkuleleTunerStatus
    let detectedNote: String?
    let confirmedTuning: UkuleleTuning?
    let stringIndex: Int?
    let cents: Double?
    let completed: Set<Int>
    let newlyTuned: Set<Int>
    let needsTopStringPrompt: Bool

    var finishedNow: Bool { completed.count == 4 && !newlyTuned.isEmpty }
}

struct UkuleleAutoTuner {
    private(set) var confirmedTuning: UkuleleTuning?
    private var candidates: Set<UkuleleTuning>
    private var completed: Set<Int>
    private var acceptedTargets: Set<StringTarget> = []
    private var pendingTuned: Set<StringTarget> = []

    private var activeTarget: StringTarget?
    private var lastMeasuredFrequency: Double?
    private var consistentReadings = 0
    private var recentCents: [Double] = []
    private var lastDisplayAt: TimeInterval?
    private var lastDisplay: UkuleleTunerFeedback?

    private var validDuration = 0.0
    private var lastValidAt: TimeInterval?
    private var invalidSince: TimeInterval?

    init(confirmedTuning: UkuleleTuning? = nil, completed: Set<Int> = []) {
        self.confirmedTuning = confirmedTuning
        self.candidates = confirmedTuning.map { [$0] } ?? Set(UkuleleTuning.allCases)
        self.completed = completed
    }

    mutating func ingest(_ reading: PitchReading?, gEvidence: GOctaveEvidence?, at time: TimeInterval) -> UkuleleTunerFeedback {
        guard let reading, reading.clarity >= 0.84, reading.frequency.isFinite, reading.frequency > 0 else {
            pause(at: time)
            if let lastDisplayAt, time - lastDisplayAt <= 0.25, let lastDisplay {
                return feedback(status: lastDisplay.status, note: lastDisplay.detectedNote, target: activeTarget, cents: lastDisplay.cents, newlyTuned: [])
            }
            return feedback(status: .listening, note: nil, target: nil, cents: nil, newlyTuned: [])
        }

        guard let frequency = resolvedFrequency(reading.frequency, gEvidence: gEvidence) else {
            pause(at: time)
            if let lastDisplayAt, time - lastDisplayAt <= 0.25, let lastDisplay {
                return feedback(status: lastDisplay.status, note: lastDisplay.detectedNote, target: activeTarget, cents: lastDisplay.cents, newlyTuned: [])
            }
            clearActiveTarget()
            return feedback(status: .ambiguous, note: noteName(reading.frequency), target: nil, cents: nil, newlyTuned: [], promptTopString: true)
        }

        let targetMatches = Set(candidates.flatMap { $0.openStrings })
            .map { target in (target, PitchDetector.cents(frequency, target: target.frequency)) }
            .filter { abs($0.1) <= 80 }
            .sorted { abs($0.1) < abs($1.1) }
        guard let match = targetMatches.first else {
            clearActiveTarget()
            return feedback(status: .tryAgain, note: noteName(frequency), target: nil, cents: nil, newlyTuned: [])
        }
        if targetMatches.count > 1, abs(abs(match.1) - abs(targetMatches[1].1)) < 20 {
            clearActiveTarget()
            return feedback(status: .ambiguous, note: noteName(frequency), target: nil, cents: nil, newlyTuned: [], promptTopString: true)
        }

        let target = match.0
        if activeTarget != target {
            activeTarget = target
            lastMeasuredFrequency = nil
            consistentReadings = 0
            recentCents = []
            resetHold()
        }

        if let lastMeasuredFrequency,
           abs(PitchDetector.cents(frequency, target: lastMeasuredFrequency)) <= 20 {
            consistentReadings += 1
        } else {
            consistentReadings = 1
        }
        lastMeasuredFrequency = frequency

        recentCents.append(match.1)
        if recentCents.count > 5 { recentCents.removeFirst() }
        let smoothedCents = recentCents.sorted()[recentCents.count / 2]
        var newlyTuned: Set<Int> = []

        if consistentReadings >= 2, abs(match.1) <= 20 {
            newlyTuned.formUnion(accept(target, frequency: frequency))
        }

        if abs(match.1) <= TuningZone.inTuneCents {
            if accumulateValidTime(at: time) {
                if let confirmedTuning,
                   let index = confirmedTuning.openStrings.firstIndex(of: target) {
                    if completed.insert(index).inserted { newlyTuned.insert(index) }
                } else {
                    pendingTuned.insert(target)
                }
            }
        } else {
            resetHold()
        }

        let result = feedback(status: .tracking, note: target.noteLabel, target: target, cents: smoothedCents, newlyTuned: newlyTuned)
        lastDisplay = result
        lastDisplayAt = time
        return result
    }

    private mutating func accept(_ target: StringTarget, frequency: Double) -> Set<Int> {
        let supporting = Set(UkuleleTuning.allCases.filter { tuning in
            guard let index = index(in: tuning, for: frequency) else { return false }
            return abs(PitchDetector.cents(frequency, target: tuning.openStrings[index].frequency)) <= 20
        })
        let narrowed = candidates.intersection(supporting)
        guard !narrowed.isEmpty else { return [] }
        candidates = narrowed
        acceptedTargets.insert(target)
        guard confirmedTuning == nil, candidates.count == 1, acceptedTargets.count >= 2,
              let selected = candidates.first else { return [] }
        confirmedTuning = selected
        var newlyTuned: Set<Int> = []
        for pending in pendingTuned {
            if let index = selected.openStrings.firstIndex(of: pending), completed.insert(index).inserted {
                newlyTuned.insert(index)
            }
        }
        pendingTuned = []
        return newlyTuned
    }

    private func index(in tuning: UkuleleTuning, for frequency: Double) -> Int? {
        tuning.openStrings.enumerated()
            .map { ($0.offset, abs(PitchDetector.cents(frequency, target: $0.element.frequency))) }
            .filter { $0.1 <= 80 }
            .min { $0.1 < $1.1 }?.0
    }

    private func resolvedFrequency(_ frequency: Double, gEvidence: GOctaveEvidence?) -> Double? {
        let nearG = [196.0, 392.0].contains { abs(PitchDetector.cents(frequency, target: $0)) <= 80 }
        guard nearG else { return frequency }
        switch gEvidence {
        case .low: return frequency > 280 ? frequency / 2 : frequency
        case .high: return frequency < 280 ? frequency * 2 : frequency
        case .uncertain, nil: return nil
        }
    }

    private mutating func accumulateValidTime(at time: TimeInterval) -> Bool {
        if let invalidSince {
            if time - invalidSince > 0.2 {
                resetHold()
            } else if let lastValidAt {
                validDuration += max(0, invalidSince - lastValidAt)
            }
        } else if let lastValidAt {
            if time - lastValidAt > 0.3 {
                resetHold()
            } else {
                validDuration += max(0, time - lastValidAt)
            }
        }
        invalidSince = nil
        lastValidAt = time
        return validDuration >= 0.5
    }

    private mutating func pause(at time: TimeInterval) {
        if invalidSince == nil { invalidSince = time }
        if time - (invalidSince ?? time) > 0.2 {
            resetHold()
            clearActiveTarget()
        }
    }

    private mutating func resetHold() {
        validDuration = 0
        lastValidAt = nil
        invalidSince = nil
    }

    private mutating func clearActiveTarget() {
        activeTarget = nil
        lastMeasuredFrequency = nil
        consistentReadings = 0
        recentCents = []
        resetHold()
    }

    private func feedback(status: UkuleleTunerStatus, note: String?, target: StringTarget?, cents: Double?, newlyTuned: Set<Int>, promptTopString: Bool = false) -> UkuleleTunerFeedback {
        let index = confirmedTuning.flatMap { tuning in target.flatMap { tuning.openStrings.firstIndex(of: $0) } }
        return UkuleleTunerFeedback(
            status: status,
            detectedNote: note,
            confirmedTuning: confirmedTuning,
            stringIndex: index,
            cents: cents,
            completed: completed,
            newlyTuned: newlyTuned,
            needsTopStringPrompt: promptTopString || (confirmedTuning == nil && acceptedTargets.count >= 2 && candidates.count > 1)
        )
    }

    private func noteName(_ frequency: Double) -> String {
        let midi = Int((69 + 12 * log2(frequency / 440)).rounded())
        let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
        return "\(names[(midi % 12 + 12) % 12])\(midi / 12 - 1)"
    }
}
