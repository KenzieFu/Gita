import Foundation

@main
struct GitaGamificationTests {
    static func main() throws {
        let tutorialKey = SongTutorialProgress.key(songID: "first-light", version: 2, arrangementID: "noob")
        precondition(tutorialKey == "first-light:v2:noob", "Tutorial identity must include chart version and arrangement")
        let zone = TimeZone(secondsFromGMT: 0)!
        let dayOne = Date(timeIntervalSince1970: 1_767_268_800)
        let dayTwo = dayOne.addingTimeInterval(86_400)
        let dayFour = dayOne.addingTimeInterval(3 * 86_400)
        let daySix = dayOne.addingTimeInterval(5 * 86_400)
        let dayEight = dayOne.addingTimeInterval(7 * 86_400)

        let profile = PlayerProfile()
        let initial = PlayerProgressSnapshot(
            profile: profile,
            dailyPlan: DailyPlanEngine.makePlan(at: dayOne, timeZone: zone, profile: profile),
            transactions: []
        )
        var engine = PlayerProgressEngine(snapshot: initial)
        let songReward = engine.rewardSongPlay(
            takeID: UUID(),
            songTitle: "Count on Me",
            tier: .noob,
            at: dayOne,
            timeZone: zone
        )
        precondition(songReward?.xp == 5 && songReward?.gems == 1, "Easy song clears award 5 XP and 1 gem")
        precondition(engine.snapshot.profile.currentStreak == 1, "A song clear qualifies the daily streak")
        let firstTask = engine.snapshot.dailyPlan.tasks[0]
        let firstReward = try engine.completeTask(id: firstTask.id, at: dayOne, timeZone: zone)
        precondition(firstReward.count == 1, "First qualifying task awards once")
        precondition(engine.snapshot.profile.currentStreak == 1, "First qualifying date begins the streak")
        let duplicated = try engine.completeTask(id: firstTask.id, at: dayOne, timeZone: zone)
        precondition(duplicated.isEmpty && engine.snapshot.profile.totalXP == firstTask.xp + 5, "Reopening a task cannot duplicate rewards")

        for task in engine.snapshot.dailyPlan.tasks.dropFirst() {
            _ = try engine.completeTask(id: task.id, at: dayOne, timeZone: zone)
        }
        precondition(engine.snapshot.dailyPlan.isComplete && engine.snapshot.dailyPlan.bonusClaimed, "All daily tasks claim one completion bonus")
        precondition(engine.snapshot.profile.streakFreezes == 2, "The daily chest grants one streak freeze up to the cap")
        precondition(engine.snapshot.profile.currentStreak == 1, "Several tasks on one date still count as one streak day")
        let dayOneXP = engine.snapshot.profile.totalXP

        engine.rollDailyPlanIfNeeded(at: dayTwo, timeZone: zone)
        _ = try engine.completeTask(id: engine.snapshot.dailyPlan.tasks[0].id, at: dayTwo, timeZone: zone)
        precondition(engine.snapshot.profile.currentStreak == 2, "A consecutive qualifying date extends the streak")
        precondition(engine.snapshot.profile.totalXP > dayOneXP, "A new date can award its tasks")

        engine.rollDailyPlanIfNeeded(at: dayFour, timeZone: zone)
        _ = try engine.completeTask(id: engine.snapshot.dailyPlan.tasks[0].id, at: dayFour, timeZone: zone)
        precondition(engine.snapshot.profile.currentStreak == 3 && engine.snapshot.profile.streakFreezes == 1, "One missed date consumes a freeze and recovers the streak")

        engine.rollDailyPlanIfNeeded(at: daySix, timeZone: zone)
        _ = try engine.completeTask(id: engine.snapshot.dailyPlan.tasks[0].id, at: daySix, timeZone: zone)
        precondition(engine.snapshot.profile.currentStreak == 4 && engine.snapshot.profile.streakFreezes == 0, "A second stored freeze can protect a later one-day gap")

        engine.rollDailyPlanIfNeeded(at: dayEight, timeZone: zone)
        _ = try engine.completeTask(id: engine.snapshot.dailyPlan.tasks[0].id, at: dayEight, timeZone: zone)
        precondition(engine.snapshot.profile.currentStreak == 1 && engine.snapshot.profile.longestStreak == 4, "Without a freeze, a missed date resets the current streak but preserves the best")

        precondition(LevelConfiguration.level(for: 0) == 1)
        precondition(LevelConfiguration.level(for: 100) == 2)
        precondition(LevelConfiguration.level(for: 999_999) == 20 && LevelConfiguration.progress(for: 999_999) == 1, "Level remains capped at twenty")

        precondition(!DailyTaskPassPolicy.passes(noteCount: 0, accuracy: 1), "An empty attempt cannot complete a task")
        precondition(!DailyTaskPassPolicy.passes(noteCount: 4, accuracy: 0.59), "A failed daily check stays incomplete")
        precondition(DailyTaskPassPolicy.passes(noteCount: 4, accuracy: 0.60), "A daily check completes at the passing threshold")

        let cheapItem = CosmeticItem(id: "test-sticker", name: "Test Sticker", category: .sticker, symbol: "star", price: 5, requiredLevel: 1)
        let gemsBeforePurchase = engine.snapshot.profile.gems
        let purchase = try engine.purchase(cheapItem, at: dayEight)
        precondition(purchase != nil && engine.snapshot.profile.gems == gemsBeforePurchase - 5, "A valid cosmetic purchase spends gems")
        let duplicatePurchase = try engine.purchase(cheapItem, at: dayEight)
        precondition(duplicatePurchase == nil, "The same item cannot be purchased twice")
        engine.equip(cheapItem)
        precondition(engine.snapshot.profile.equippedItemIDs.contains(cheapItem.id), "An owned item can be equipped")

        let temporaryRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }
        let store = PlayerProgressStore(root: temporaryRoot)
        try store.save(engine.snapshot)
        precondition(store.load(now: dayEight, timeZone: zone).profile == engine.snapshot.profile, "Gamification progress persists atomically")

        print("Gita gamification tests passed")
    }
}
