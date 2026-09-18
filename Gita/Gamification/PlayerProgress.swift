import Foundation

struct DayStamp: Codable, Equatable {
    let localDate: String
    let timeZoneID: String

    static func make(at date: Date, timeZone: TimeZone) -> DayStamp {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return DayStamp(
            localDate: String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!),
            timeZoneID: timeZone.identifier
        )
    }

    func isPreviousDay(of other: DayStamp) -> Bool {
        days(until: other) == 1
    }

    func days(until other: DayStamp) -> Int? {
        guard let zone = TimeZone(identifier: other.timeZoneID) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = zone
        formatter.dateFormat = "yyyy-MM-dd"
        guard let first = formatter.date(from: localDate), let second = formatter.date(from: other.localDate) else { return nil }
        return calendar.dateComponents([.day], from: first, to: second).day
    }
}

struct PlayerProfile: Codable, Equatable {
    var totalXP = 0
    var gems = 30
    var currentStreak = 0
    var longestStreak = 0
    var lastQualifiedDay: DayStamp?
    var streakFreezes = 1
    var ownedItemIDs: Set<String> = ["mascot-gita"]
    var equippedItemIDs: Set<String> = ["mascot-gita"]
    var completedTutorialKeys: Set<String> = []

    var level: Int { LevelConfiguration.level(for: totalXP) }
    var levelProgress: Double { LevelConfiguration.progress(for: totalXP) }

    private enum CodingKeys: String, CodingKey {
        case totalXP, gems, currentStreak, longestStreak, lastQualifiedDay, streakFreezes
        case ownedItemIDs, equippedItemIDs, completedTutorialKeys
    }

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        totalXP = try values.decodeIfPresent(Int.self, forKey: .totalXP) ?? 0
        gems = try values.decodeIfPresent(Int.self, forKey: .gems) ?? 30
        currentStreak = try values.decodeIfPresent(Int.self, forKey: .currentStreak) ?? 0
        longestStreak = try values.decodeIfPresent(Int.self, forKey: .longestStreak) ?? 0
        lastQualifiedDay = try values.decodeIfPresent(DayStamp.self, forKey: .lastQualifiedDay)
        // Existing installs receive one recovery chance when they migrate.
        streakFreezes = try values.decodeIfPresent(Int.self, forKey: .streakFreezes) ?? 1
        ownedItemIDs = try values.decodeIfPresent(Set<String>.self, forKey: .ownedItemIDs) ?? ["mascot-gita"]
        equippedItemIDs = try values.decodeIfPresent(Set<String>.self, forKey: .equippedItemIDs) ?? ["mascot-gita"]
        completedTutorialKeys = try values.decodeIfPresent(Set<String>.self, forKey: .completedTutorialKeys) ?? []
    }
}

enum SongTutorialProgress {
    static func key(songID: String, version: Int, arrangementID: String) -> String {
        "\(songID):v\(version):\(arrangementID)"
    }
}

enum DailyTaskKind: String, Codable {
    case chordLesson
    case transition
    case song
    case review
}

struct DailyTask: Codable, Identifiable, Equatable {
    let id: String
    let kind: DailyTaskKind
    let title: String
    let detail: String
    let xp: Int
    let gems: Int
}

enum DailyTaskPassPolicy {
    static let minimumAccuracy = 0.60

    static func passes(noteCount: Int, accuracy: Double) -> Bool {
        noteCount > 0 && accuracy.isFinite && accuracy >= minimumAccuracy
    }
}

struct DailyPlan: Codable, Equatable {
    let day: DayStamp
    let tasks: [DailyTask]
    var completedTaskIDs: Set<String> = []
    var bonusClaimed = false

    var isComplete: Bool { !tasks.isEmpty && tasks.allSatisfy { completedTaskIDs.contains($0.id) } }
}

struct RewardTransaction: Codable, Identifiable, Equatable {
    let id: String
    let xp: Int
    let gems: Int
    let streakFreezes: Int
    let reason: String
    let createdAt: Date

