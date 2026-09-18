import Foundation

enum GuideToneRenderer {
    static func render(frequency: Double, duration: Double, sampleRate: Double) -> [Float] {
        guard frequency.isFinite, duration.isFinite, sampleRate.isFinite,
              frequency > 0, duration > 0, sampleRate > 0, frequency < sampleRate / 2 else { return [] }
        let count = Int((duration * sampleRate).rounded())
        guard count > 0 && count < 10_000_000 else { return [] }
        return (0..<count).map { index in
            let time = Double(index) / sampleRate
            let attack = min(1, time / 0.006)
            let decay = exp(-time * 8)
            let fundamental = sin(2 * .pi * frequency * time)
            let second = frequency * 2 < sampleRate / 2 ? 0.25 * sin(4 * .pi * frequency * time) : 0
            return Float(0.65 * attack * decay * (fundamental + second))
        }
    }
}
