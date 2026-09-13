import Foundation

struct LessonJudge {
    private var previousRMS = 0.0

    mutating func matches(_ samples: [Float], sampleRate: Double, target: LessonTarget) -> Bool {
        guard !samples.isEmpty else { return false }
        let rms = sqrt(samples.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(samples.count))
        let attack = rms > max(0.025, previousRMS * 1.4)
        observe(samples)
        guard attack else { return false }

        if target.kind == .chord {
            return ChordMatcher.matches(samples, sampleRate: sampleRate, targets: target.frequencies)
        }
        guard let expected = target.frequencies.first,
              let reading = PitchDetector.estimate(samples, sampleRate: sampleRate),
              reading.clarity >= 0.80 else { return false }
        return abs(PitchDetector.cents(reading.frequency, target: expected)) <= 35
    }

    mutating func observe(_ samples: [Float]) {
        guard !samples.isEmpty else { return }
        previousRMS = sqrt(samples.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(samples.count))
    }

    mutating func reset() {
        previousRMS = 0
    }
}