    init(id: String, xp: Int, gems: Int, streakFreezes: Int = 0, reason: String, createdAt: Date) {
        self.id = id
        self.xp = xp
        self.gems = gems
        self.streakFreezes = streakFreezes
        self.reason = reason
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey { case id, xp, gems, streakFreezes, reason, createdAt }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        xp = try values.decode(Int.self, forKey: .xp)
        gems = try values.decode(Int.self, forKey: .gems)
        streakFreezes = try values.decodeIfPresent(Int.self, forKey: .streakFreezes) ?? 0
        reason = try values.decode(String.self, forKey: .reason)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
    }
}

struct PlayerProgressSnapshot: Codable, Equatable {
    var profile: PlayerProfile
    var dailyPlan: DailyPlan
    var transactions: [RewardTransaction]
}

enum LevelConfiguration {
    // Total XP required to begin levels 1...20.
    static let thresholds = [
        0, 100, 250, 450, 700,
        1_000, 1_350, 1_750, 2_200, 2_700,
        3_250, 3_850, 4_500, 5_200, 5_950,
        6_750, 7_600, 8_500, 9_450, 10_450,
    ]

    static func level(for xp: Int) -> Int {
        let safeXP = max(0, xp)
        return min(20, (thresholds.lastIndex(where: { safeXP >= $0 }) ?? 0) + 1)
    }

    static func progress(for xp: Int) -> Double {
        let currentLevel = level(for: xp)
        guard currentLevel < 20 else { return 1 }
        let start = thresholds[currentLevel - 1]
        let end = thresholds[currentLevel]
        return min(1, max(0, Double(xp - start) / Double(end - start)))
    }

    static func xpRemaining(for xp: Int) -> Int {
        let currentLevel = level(for: xp)
        guard currentLevel < 20 else { return 0 }
        return max(0, thresholds[currentLevel] - xp)
    }
}

enum DailyPlanEngine {
    static func makePlan(at date: Date, timeZone: TimeZone, profile: PlayerProfile) -> DailyPlan {
        let foundation = DailyTask(
            id: "chord-foundation",
            kind: .chordLesson,
            title: "One easy chord check",
            detail: "Play one chord once. Listen for a clean sound.",
            xp: 20,
            gems: 5
        )
        let transition = DailyTask(
            id: "chord-transition",
            kind: .transition,
            title: "Two easy chord checks",
            detail: "Play two slow cues. No full song required.",
            xp: 20,
            gems: 5
        )
        let song = DailyTask(
            id: "song-progress",
            kind: .song,
            title: "Three-note rhythm check",
            detail: "Follow three short cues in Easy mode.",
            xp: 20,
            gems: 5
        )
        return DailyPlan(day: .make(at: date, timeZone: timeZone), tasks: [foundation, transition, song])
    }
}

enum ProgressRewardError: Error {
    case unknownTask
    case insufficientGems
    case lockedItem
}

struct PlayerProgressEngine {
    private(set) var snapshot: PlayerProgressSnapshot

    init(snapshot: PlayerProgressSnapshot) {
        self.snapshot = snapshot
    }

    mutating func rollDailyPlanIfNeeded(at date: Date, timeZone: TimeZone) {
        let today = DayStamp.make(at: date, timeZone: timeZone)
        if snapshot.dailyPlan.day == today {
            // Refresh copy and difficulty for existing installs without losing
            // today's already-completed task IDs or claimed chest.
            let refreshed = DailyPlanEngine.makePlan(at: date, timeZone: timeZone, profile: snapshot.profile)
            snapshot.dailyPlan = DailyPlan(
                day: today,
                tasks: refreshed.tasks,
                completedTaskIDs: snapshot.dailyPlan.completedTaskIDs,
                bonusClaimed: snapshot.dailyPlan.bonusClaimed
            )
            return
        }
        snapshot.dailyPlan = DailyPlanEngine.makePlan(at: date, timeZone: timeZone, profile: snapshot.profile)
    }

