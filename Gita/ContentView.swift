import CryptoKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var account = AppleSession()
    @StateObject private var microphone = Microphone()
    @State private var progress = SetupProgress()
    @State private var route: SetupRoute = .welcome
    @State private var started = false
    @State private var guestMode = false
    @State private var returningFromReadyRetune = false
    @State private var showingPractice = false
    @State private var showingSongPreview = false
    @State private var showingChallengeHistory = false
    @State private var importingSongFiles = false
    @State private var importedSongs: [SongChart] = []
    @State private var songScores: [SongScoreRecord] = []
    @State private var playingSong: LocalSongSelection?
    @State private var showingFretFinder = false
    @State private var showingChordLibrary = false
    @State private var latestPracticeTake: PracticeTake?
    @State private var savedChallengeMessage: String?
    @State private var pendingDailyTaskID: String?
    @State private var latestSongResult: SongPlayResult?
    @State private var progressRevision = 0
    @State private var songPreviewRevision = 0

    private let store = ProgressStore()
    private let takeStore = PracticeTakeStore()

    var body: some View {
        Group {
            if account.status == .checking {
                StageShell(step: "Loading", title: "Finding your beat…", subtitle: "Loading your player setup on this device.") {
                    ProgressView().tint(ArcadeTheme.cyan)
                } trailing: {
                    NeonNote(symbol: "waveform.path", label: "GITA")
                }
            } else {
                stage
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            guestMode = store.isGuestModeEnabled
            // Seed the bundled chart before the first navigation decision. This
            // makes the default song available on every fresh installation,
            // independent of guest or Apple sign-in selection.
            installBundledSongIfAvailable()
            reloadSongScores()
            account.refreshCredentialState()
        }
        .onChange(of: account.status) { _, status in
            switch status {
            case .signedIn:
                if let id = account.userID {
                    store.setGuestModeEnabled(false)
                    guestMode = false
                    progress = store.load(for: id)
                    route = SetupPolicy.route(guestMode: false, userID: id, progress: progress, started: started)
                    installBundledSongIfAvailable()
                    reloadSongScores()
                }
            case .signedOut, .error:
                if guestMode {
                    progress = store.loadGuest()
                }
                route = SetupPolicy.route(guestMode: guestMode, userID: nil, progress: progress, started: started)
                if guestMode { installBundledSongIfAvailable() }
                if guestMode { reloadSongScores() }
            case .checking:
                break
            }
        }
        .onChange(of: route) { oldRoute, newRoute in
            if oldRoute.usesMicrophone { microphone.stop() }
            if newRoute.usesMicrophone { Task { await microphone.start() } }
        }
        .fullScreenCover(isPresented: $showingPractice) {
            if let instrument = progress.instrument,
               let chart = PracticeChart.starter(for: instrument, tuning: progress.ukuleleTuning) {
                PracticeView(chart: chart, microphone: microphone) {
                    showingPractice = false
                    pendingDailyTaskID = nil
                } onSave: { take in
                    showingPractice = false
                    completePendingDailyTask()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        latestPracticeTake = take
                    }
                }
            }
        }
        .sheet(isPresented: $showingSongPreview) {
            if let instrument = progress.instrument {
                SongPreviewView(info: .starter(for: instrument)) {
                    showingSongPreview = false
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        showingPractice = true
                    }
                } onClose: {
                    showingSongPreview = false
                    pendingDailyTaskID = nil
                }
            }
        }
        .sheet(isPresented: $showingChallengeHistory) {
            ChallengeHistoryView(days: (try? challengeDayStore.days()) ?? [], store: challengeDayStore) {
                showingChallengeHistory = false
            }
        }
        .fullScreenCover(item: $playingSong) { selection in
            GuidedPracticeView(
                chart: selection.chart,
                section: selection.section,
                audioURL: selection.audioURL,
                tier: selection.tier,
                contextTitle: selection.dailyTask?.title,
                microphone: microphone
            ) { take, recordingURL in
                finishSong(selection: selection, take: take, recordingURL: recordingURL)
            } onClose: {
                playingSong = nil
                pendingDailyTaskID = nil
                songPreviewRevision += 1
            }
        }
        .fullScreenCover(item: $latestSongResult) { result in
            SongPlayResultView(result: result) {
                latestSongResult = nil
                songPreviewRevision += 1
            }
        }
        .fullScreenCover(isPresented: $showingFretFinder) {
            if let instrument = progress.instrument {
                FretFinderView(instrument: instrument, tuning: progress.ukuleleTuning) {
                    showingFretFinder = false
                }
            }
        }
        .fullScreenCover(isPresented: $showingChordLibrary) {
            if let instrument = progress.instrument {
                ChordLibraryView(instrument: instrument) {
                    showingChordLibrary = false
                }
            }
        }
        .sheet(item: $latestPracticeTake) { take in
            TakeResultView(take: take, suggestedTitle: practiceTitle, suggestedDay: nextChallengeDay) { entry in
                if takeStore.save(entry, for: account.userID) {
                    latestPracticeTake = nil
                    savedChallengeMessage = "Day \(entry.day) · \(entry.songTitle) saved on this device."
                }
            } onClose: {
                latestPracticeTake = nil
            }
        }
        .fileImporter(isPresented: $importingSongFiles, allowedContentTypes: [.json, .audio], allowsMultipleSelection: true) { result in
            do {
                let urls = try result.get()
                guard !urls.isEmpty else { return }

                let scopedURLs = urls.filter { $0.startAccessingSecurityScopedResource() }
                defer { scopedURLs.forEach { $0.stopAccessingSecurityScopedResource() } }

                let chartURLs = urls.filter { $0.pathExtension.lowercased() == "json" }
                let audioURLs = urls.filter { url in
                    guard url.pathExtension.lowercased() != "json" else { return false }
                    return UTType(filenameExtension: url.pathExtension)?.conforms(to: .audio) == true
                }
                guard chartURLs.count == 1 else {
                    savedChallengeMessage = "Select one exported Gita chart JSON and one matching MP3 or M4A file."
                    return
                }

                let data = try Data(contentsOf: chartURLs[0])
                _ = try SongChart.decodeValidated(data)
                guard audioURLs.count == 1 else {
                    savedChallengeMessage = "Select one exported chart JSON and one matching MP3 or M4A together."
                    return
                }
                try importSong(chartData: data, audioURL: audioURLs[0])
            } catch {
                savedChallengeMessage = "The chart or audio could not be opened. Select the exported JSON and its matching MP3 or M4A."
            }
        }
        .alert("Gita update", isPresented: Binding(
            get: { savedChallengeMessage != nil },
            set: { if !$0 { savedChallengeMessage = nil } }
        )) {
            Button("OK") { savedChallengeMessage = nil }
        } message: {
            Text(savedChallengeMessage ?? "")
        }
    }

    @ViewBuilder private var stage: some View {
        switch route {
        case .welcome:
            WelcomeView {
                started = true
                route = .signIn
            }
        case .signIn:
            SignInView(errorMessage: errorMessage, onCompletion: account.handle) {
                store.setGuestModeEnabled(true)
                guestMode = true
                progress = store.loadGuest()
                route = SetupPolicy.route(guestMode: true, userID: nil, progress: progress, started: started)
            } onBack: {
                started = false
                route = .welcome
            }
        case .instrumentChoice:
            InstrumentChoiceView { instrument in
                progress.choose(instrument)
                saveProgress()
                returningFromReadyRetune = false
                route = .tuning
            }
        case .tuning:
            if let instrument = progress.instrument {
                TunerView(instrument: instrument, initialTuning: progress.ukuleleTuning, microphone: microphone, completed: progress.completedTuning) { tuned, tuning in
                    progress.completedTuning = tuned
                    progress.ukuleleTuning = tuning
                    saveProgress()
                } onComplete: {
                    route = returningFromReadyRetune ? .ready : .tutorial
                    returningFromReadyRetune = false
                } onBack: {
                    route = .instrumentChoice
                }
            }
        case .tutorial:
            if let instrument = progress.instrument {
                TutorialView(instrument: instrument, tuning: progress.ukuleleTuning, microphone: microphone, initialStep: progress.lessonStep) { nextStep in
                    progress.lessonStep = nextStep
                    saveProgress()
                } onComplete: {
                    progress.tutorialComplete = true
                    progress.lessonStep = 3
                    saveProgress()
                    route = .ready
                } onBack: {
                    route = .tuning
                }
            }
        case .ready:
            if let instrument = progress.instrument {
                MainTabView(
                    instrument: instrument,
                    isGuest: guestMode,
                    songs: importedSongs,
                    songScores: songScores,
                    audioURLForSong: audioURL(for:),
                    progressRoot: gamificationRoot,
                    progressRevision: progressRevision,
                    songPreviewRevision: songPreviewRevision
                ) {
                    progress.resetTuning()
                    saveProgress()
                    returningFromReadyRetune = true
                    route = .tuning
                } onPractice: {
                    showingSongPreview = true
                } onImportSong: {
                    importingSongFiles = true
                } onSelectSong: { chart, section, tier in
                    openSong(chart, section: section, tier: tier)
                } onHistory: {
                    showingChallengeHistory = true
                } onFretFinder: {
                    showingFretFinder = true
                } onChordLibrary: {
                    showingChordLibrary = true
                } onReplay: {
                    progress.tutorialComplete = false
                    progress.lessonStep = 0
                    saveProgress()
                    route = .tutorial
                } onSwitch: {
                    route = .instrumentChoice
                } onSignIn: {
                    store.setGuestModeEnabled(false)
                    guestMode = false
                    started = true
                    route = .signIn
                } onStartDailyTask: { task in
                    openDailyTask(task)
                }
            }
        }
    }

    private var errorMessage: String? {
        if case .error(let message) = account.status { return message }
        return nil
    }

    private func openSong(_ chart: SongChart, section: SongSection, tier: ArrangementTier?, dailyTask: DailyTask? = nil) {
        do {
            let (_, audioURL) = try localSongLibrary.load(chartID: chart.id, version: chart.version)
            let selection = LocalSongSelection(
                chart: chart,
                section: section,
                audioURL: audioURL,
                tier: tier ?? chart.experience?.defaultTier ?? .noob,
                dailyTask: dailyTask
            )
            playingSong = selection
        } catch {
            if dailyTask != nil { pendingDailyTaskID = nil }
            savedChallengeMessage = "This song's audio is missing. Please import it again."
        }
    }

    private func openDailyTask(_ task: DailyTask) {
        guard let chart = importedSongs.first(where: { $0.experience != nil }) else {
            savedChallengeMessage = "Add a playable song before starting today's task."
            return
        }
        // Daily practice is intentionally gentle: all tasks use the Easy
        // arrangement and increase only the number of short checks.
        let tier: ArrangementTier = .noob
        guard chart.experience?.arrangement(for: tier) != nil else {
            savedChallengeMessage = "This song does not include the \(tier.title) mode required by the task."
            return
        }
        let section = dailyTaskSection(for: task, chart: chart, tier: tier)
        pendingDailyTaskID = task.id
        openSong(chart, section: section, tier: tier, dailyTask: task)
    }

    private func dailyTaskSection(for task: DailyTask, chart: SongChart, tier: ArrangementTier) -> SongSection {
        let cueLimit: Int
        switch task.kind {
        case .chordLesson: cueLimit = 1
        case .transition: cueLimit = 2
        case .song: cueLimit = 3
        case .review: cueLimit = 4
        }
        guard let cues = chart.experience?.arrangement(for: tier)?.cues.sorted(by: { $0.onsetSeconds < $1.onsetSeconds }),
              let first = cues.first else {
            return chart.sections.first ?? chart.fullSongSection
        }
        let selected = Array(cues.prefix(cueLimit))
        let lastOnset = selected.last?.onsetSeconds ?? first.onsetSeconds
        let start = max(0, first.onsetSeconds - 1.25)
        let end = min(chart.audioDurationSeconds, max(start + 3.5, lastOnset + 2.25))
        return SongSection(
            id: "__daily-\(task.id)__",
            title: "\(selected.count) quick check\(selected.count == 1 ? "" : "s")",
            startSeconds: start,
            endSeconds: end
        )
    }

    private func audioURL(for chart: SongChart) -> URL? {
        try? localSongLibrary.load(chartID: chart.id, version: chart.version).1
    }

    private func importSong(chartData: Data, audioURL: URL) throws {
        let incomingChart = try SongChart.decodeValidated(chartData)
        let isReplacement = (try? localSongLibrary.load(chartID: incomingChart.id, version: incomingChart.version)) != nil
        let imported = try localSongLibrary.importChart(data: chartData, audio: audioURL)
        importedSongs = (try? localSongLibrary.list()) ?? []
        savedChallengeMessage = isReplacement
            ? "\(imported.title) updated. The existing song was replaced with this import."
            : "\(imported.title) imported. It is ready in Songs."
    }

    private var practiceTitle: String {
        guard let instrument = progress.instrument,
              let chart = PracticeChart.starter(for: instrument, tuning: progress.ukuleleTuning) else { return "Practice" }
        return chart.title
    }

    private var nextChallengeDay: Int {
        min(100, (takeStore.load(for: account.userID).map(\.day).max() ?? 0) + 1)
    }

    private var localSongLibrary: LocalSongLibrary {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return LocalSongLibrary(root: support.appendingPathComponent("Gita/Songs/\(storageOwnerKey)", isDirectory: true))
    }

    private var challengeDayStore: ChallengeDayStore {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return ChallengeDayStore(root: support.appendingPathComponent("Gita/Challenge/\(storageOwnerKey)", isDirectory: true))
    }

    private var gamificationRoot: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("Gita/Progress/\(storageOwnerKey)", isDirectory: true)
    }

    private var storageOwnerKey: String {
        guard let userID = account.userID else { return "guest" }
        return SHA256.hash(data: Data(userID.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func saveProgress() {
        if guestMode {
            store.saveGuest(progress)
        } else if let id = account.userID {
            store.save(progress, for: id)
        }
    }

    @discardableResult
    private func completePendingDailyTask() -> [RewardTransaction] {
        guard let taskID = pendingDailyTaskID else { return [] }
        let progressStore = PlayerProgressStore(root: gamificationRoot)
        var engine = PlayerProgressEngine(snapshot: progressStore.load())
        let rewards = (try? engine.completeTask(id: taskID, at: Date(), timeZone: .current)) ?? []
        try? progressStore.save(engine.snapshot)
        pendingDailyTaskID = nil
        progressRevision += 1
        return rewards
    }

    private func finishSong(selection: LocalSongSelection, take: PracticeTake, recordingURL: URL) {
        let progressStore = PlayerProgressStore(root: gamificationRoot)
        let before = progressStore.load(now: take.playedAt, timeZone: .current)
        var engine = PlayerProgressEngine(snapshot: before)
        var rewards: [RewardTransaction] = []
        let isDailyTask = selection.dailyTask != nil
        let didPass = !isDailyTask || DailyTaskPassPolicy.passes(
            noteCount: take.noteCount,
            accuracy: take.accuracy
        )
        // Short daily checks award their task reward only; they must not count
        // as a full-song clear or overwrite the song's best score.
        let awardsSongClear = selection.dailyTask == nil
        if awardsSongClear {
            if let songReward = engine.rewardSongPlay(
                takeID: take.id,
                songTitle: selection.chart.title,
                tier: selection.tier,
                at: take.playedAt,
                timeZone: .current
            ) {
                rewards.append(songReward)
            }
        }
        if didPass, let taskID = pendingDailyTaskID {
            rewards.append(contentsOf: (try? engine.completeTask(id: taskID, at: take.playedAt, timeZone: .current)) ?? [])
        }
        pendingDailyTaskID = nil
        try? progressStore.save(engine.snapshot)

        let currentScore = SongScoreRecord.score(for: take)
        let scoreRecord = awardsSongClear
            ? try? songScoreStore.record(take: take, chart: selection.chart, tier: selection.tier)
            : nil
        reloadSongScores()

        let recordingMessage: String
        do {
            if isDailyTask && !didPass {
                try? FileManager.default.removeItem(at: recordingURL)
                recordingMessage = "Task not completed. Reach at least 60% note match and try again."
            } else {
                let day = try challengeDayStore.save(
                    take: take,
                    audioURL: recordingURL,
                    chart: selection.chart,
                    section: selection.section,
                    at: take.playedAt,
                    timeZone: .current
                )
                try? FileManager.default.removeItem(at: recordingURL)
                recordingMessage = "Saved as challenge day \(day.ordinal)."
            }
        } catch {
            recordingMessage = "Score saved. The temporary audio recording could not be added to the challenge."
        }

        let result = SongPlayResult(
            take: take,
            songTitle: selection.chart.title,
            tier: selection.tier,
            score: currentScore,
            bestScore: scoreRecord?.bestScore ?? currentScore,
            rewards: rewards,
            levelBefore: before.profile.level,
            levelAfter: engine.snapshot.profile.level,
            totalXP: engine.snapshot.profile.totalXP,
            gems: engine.snapshot.profile.gems,
            streak: engine.snapshot.profile.currentStreak,
            streakFreezesAvailable: engine.snapshot.profile.streakFreezes,
            recordingMessage: recordingMessage,
            heading: isDailyTask ? (didPass ? "TASK CLEAR" : "TRY AGAIN") : "SONG CLEAR",
            isDailyTask: isDailyTask,
            didPass: didPass
        )
        progressRevision += 1
        playingSong = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            latestSongResult = result
        }
    }

    private func installBundledSongIfAvailable() {
        guard let audioURL = Bundle.main.url(forResource: CountOnMePrototype.audioResourceName, withExtension: "mp3") else { return }
        do {
            // Prefer the user-authored export when it is bundled with the app.
            // The generated chart remains a fallback for older builds.
            let chartData: Data
            if let authoredURL = Bundle.main.url(forResource: "count-on-me-bruno-mars-v1", withExtension: "gita.json") {
                chartData = try Data(contentsOf: authoredURL)
            } else {
                chartData = try JSONEncoder().encode(CountOnMePrototype.makeChart())
            }
            _ = try BundledSongInstaller.install(chartData: chartData, audioURL: audioURL, into: localSongLibrary)
            importedSongs = (try? localSongLibrary.list()) ?? []
        } catch {
            savedChallengeMessage = "The built-in prototype song could not be installed. Check its local audio resource."
        }
    }

    private var songScoreStore: SongScoreStore {
        SongScoreStore(root: gamificationRoot)
    }

    private func reloadSongScores() {
        songScores = songScoreStore.load()
    }
}

private struct LocalSongSelection: Identifiable {
    let chart: SongChart
    let section: SongSection
    let audioURL: URL
    var tier: ArrangementTier = .noob
    var dailyTask: DailyTask? = nil

    var arrangement: SongArrangement? { chart.experience?.arrangement(for: tier) }

    var id: String { "\(chart.id)-\(chart.version)-\(section.id)-\(tier.rawValue)" }
}

#Preview {
    ContentView()
}
