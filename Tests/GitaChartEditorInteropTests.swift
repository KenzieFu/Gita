import Foundation

@main
enum GitaChartEditorInteropTests {
    static func main() throws {
        let fixture = URL(fileURLWithPath: "Tests/Fixtures/lyric-interop-chart.json")
        let data = try Data(contentsOf: fixture)
        let chart = try SongChart.decodeValidated(data)
        precondition(chart.schemaVersion == 2)
        precondition(chart.experience?.defaultTier == .superstar)
        precondition(chart.experience?.arrangements.first?.cues.map(\.lyricTokenID) == ["word-a1", "word-b1"])
        precondition(chart.notes.map(\.fret) == [0, 0, 0, 3, 0, 2, 3, 2])
        precondition(chart.sections.first?.id == "verse")

        var manualObject = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        var experience = manualObject["experience"] as! [String: Any]
        experience["lyricLines"] = []
        var arrangements = experience["arrangements"] as! [[String: Any]]
        var cues = arrangements[0]["cues"] as! [[String: Any]]
        for index in cues.indices { cues[index].removeValue(forKey: "lyricTokenID") }
        arrangements[0]["cues"] = cues
        experience["arrangements"] = arrangements
        manualObject["experience"] = experience
        let manualData = try JSONSerialization.data(withJSONObject: manualObject)
        let manualChart = try SongChart.decodeValidated(manualData)
        precondition(manualChart.experience?.lyricLines.isEmpty == true)
        precondition(manualChart.experience?.arrangements[0].cues.allSatisfy { $0.lyricTokenID == nil } == true)
        let manualExperience = manualChart.experience!
        let scoringChart = manualChart.practiceChart(experience: manualExperience, arrangement: manualExperience.arrangements[0])
        precondition(scoringChart.notes.count == 8)
        precondition(scoringChart.notes.filter { abs($0.beat - (0.5 * 80 / 60)) < 0.001 }.count == 4)

        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("gita-interop-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let matching = temp.appendingPathComponent("matching.mp3")
        let wrong = temp.appendingPathComponent("wrong.mp3")
        try Data([1, 2, 3]).write(to: matching)
        try Data([9, 9, 9]).write(to: wrong)
        let imported = try LocalSongLibrary(root: temp.appendingPathComponent("matched")).importChart(data: data, audio: matching)
        precondition(imported.id == chart.id)
        do {
            _ = try LocalSongLibrary(root: temp.appendingPathComponent("wrong")).importChart(data: data, audio: wrong)
            preconditionFailure("Different audio must not import")
        } catch LocalSongLibraryError.audioMismatch {
            // Expected.
        }
        print("Gita chart-editor interoperability tests passed")
    }
}
