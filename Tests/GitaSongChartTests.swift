import Foundation
import CryptoKit

@main
struct GitaSongChartTests {
    static func main() throws {
        let fixture = URL(fileURLWithPath: "Tests/Fixtures/short-ukulele-chart.json")
        let chart = try SongChart.decodeValidated(Data(contentsOf: fixture))
        precondition(chart.notes.count == 2 && chart.section(id: "intro")?.title == "Intro", "Valid chart must decode with sections")
        precondition(chart.practiceChart().notes[0].beat == 2.0 / 3.0, "An onset at 0.5 seconds is two-thirds of a beat at 80 BPM")
        precondition(chart.practiceChart().beatsPerBar == 4, "Time signature must reach the practice engine")
        precondition(chart.difficulty == .easy && chart.chordNames.isEmpty, "Song preview must show authored difficulty and no guessed chords")

        var invalidChordList = chart
        invalidChordList.chordNames = ["C"]
        precondition((try? SongChart.decodeValidated(JSONEncoder().encode(invalidChordList))) == nil, "Single-note chart must not advertise chord practice")

        var invalidFret = chart
        invalidFret.notes[0].fret = 13
        precondition((try? SongChart.decodeValidated(JSONEncoder().encode(invalidFret))) == nil, "Out-of-range frets must be rejected")

        var unsupported = chart
        unsupported.schemaVersion = 2
        precondition((try? SongChart.decodeValidated(JSONEncoder().encode(unsupported))) == nil, "Unknown schema versions must be rejected")

        var overlapping = chart
        overlapping.notes[1].onsetSeconds = 0.5
        precondition((try? SongChart.decodeValidated(JSONEncoder().encode(overlapping))) == nil, "Single-note charts cannot claim simultaneous notes")

        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        let matchingAudioURL = temporaryDirectory.appendingPathComponent("matching.mp3")
        let wrongAudioURL = temporaryDirectory.appendingPathComponent("wrong.mp3")
        try Data([1, 2, 3]).write(to: matchingAudioURL)
        try Data([9, 9, 9]).write(to: wrongAudioURL)
        var importable = chart
        importable.audioSHA256 = SHA256.hash(data: Data([1, 2, 3])).map { String(format: "%02x", $0) }.joined()
        let chartData = try JSONEncoder().encode(importable)
        let library = LocalSongLibrary(root: temporaryDirectory.appendingPathComponent("library"))
        _ = try library.importChart(data: chartData, audio: matchingAudioURL)
        let loaded = try library.load(chartID: "test-song", version: 1)
        let loadedAudio = try Data(contentsOf: loaded.1)
        precondition(loaded.0.id == "test-song" && loadedAudio == Data([1, 2, 3]), "Imported audio must stay paired with its chart")
        let savedCharts = try library.list()
        precondition(savedCharts.count == 1, "Imported chart must appear in the library")

        var replacement = importable
        replacement.title = "Updated Test Song"
        _ = try library.importChart(data: JSONEncoder().encode(replacement), audio: matchingAudioURL)
        let replaced = try library.load(chartID: "test-song", version: 1)
        let replacedAudio = try Data(contentsOf: replaced.1)
        let chartsAfterReplacement = try library.list()
        precondition(replaced.0.title == "Updated Test Song" && replacedAudio == Data([1, 2, 3]), "A matching song ID and version must replace the saved import")
        precondition(chartsAfterReplacement.count == 1, "Replacing a song must not create a duplicate")

        var badReplacement = replacement
        badReplacement.title = "Must Not Replace"
        precondition((try? library.importChart(data: JSONEncoder().encode(badReplacement), audio: wrongAudioURL)) == nil, "Mismatched replacement audio must be rejected")
        let preserved = try library.load(chartID: "test-song", version: 1)
        precondition(preserved.0.title == "Updated Test Song", "A failed replacement must preserve the existing song")

        let wrongLibrary = LocalSongLibrary(root: temporaryDirectory.appendingPathComponent("wrong-library"))
        precondition((try? wrongLibrary.importChart(data: chartData, audio: wrongAudioURL)) == nil, "Audio with the wrong digest must be rejected")
        let wrongCharts = try wrongLibrary.list()
        precondition(wrongCharts.isEmpty, "Failed import must not leave a chart behind")

        var flow = LearningFlow()
        precondition(flow.stage == .hear && flow.rate == 0.7, "A new section must begin in Hear at beginner speed")
        flow.advance()
        precondition(flow.stage == .learn && flow.rate == 0.7, "Moving to Learn must not change speed")
        precondition(!flow.shouldSuggestFaster(score: 0.95, confidence: 0.5), "Uncertain scoring cannot suggest acceleration")
        precondition(flow.shouldSuggestFaster(score: 0.9, confidence: 0.95), "Strong confident practice can offer a faster option")
        precondition(flow.rate == 0.7, "A suggestion must never change speed on its own")
        flow.acceptFasterSuggestion()
        precondition(flow.rate == 0.8, "Accepting the suggestion should advance one speed step")
        flow.advance()
        precondition(flow.stage == .play, "The last stage is Play")
        let timeline = SongPlaybackTimeline(sourceStart: 30, rate: 0.5)
        precondition(timeline.elapsed(forSourceSeconds: 31) == 2, "Source events must stretch at half speed")
        precondition(timeline.sourceSeconds(forElapsed: 2) == 31, "Playback and source time must be reversible")

        let tone = GuideToneRenderer.render(frequency: 440, duration: 0.2, sampleRate: 44_100)
        precondition(tone.count == 8_820 && tone.contains(where: { abs($0) > 0.01 }), "Guide must audibly represent a chart note")
        precondition(tone.allSatisfy { abs($0) <= 1 }, "Guide must not clip")
        precondition(GuideToneRenderer.render(frequency: -1, duration: 0.2, sampleRate: 44_100).isEmpty, "Invalid frequency must not generate a sound")

        let starterPreview = SongPreviewInfo.starter(for: .ukulele)
        precondition(starterPreview.difficulty == .easy && starterPreview.chordNames == ["C"], "Ukulele starter preview must name its authored C chord")
        precondition(starterPreview.playTypes == ["Single notes", "Basic chord"], "Preview must tell beginners what they will play")

        let schedule = GuideEventSchedule(chart: chart, section: chart.sections[0], rate: 0.5)
        precondition(schedule.noteOnsets == [1, 2.5], "Guide note onsets must stretch with the song")
        precondition(schedule.beatOnsets.prefix(3).elementsEqual([0, 1.5, 3]), "Beat cues must use the same slowed timeline")

        let challengeRoot = temporaryDirectory.appendingPathComponent("challenge")
        let dayStore = ChallengeDayStore(root: challengeRoot)
        let firstTake = PracticeTake(id: UUID(), chartID: "test-song-v1", playedAt: Date(timeIntervalSince1970: 1_767_268_800), speed: 0.7, noteCount: 2, hits: [])
        let secondTake = PracticeTake(id: UUID(), chartID: "test-song-v1", playedAt: firstTake.playedAt.addingTimeInterval(3_600), speed: 0.7, noteCount: 2, hits: [])
        let thirdTake = PracticeTake(id: UUID(), chartID: "test-song-v1", playedAt: firstTake.playedAt.addingTimeInterval(3 * 86_400), speed: 0.8, noteCount: 2, hits: [])
        let zone = TimeZone(secondsFromGMT: 0)!
        let firstDay = try dayStore.save(take: firstTake, audioURL: matchingAudioURL, chart: chart, section: chart.sections[0], at: firstTake.playedAt, timeZone: zone)
        let sameDay = try dayStore.save(take: secondTake, audioURL: matchingAudioURL, chart: chart, section: chart.sections[0], at: secondTake.playedAt, timeZone: zone)
        let laterDay = try dayStore.save(take: thirdTake, audioURL: matchingAudioURL, chart: chart, section: chart.sections[0], at: thirdTake.playedAt, timeZone: zone)
        precondition(firstDay.ordinal == 1 && sameDay.ordinal == 1 && laterDay.ordinal == 2, "Challenge must count distinct practice dates without reset")
        let savedDays = try dayStore.days()
        precondition(savedDays.count == 2, "Multiple takes on one date share one challenge day")
        precondition((try? dayStore.save(take: firstTake, audioURL: temporaryDirectory.appendingPathComponent("missing.caf"), chart: chart, section: chart.sections[0], at: firstTake.playedAt.addingTimeInterval(4 * 86_400), timeZone: zone)) == nil, "Missing audio cannot create a challenge day")
        let daysAfterFailure = try dayStore.days()
        precondition(daysAfterFailure.count == 2, "Failed recording must not advance the challenge")
    }
}
