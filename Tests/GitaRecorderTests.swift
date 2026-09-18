import AVFoundation
import Foundation

@main
struct GitaRecorderTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("gita-recorder-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let recorder = PracticeAudioRecorder(root: root)
        try recorder.start(sampleRate: 44_100)
        try recorder.append(Array(repeating: 0.25, count: 4_410), sampleRate: 44_100)
        let fileURL = try recorder.stop()
        let file = try AVAudioFile(forReading: fileURL)
        precondition(file.length == 4_410, "Saved practice audio must include the microphone samples")
        precondition((try? recorder.stop()) == nil, "A recording cannot be saved twice")
    }
}
