import AVFoundation
import Foundation

enum PracticeAudioRecorderError: Error {
    case notRecording
    case sampleRateChanged
}

final class PracticeAudioRecorder {
    let root: URL
    private var file: AVAudioFile?
    private var fileURL: URL?
    private var sampleRate: Double?

    init(root: URL) {
        self.root = root
    }

    func start(sampleRate: Double) throws {
        cancel()
        guard sampleRate.isFinite && sampleRate > 0 else { throw PracticeAudioRecorderError.sampleRateChanged }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("\(UUID().uuidString).caf")
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        file = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        fileURL = url
        self.sampleRate = sampleRate
    }

    func append(_ samples: [Float], sampleRate: Double) throws {
        guard let file, let expected = self.sampleRate else { throw PracticeAudioRecorderError.notRecording }
        guard sampleRate == expected else { throw PracticeAudioRecorderError.sampleRateChanged }
        guard !samples.isEmpty else { return }
        let format = AVAudioFormat(standardFormatWithSampleRate: expected, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            buffer.floatChannelData![0].update(from: source.baseAddress!, count: samples.count)
        }
        try file.write(from: buffer)
    }

    func stop() throws -> URL {
        guard let fileURL else { throw PracticeAudioRecorderError.notRecording }
        file = nil
        self.fileURL = nil
        sampleRate = nil
        return fileURL
    }

    func cancel() {
        file = nil
        if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
        fileURL = nil
        sampleRate = nil
    }
}
