import Foundation

struct SongScoreRecord: Codable, Equatable, Identifiable {
    let songID: String
    let songVersion: Int
    let tier: ArrangementTier
    var bestScore: Int
    var lastScore: Int
    var bestAccuracy: Double
    var totalPlays: Int
    var lastPlayedAt: Date

    var id: String { Self.key(songID: songID, songVersion: songVersion, tier: tier) }

    static func key(songID: String, songVersion: Int, tier: ArrangementTier) -> String {
        "\(songID):v\(songVersion):\(tier.rawValue)"
    }

    static func score(for take: PracticeTake) -> Int {
        guard take.noteCount > 0 else { return 0 }
        let points = take.hits.reduce(0) { partial, hit in
            let value = switch hit.grade {
            case .perfect: 100
            case .great: 80
            case .good: 55
            case .miss: 0
            }
            return partial + value
        }
        return min(100, max(0, Int((Double(points) / Double(take.noteCount)).rounded())))
    }
}

struct SongScoreStore {
    let root: URL

    func load() -> [SongScoreRecord] {
        let file = root.appendingPathComponent("song-scores.json")
        guard let data = try? Data(contentsOf: file),
              let records = try? JSONDecoder().decode([SongScoreRecord].self, from: data) else { return [] }
        return records.sorted { $0.lastPlayedAt > $1.lastPlayedAt }
    }

    @discardableResult
    func record(take: PracticeTake, chart: SongChart, tier: ArrangementTier) throws -> SongScoreRecord {
        var records = load()
        let id = SongScoreRecord.key(songID: chart.id, songVersion: chart.version, tier: tier)
        let score = SongScoreRecord.score(for: take)
        let record: SongScoreRecord
        if let index = records.firstIndex(where: { $0.id == id }) {
            records[index].bestScore = max(records[index].bestScore, score)
            records[index].lastScore = score
            records[index].bestAccuracy = max(records[index].bestAccuracy, take.accuracy)
            records[index].totalPlays += 1
            records[index].lastPlayedAt = take.playedAt
            record = records[index]
        } else {
            record = SongScoreRecord(
                songID: chart.id,
                songVersion: chart.version,
                tier: tier,
                bestScore: score,
                lastScore: score,
                bestAccuracy: take.accuracy,
                totalPlays: 1,
                lastPlayedAt: take.playedAt
            )
            records.append(record)
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try JSONEncoder().encode(records).write(
            to: root.appendingPathComponent("song-scores.json"),
            options: .atomic
        )
        return record
    }
}

struct SongPlayResult: Identifiable {
    let take: PracticeTake
    let songTitle: String
    let tier: ArrangementTier
    let score: Int
    let bestScore: Int
    let rewards: [RewardTransaction]
    let levelBefore: Int
    let levelAfter: Int
    let totalXP: Int
    let gems: Int
    let streak: Int
    let streakFreezesAvailable: Int
    let recordingMessage: String
    let heading: String
    let isDailyTask: Bool
    let didPass: Bool

    var id: UUID { take.id }
    var earnedXP: Int { rewards.reduce(0) { $0 + $1.xp } }
    var earnedGems: Int { rewards.reduce(0) { $0 + $1.gems } }
    var earnedStreakFreezes: Int { rewards.reduce(0) { $0 + $1.streakFreezes } }
    var unlockedDailyChest: Bool { rewards.contains { $0.id.hasSuffix(":complete") } }
}
