import Foundation

/// A lightweight Harmonic Pitch Class Profile (HPCP) matcher. It converts a
/// microphone frame into twelve octave-independent pitch-class strengths, then
/// compares that chroma vector with the chord Gita expects at the hit line.
enum ChordMatcher {
    static func matches(_ samples: [Float], sampleRate: Double, targets: [Double]) -> Bool {
        guard let chroma = chromaVector(samples, sampleRate: sampleRate) else { return false }
        let targetClasses = Set(targets.compactMap(pitchClass(for:)))
        guard targetClasses.count >= 3 else { return false }

        let expectedScore = templateScore(chroma, pitchClasses: targetClasses)
        let peak = chroma.max() ?? 0
        let presentThreshold = max(0.08, peak * 0.16)
        let coveredClasses = targetClasses.filter { chroma[$0] >= presentThreshold }.count
        let targetEnergy = targetClasses.reduce(0.0) { $0 + chroma[$1] * chroma[$1] }

        // A margin against all major/minor triads prevents shared tones (for
        // example C/E in both C and Am) from claiming the wrong nearby cue.
        var bestCompetingScore = 0.0
        for root in 0..<12 {
            for third in [3, 4] {
                let candidate: Set<Int> = [root, (root + third) % 12, (root + 7) % 12]
                guard candidate != targetClasses else { continue }
                bestCompetingScore = max(bestCompetingScore, templateScore(chroma, pitchClasses: candidate))
            }
        }

        return expectedScore >= 0.66 &&
            coveredClasses == targetClasses.count &&
            targetEnergy >= 0.46 &&
            expectedScore >= bestCompetingScore - 0.025
    }

    /// Builds a normalized 12-bin chroma vector. Each candidate fundamental is
    /// measured together with softly weighted harmonics, making the result more
    /// stable for bright nylon-string strums than fundamental-only matching.
    static func chromaVector(_ samples: [Float], sampleRate: Double) -> [Double]? {
        guard samples.count >= 2_048, sampleRate.isFinite, sampleRate > 0 else { return nil }
        let analysisCount = min(4_096, samples.count)
        let frame = samples.suffix(analysisCount)
        let mean = frame.reduce(0.0) { $0 + Double($1) } / Double(analysisCount)
        let rms = sqrt(frame.reduce(0.0) {
            let centered = Double($1) - mean
            return $0 + centered * centered
        } / Double(analysisCount))
        guard rms > 0.009 else { return nil }

        var windowed = [Double](repeating: 0, count: analysisCount)
        var windowSum = 0.0
        for (index, sample) in frame.enumerated() {
            let window = 0.5 - 0.5 * cos(2 * .pi * Double(index) / Double(analysisCount - 1))
            windowed[index] = (Double(sample) - mean) * window
            windowSum += window
        }

        var chroma = [Double](repeating: 0, count: 12)
        let harmonicWeights = [1.0, 0.34, 0.19, 0.11]
        let tuningRatios = [-18.0, 0, 18.0].map { pow(2, $0 / 1_200) }

        // C3...E6 covers standard ukulele and the configured fret range while
        // excluding most low-frequency handling noise.
        for midi in 48...88 {
            let fundamental = 440 * pow(2, Double(midi - 69) / 12)
            var salience = 0.0
            for (harmonicIndex, weight) in harmonicWeights.enumerated() {
                let harmonic = Double(harmonicIndex + 1)
                let centerFrequency = fundamental * harmonic
                guard centerFrequency < sampleRate * 0.47 else { continue }
                var strongestDetunedAmplitude = 0.0
                for tuningRatio in tuningRatios {
                    strongestDetunedAmplitude = max(
                        strongestDetunedAmplitude,
                        goertzelAmplitude(windowed, sampleRate: sampleRate, frequency: centerFrequency * tuningRatio, windowSum: windowSum)
                    )
                }
                salience += strongestDetunedAmplitude * weight
            }
            chroma[positiveModulo(midi, 12)] += salience
        }

        // Log compression stops one loud harmonic from hiding quieter chord
        // tones; L2 normalization makes matching independent of strum volume.
        chroma = chroma.map { log1p($0 * 45) }
        let magnitude = sqrt(chroma.reduce(0) { $0 + $1 * $1 })
        guard magnitude.isFinite, magnitude > 0.000_001 else { return nil }
        return chroma.map { $0 / magnitude }
    }

    private static func goertzelAmplitude(
        _ samples: [Double],
        sampleRate: Double,
        frequency: Double,
        windowSum: Double
    ) -> Double {
        guard frequency > 0, frequency < sampleRate / 2 else { return 0 }
        let coefficient = 2 * cos(2 * .pi * frequency / sampleRate)
        var previous = 0.0
        var previousPrevious = 0.0
        for sample in samples {
            let current = sample + coefficient * previous - previousPrevious
            previousPrevious = previous
            previous = current
        }
        let power = max(0, previous * previous + previousPrevious * previousPrevious - coefficient * previous * previousPrevious)
        return 2 * sqrt(power) / max(1, windowSum)
    }

    private static func pitchClass(for frequency: Double) -> Int? {
        guard frequency.isFinite, frequency > 0 else { return nil }
        let midi = Int((69 + 12 * log2(frequency / 440)).rounded())
        return positiveModulo(midi, 12)
    }

    private static func templateScore(_ chroma: [Double], pitchClasses: Set<Int>) -> Double {
        guard !pitchClasses.isEmpty else { return 0 }
        return pitchClasses.reduce(0.0) { $0 + chroma[$1] } / sqrt(Double(pitchClasses.count))
    }

    private static func positiveModulo(_ value: Int, _ divisor: Int) -> Int {
        let remainder = value % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }
}
