import Foundation

struct ChallengeRecording: Codable, Identifiable {
    let take: PracticeTake
    let recordingFilename: String
    let chartID: String
    let chartVersion: Int
    let sectionID: String
    let sectionStartSeconds: Double
    let sectionEndSeconds: Double
    let scorerVersion: Int
    let confidence: Double?

    var id: UUID { take.id }
}

struct ChallengeDay: Codable, Identifiable {
    let ordinal: Int
    let localDate: String
    let timeZoneID: String
    var recordings: [ChallengeRecording]

    var id: String { "\(timeZoneID)-\(localDate)" }
}

struct ChallengeDayStore {
    let root: URL

    func days() throws -> [ChallengeDay] {
        let file = root.appendingPathComponent("challenge-days.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        return try JSONDecoder().decode([ChallengeDay].self, from: Data(contentsOf: file))
    }

    func save(take: PracticeTake, audioURL: URL, chart: SongChart, section: SongSection, at date: Date, timeZone: TimeZone) throws -> ChallengeDay {
        try chart.validate()
        guard section.startSeconds.isFinite,
              section.endSeconds.isFinite,
              section.startSeconds >= 0,
              section.startSeconds < section.endSeconds,
              section.endSeconds <= chart.audioDurationSeconds else {
            throw SongChartError.invalid("Invalid practice section")
        }
        let manager = FileManager.default
        let recordingsDirectory = root.appendingPathComponent("Recordings", isDirectory: true)
        try manager.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
        let audioData = try Data(contentsOf: audioURL)
        guard !audioData.isEmpty else { throw SongChartError.invalid("Recording is empty") }

        let filename = "\(take.id.uuidString).\(audioURL.pathExtension.isEmpty ? "caf" : audioURL.pathExtension.lowercased())"
        let savedAudio = recordingsDirectory.appendingPathComponent(filename)
        guard !manager.fileExists(atPath: savedAudio.path) else { throw LocalSongLibraryError.alreadyExists }
        try audioData.write(to: savedAudio, options: .atomic)
        do {
            var existingDays = try days()
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            let dayKey = String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)
            let recording = ChallengeRecording(
                take: take,
                recordingFilename: filename,
                chartID: chart.id,
                chartVersion: chart.version,
                sectionID: section.id,
                sectionStartSeconds: section.startSeconds,
                sectionEndSeconds: section.endSeconds,
                scorerVersion: 1,
                confidence: nil
            )
            let index = existingDays.firstIndex { $0.localDate == dayKey }
            if let index {
                existingDays[index].recordings.append(recording)
            } else {
                existingDays.append(ChallengeDay(ordinal: existingDays.count + 1, localDate: dayKey, timeZoneID: timeZone.identifier, recordings: [recording]))
            }
            try JSONEncoder().encode(existingDays).write(to: root.appendingPathComponent("challenge-days.json"), options: .atomic)
            return existingDays[index ?? existingDays.count - 1]
        } catch {
            try? manager.removeItem(at: savedAudio)
            throw error
        }
    }

    func recordingURL(for recording: ChallengeRecording) -> URL {
        root.appendingPathComponent("Recordings", isDirectory: true).appendingPathComponent(recording.recordingFilename)
    }
}