    @discardableResult
    mutating func completeTask(id taskID: String, at date: Date, timeZone: TimeZone) throws -> [RewardTransaction] {
        rollDailyPlanIfNeeded(at: date, timeZone: timeZone)
        guard let task = snapshot.dailyPlan.tasks.first(where: { $0.id == taskID }) else { throw ProgressRewardError.unknownTask }
        let day = snapshot.dailyPlan.day
        let taskTransactionID = "daily:\(day.localDate):\(task.id)"
        guard !snapshot.transactions.contains(where: { $0.id == taskTransactionID }) else { return [] }

        var awarded: [RewardTransaction] = []
        let taskReward = RewardTransaction(id: taskTransactionID, xp: task.xp, gems: task.gems, reason: task.title, createdAt: date)
        apply(taskReward)
        awarded.append(taskReward)
        snapshot.dailyPlan.completedTaskIDs.insert(task.id)
        updateStreak(for: day)

        if snapshot.dailyPlan.isComplete && !snapshot.dailyPlan.bonusClaimed {
            let bonus = RewardTransaction(
                id: "daily:\(day.localDate):complete",
                xp: 30,
                gems: 10,
                streakFreezes: snapshot.profile.streakFreezes < 2 ? 1 : 0,
                reason: "Daily path complete",
                createdAt: date
            )
            apply(bonus)
            awarded.append(bonus)
            snapshot.dailyPlan.bonusClaimed = true
        }
        return awarded
    }

    @discardableResult
    mutating func rewardSongPlay(
        takeID: UUID,
        songTitle: String,
        tier: ArrangementTier,
        at date: Date,
        timeZone: TimeZone
    ) -> RewardTransaction? {
        rollDailyPlanIfNeeded(at: date, timeZone: timeZone)
        let transaction = RewardTransaction(
            id: "song:\(takeID.uuidString)",
            xp: tier.playXP,
            gems: tier.playGems,
            reason: "\(songTitle) · \(tier.title)",
            createdAt: date
        )
        guard !snapshot.transactions.contains(where: { $0.id == transaction.id }) else { return nil }
        apply(transaction)
        updateStreak(for: snapshot.dailyPlan.day)
        return transaction
    }

    @discardableResult
    mutating func purchase(_ item: CosmeticItem, at date: Date) throws -> RewardTransaction? {
        if snapshot.profile.ownedItemIDs.contains(item.id) { return nil }
        guard snapshot.profile.level >= item.requiredLevel else { throw ProgressRewardError.lockedItem }
        guard snapshot.profile.gems >= item.price else { throw ProgressRewardError.insufficientGems }
        let transaction = RewardTransaction(id: "purchase:\(item.id)", xp: 0, gems: -item.price, reason: "Purchased \(item.name)", createdAt: date)
        guard !snapshot.transactions.contains(where: { $0.id == transaction.id }) else { return nil }
        apply(transaction)
        snapshot.profile.ownedItemIDs.insert(item.id)
        return transaction
    }

    mutating func equip(_ item: CosmeticItem) {
        guard snapshot.profile.ownedItemIDs.contains(item.id) else { return }
        for catalogItem in CosmeticCatalog.items where catalogItem.category == item.category {
            snapshot.profile.equippedItemIDs.remove(catalogItem.id)
        }
        snapshot.profile.equippedItemIDs.insert(item.id)
    }

    private mutating func apply(_ transaction: RewardTransaction) {
        guard !snapshot.transactions.contains(where: { $0.id == transaction.id }) else { return }
        snapshot.transactions.append(transaction)
        snapshot.profile.totalXP = max(0, snapshot.profile.totalXP + transaction.xp)
        snapshot.profile.gems = max(0, snapshot.profile.gems + transaction.gems)
        snapshot.profile.streakFreezes = min(2, max(0, snapshot.profile.streakFreezes + transaction.streakFreezes))
    }

    private mutating func updateStreak(for day: DayStamp) {
        guard snapshot.profile.lastQualifiedDay != day else { return }
        if let previous = snapshot.profile.lastQualifiedDay {
            switch previous.days(until: day) {
            case 1:
                snapshot.profile.currentStreak += 1
            case 2 where snapshot.profile.streakFreezes > 0:
                // One missed calendar day is recoverable once. The freeze is
                // consumed only when the player returns and qualifies again.
                snapshot.profile.streakFreezes -= 1
                snapshot.profile.currentStreak += 1
            default:
                snapshot.profile.currentStreak = 1
            }
        } else {
            snapshot.profile.currentStreak = 1
        }
        snapshot.profile.longestStreak = max(snapshot.profile.longestStreak, snapshot.profile.currentStreak)
        snapshot.profile.lastQualifiedDay = day
    }
}
