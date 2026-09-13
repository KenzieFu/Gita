import Foundation

enum ChordMatcher {
    static func matches(_ samples: [Float], sampleRate: Double, targets: [Double]) -> Bool {
        guard samples.count >= 2_048, sampleRate > 0, targets.count >= 3 else { return false }
        let rms = sqrt(samples.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(samples.count))
        guard rms > 0.012 else { return false }

        let count = samples.count
        let weighted = samples.enumerated().map { index, sample in
            Double(sample) * (0.5 - 0.5 * cos(2 * .pi * Double(index) / Double(count - 1)))
        }
        let strengths = targets.map { frequency -> Double in
            let angle = -2 * Double.pi * frequency / sampleRate
            var real = 0.0
            var imaginary = 0.0
            for (index, sample) in weighted.enumerated() {
                real += sample * cos(angle * Double(index))
                imaginary += sample * sin(angle * Double(index))
            }
            return 4 * hypot(real, imaginary) / Double(count)
        }
        guard let strongest = strengths.max(), strongest > 0.03 else { return false }
        let present = strengths.filter { $0 > max(0.025, strongest * 0.22) }.count
        return present >= max(3, Int(ceil(Double(targets.count) * 0.6)))
    }
}
