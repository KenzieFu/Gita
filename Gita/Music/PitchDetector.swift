import Foundation

struct PitchReading {
    let frequency: Double
    let clarity: Double
}

enum PitchDetector {
    static func cents(_ frequency: Double, target: Double) -> Double {
        1_200 * log2(frequency / target)
    }

    static func estimate(_ samples: [Float], sampleRate: Double) -> PitchReading? {
        guard samples.count >= 1_024, sampleRate > 0 else { return nil }
        let strideSize = max(1, Int((sampleRate / 11_025).rounded()))
        let values = stride(from: 0, to: samples.count, by: strideSize).map { Double(samples[$0]) }
        let rate = sampleRate / Double(strideSize)
        guard values.count >= 512 else { return nil }

        let mean = values.reduce(0, +) / Double(values.count)
        let centered = values.map { $0 - mean }
        let rms = sqrt(centered.reduce(0) { $0 + $1 * $1 } / Double(centered.count))
        guard rms > 0.008 else { return nil }

        let minLag = max(2, Int(rate / 900))
        let maxLag = min(Int(rate / 75), centered.count / 3)
        guard maxLag > minLag else { return nil }
        let comparisonCount = centered.count - maxLag
        var difference = [Double](repeating: 0, count: maxLag + 1)
        for lag in 1...maxLag {
            var sum = 0.0
            for index in 0..<comparisonCount {
                let delta = centered[index] - centered[index + lag]
                sum += delta * delta
            }
            difference[lag] = sum
        }

        var cumulative = 0.0
        var normalized = [Double](repeating: 1, count: maxLag + 1)
        for lag in 1...maxLag {
            cumulative += difference[lag]
            if cumulative > 0 {
                normalized[lag] = difference[lag] * Double(lag) / cumulative
            }
        }

        var selected: Int?
        for lag in minLag...maxLag where normalized[lag] < 0.16 {
            if lag == maxLag || normalized[lag] <= normalized[lag + 1] {
                selected = lag
                break
            }
        }
        if selected == nil,
           let best = (minLag...maxLag).min(by: { normalized[$0] < normalized[$1] }),
           normalized[best] < 0.22 {
            selected = best
        }
        guard let lag = selected else { return nil }
        var refined = Double(lag)
        if lag > 1 && lag < maxLag {
            let left = normalized[lag - 1]
            let middle = normalized[lag]
            let right = normalized[lag + 1]
            let curvature = left - 2 * middle + right
            if abs(curvature) > 0.000_001 {
                refined += 0.5 * (left - right) / curvature
            }
        }
        let frequency = rate / refined
        guard frequency.isFinite, (75...900).contains(frequency) else { return nil }
        return PitchReading(frequency: frequency, clarity: 1 - normalized[lag])
    }
}
