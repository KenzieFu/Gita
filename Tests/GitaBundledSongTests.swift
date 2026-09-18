import CryptoKit
import Foundation

@main
struct GitaBundledSongTests {
    static func main() throws {
        let chart = CountOnMePrototype.makeChart()
        try chart.validate()
        precondition(chart.schemaVersion == 2 && chart.instrument == .ukulele, "The built-in song must use the ukulele lyric schema")
        precondition(chart.sections.count >= 3 && chart.experience?.lyricLines.count ?? 0 >= 8, "The song must expose its verse, pre-chorus, and chorus for playtesting")
        precondition(chart.experience?.arrangement(for: .noob)?.chordIDs == ["C", "G", "Am"], "Easy must use C, G, and Am")
        precondition(chart.experience?.arrangement(for: .guitaristWannabe)?.chordIDs == ["C", "G", "Am", "Dm"], "Medium must add Dm")
        precondition(chart.experience?.arrangement(for: .superstar)?.chordIDs.count == 6, "Pro must show the full six-chord progression")

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("gita-bundled-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let audioURL = root.appendingPathComponent("tiny.mp3")
        let audio = Data([1, 2, 3, 4])
        try audio.write(to: audioURL)
        var tinyChart = chart
        tinyChart.audioSHA256 = SHA256.hash(data: audio).map { String(format: "%02x", $0) }.joined()
        let library = LocalSongLibrary(root: root.appendingPathComponent("library", isDirectory: true))
        let chartData = try JSONEncoder().encode(tinyChart)
        let first = try BundledSongInstaller.install(chartData: chartData, audioURL: audioURL, into: library)
        let second = try BundledSongInstaller.install(chartData: chartData, audioURL: audioURL, into: library)
        precondition(first.id == chart.id && second.id == chart.id, "The bundled song must install once and be reusable")
        let installedSongs = try library.list()
        precondition(installedSongs.count == 1, "Repeated launches must not duplicate the song")

        if let suppliedAudioPath = ProcessInfo.processInfo.environment["GITA_COUNT_ON_ME_AUDIO"] {
            let realAudioURL = URL(fileURLWithPath: suppliedAudioPath)
            let realLibrary = LocalSongLibrary(root: root.appendingPathComponent("real-library", isDirectory: true))
            let installed = try BundledSongInstaller.install(chartData: JSONEncoder().encode(chart), audioURL: realAudioURL, into: realLibrary)
            let loaded = try realLibrary.load(chartID: installed.id, version: installed.version)
            precondition(loaded.0.audioSHA256 == chart.audioSHA256, "The supplied recording must pair with the prototype chart")
            let installedAudio = try Data(contentsOf: loaded.1)
            precondition(installedAudio.count > 7_000_000, "The installed song must keep the full supplied recording")
        }

        print("Gita bundled song tests passed")
    }
}
