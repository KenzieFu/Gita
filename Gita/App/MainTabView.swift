import SwiftUI

struct MainTabView: View {
    let instrument: Instrument
    let isGuest: Bool
    let songs: [SongChart]
    let songScores: [SongScoreRecord]
    let audioURLForSong: (SongChart) -> URL?
    let progressRevision: Int
    let songPreviewRevision: Int
    let onRetune: () -> Void
    let onPractice: () -> Void
    let onImportSong: () -> Void
    let onSelectSong: (SongChart, SongSection, ArrangementTier?) -> Void
    let onHistory: () -> Void
    let onFretFinder: () -> Void
    let onChordLibrary: () -> Void
    let onReplay: () -> Void
    let onSwitch: () -> Void
    let onSignIn: () -> Void
    let onStartDailyTask: (DailyTask) -> Void

    @StateObject private var progress: PlayerProgressModel
    @State private var selectedTab: GitaMainTab = .home

    init(
        instrument: Instrument,
        isGuest: Bool,
        songs: [SongChart],
        songScores: [SongScoreRecord],
        audioURLForSong: @escaping (SongChart) -> URL?,
        progressRoot: URL,
        progressRevision: Int,
        songPreviewRevision: Int,
        onRetune: @escaping () -> Void,
        onPractice: @escaping () -> Void,
        onImportSong: @escaping () -> Void,
        onSelectSong: @escaping (SongChart, SongSection, ArrangementTier?) -> Void,
        onHistory: @escaping () -> Void,
        onFretFinder: @escaping () -> Void,
        onChordLibrary: @escaping () -> Void,
        onReplay: @escaping () -> Void,
        onSwitch: @escaping () -> Void,
        onSignIn: @escaping () -> Void,
        onStartDailyTask: @escaping (DailyTask) -> Void
    ) {
        self.instrument = instrument
        self.isGuest = isGuest
        self.songs = songs
        self.songScores = songScores
        self.audioURLForSong = audioURLForSong
        self.progressRevision = progressRevision
        self.songPreviewRevision = songPreviewRevision
        self.onRetune = onRetune
        self.onPractice = onPractice
        self.onImportSong = onImportSong
        self.onSelectSong = onSelectSong
        self.onHistory = onHistory
        self.onFretFinder = onFretFinder
        self.onChordLibrary = onChordLibrary
        self.onReplay = onReplay
        self.onSwitch = onSwitch
        self.onSignIn = onSignIn
        self.onStartDailyTask = onStartDailyTask
        _progress = StateObject(wrappedValue: PlayerProgressModel(store: PlayerProgressStore(root: progressRoot)))
    }

    var body: some View {
        VStack(spacing: 0) {
            GameTopNavigation(profile: progress.snapshot.profile, selectedTab: $selectedTab)
            ZStack {
                switch selectedTab {
                case .home:
                    NavigationStack {
                        HomeView(
                            model: progress,
                            instrument: instrument,
                            isGuest: isGuest,
                            onPractice: onPractice,
                            onHistory: onHistory,
                            onFretFinder: onFretFinder,
                            onRetune: onRetune,
                            onReplay: onReplay,
                            onSwitch: onSwitch,
                            onSignIn: onSignIn,
                            onStartDailyTask: onStartDailyTask
                        )
                        .toolbar(.hidden, for: .navigationBar)
                    }
                case .songs:
                    SongLibraryView(
                        songs: songs,
                        scores: songScores,
                        audioURLForSong: audioURLForSong,
                        previewRevision: songPreviewRevision,
                        onSelect: onSelectSong,
                        onImport: onImportSong
                    )
                case .shop:
                    NavigationStack {
                        ShopView(model: progress)
                            .toolbar(.hidden, for: .navigationBar)
                    }
                case .backpack:
                    NavigationStack {
                        BackpackView(model: progress)
                            .toolbar(.hidden, for: .navigationBar)
                    }
                case .settings:
                    NavigationStack {
                        PlayerSettingsView(
                            instrument: instrument,
                            isGuest: isGuest,
                            onHistory: onHistory,
                            onFretFinder: onFretFinder,
                            onChordLibrary: onChordLibrary,
                            onRetune: onRetune,
                            onReplay: onReplay,
                            onSwitch: onSwitch,
                            onSignIn: onSignIn
                        )
                        .toolbar(.hidden, for: .navigationBar)
                    }
                }
            }
            .id(selectedTab)
            .transition(.opacity.combined(with: .scale(scale: 0.985)))
            .animation(.smooth(duration: 0.28), value: selectedTab)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(ArcadeTheme.background.ignoresSafeArea())
        .tint(ArcadeTheme.cyan)
        .preferredColorScheme(.dark)
        .onChange(of: selectedTab) { _, _ in progress.reload() }
        .onChange(of: progressRevision) { _, _ in progress.reload() }
        .alert("Gita", isPresented: Binding(
            get: { progress.message != nil },
            set: { if !$0 { progress.message = nil } }
        )) {
            Button("OK") { progress.message = nil }
        } message: {
            Text(progress.message ?? "")
        }
    }
}

private enum GitaMainTab: String, CaseIterable, Identifiable {
    case home
    case songs
    case shop
    case backpack
    case settings

    var id: String { rawValue }
    var title: String { rawValue.uppercased() }
    var isEnabled: Bool { self != .shop && self != .backpack }
    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .songs: "music.note.list"
        case .shop: "storefront.fill"
        case .backpack: "backpack.fill"
        case .settings: "gearshape.fill"
        }
    }
}

private struct GameTopNavigation: View {
    let profile: PlayerProfile
    @Binding var selectedTab: GitaMainTab
    @Namespace private var selectedTabAnimation
    @State private var flamePulse = false

    private var nextLevelXP: Int {
        guard profile.level < LevelConfiguration.thresholds.count else { return LevelConfiguration.thresholds.last ?? profile.totalXP }
        return LevelConfiguration.thresholds[profile.level]
    }

    var body: some View {
        ZStack {
            ZStack(alignment: .bottom) {
                Color(red: 0.07, green: 0.065, blue: 0.13)
                Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
                LinearGradient(colors: [ArcadeTheme.cyan.opacity(0.18), .clear, ArcadeTheme.pink.opacity(0.16)], startPoint: .leading, endPoint: .trailing)
            }
            .ignoresSafeArea(.container, edges: .top)

            HStack(spacing: 8) {
                levelPanel
                    .frame(width: 186)

                HStack(spacing: 2) {
                    ForEach(GitaMainTab.allCases) { tab in
                        Button {
                            guard tab.isEnabled, selectedTab != tab else { return }
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) { selectedTab = tab }
                        } label: {
                            VStack(spacing: 0) {
                                Text(tab.title)
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .tracking(0.5)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.62)
                                if !tab.isEnabled {
                                    Text("SOON")
                                        .font(.system(size: 6, weight: .black, design: .monospaced))
                                        .foregroundStyle(ArcadeTheme.yellow)
                                }
                            }
                                .frame(maxWidth: .infinity, minHeight: 42)
                            .foregroundStyle(selectedTab == tab ? ArcadeTheme.background : .white)
                            .contentShape(ActiveNavShape())
                            .background {
                                if selectedTab == tab {
                                    ActiveNavShape()
                                        .fill(Color(red: 0.98, green: 0.91, blue: 0.76))
                                        .matchedGeometryEffect(id: "selected-tab", in: selectedTabAnimation)
                                }
                            }
                            .scaleEffect(selectedTab == tab ? 1 : 0.96)
                        }
                        .buttonStyle(GameNavButtonStyle())
                        .disabled(!tab.isEnabled)
                        .opacity(tab.isEnabled ? 1 : 0.48)
                        .accessibilityLabel(tab.title.capitalized)
                        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                    }
                }
                .frame(maxWidth: .infinity)

                gemPanel
                    .frame(width: 124)
            }
            .padding(.horizontal, 8)
            .safeAreaPadding(.horizontal, 6)
            .padding(.vertical, 5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
        .zIndex(10)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.72).repeatForever(autoreverses: true)) {
                flamePulse = true
            }
        }
    }

    private var levelPanel: some View {
        ZStack(alignment: .leading) {
            LevelXPPanelShape()
                .fill(Color(red: 0.13, green: 0.105, blue: 0.22))
                .overlay(LevelXPPanelShape().stroke(Color.white.opacity(0.06), lineWidth: 1))
                .frame(height: 43)
                .padding(.leading, 33)

            HStack(spacing: 8) {
                VStack(spacing: -1) {
                    Text("\(profile.level)")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                    Text("LEVEL")
                        .font(.system(size: 7, weight: .black, design: .rounded))
                        .tracking(0.55)
                }
                .foregroundStyle(ArcadeTheme.background)
                .frame(width: 46, height: 46)
                .background(LevelBadgeShape().fill(ArcadeTheme.cyan))
                .overlay(LevelBadgeShape().stroke(.white.opacity(0.9), lineWidth: 1.5))
                .shadow(color: ArcadeTheme.cyan.opacity(0.24), radius: 5)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Text("\(profile.totalXP) / \(nextLevelXP)")
                        Spacer(minLength: 2)
                        Text("XP")
                    }
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            XPBarShape().fill(Color.black.opacity(0.42))
                            XPBarShape().fill(ArcadeTheme.cyan)
                                .frame(width: geometry.size.width * profile.levelProgress)
                                .animation(.spring(response: 0.5, dampingFraction: 0.82), value: profile.levelProgress)
                        }
                    }
                    .frame(height: 9)
                }
                .padding(.trailing, 15)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level \(profile.level), \(profile.totalXP) experience points")
    }

    private var gemPanel: some View {
        HStack(spacing: 9) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                    .scaleEffect(flamePulse ? 1.16 : 0.9)
                    .rotationEffect(.degrees(flamePulse ? 3 : -3))
                    .shadow(color: .orange.opacity(flamePulse ? 0.75 : 0.25), radius: flamePulse ? 7 : 2)
                Text("\(profile.currentStreak)")
                    .font(.system(size: 15, weight: .black, design: .rounded))
            }
            Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1, height: 23)
            HStack(spacing: 5) {
                Image(systemName: "diamond.fill")
                    .foregroundStyle(ArcadeTheme.cyan)
                Text("\(profile.gems)")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .contentTransition(.numericText(value: Double(profile.gems)))
                    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: profile.gems)
            }
            .foregroundStyle(.white)
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity, minHeight: 43)
        .background(CurrencyPanelShape().fill(Color(red: 0.13, green: 0.105, blue: 0.22)))
        .overlay(CurrencyPanelShape().stroke(Color.white.opacity(0.06), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(profile.currentStreak) day streak, \(profile.streakFreezes) streak freezes, \(profile.gems) gems")
    }
}

private struct LevelBadgeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 6, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - 4, y: rect.minY + 2))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + 10))
        path.addLine(to: CGPoint(x: rect.maxX - 4, y: rect.maxY - 5))
        path.addLine(to: CGPoint(x: rect.maxX - 11, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + 4, y: rect.maxY - 3))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + 8))
        path.closeSubpath()
        return path
    }
}

private struct LevelXPPanelShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 8, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - 13, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - 13, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + 5, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct XPBarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 5, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - 7, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct ActiveNavShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 6, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - 5, y: rect.minY + 1))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + 7))
        path.addLine(to: CGPoint(x: rect.maxX - 3, y: rect.maxY - 2))
        path.addLine(to: CGPoint(x: rect.maxX - 10, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + 3, y: rect.maxY - 1))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + 6))
        path.closeSubpath()
        return path
    }
}

private struct CurrencyPanelShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 8, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - 4, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 7))
        path.addLine(to: CGPoint(x: rect.maxX - 10, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - 3))
        path.addLine(to: CGPoint(x: rect.minX + 5, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct GameNavButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

private struct PlayerSettingsView: View {
    let instrument: Instrument
    let isGuest: Bool
    let onHistory: () -> Void
    let onFretFinder: () -> Void
    let onChordLibrary: () -> Void
    let onRetune: () -> Void
    let onReplay: () -> Void
    let onSwitch: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("PLAYER SETTINGS")
                    .font(.caption.monospaced().weight(.black))
                    .tracking(3)
                    .foregroundStyle(ArcadeTheme.yellow)
                Text("Player tools")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                Text("Playing \(instrument.displayName)")
                    .foregroundStyle(ArcadeTheme.muted)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
                    settingButton("Tune", "Check every open string.", symbol: "tuningfork", action: onRetune)
                    settingButton("Replay tutorial", "Learn again with the Play interface.", symbol: "arrow.counterclockwise", action: onReplay)
                    settingButton("Chord library", "See the common chord shapes.", symbol: "rectangle.grid.2x2.fill", action: onChordLibrary)
                    settingButton("Play & detect", "Play a string and detect its note and fret.", symbol: "waveform.badge.mic", action: onFretFinder)
                }
            }
            .padding(24)
        }
        .background(ArcadeTheme.background.ignoresSafeArea())
    }

    private func settingButton(_ title: String, _ detail: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title2.weight(.black))
                    .foregroundStyle(ArcadeTheme.cyan)
                    .frame(width: 44, height: 44)
                    .background(ArcadeTheme.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline.weight(.black))
                    Text(detail).font(.caption).foregroundStyle(ArcadeTheme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(ArcadeTheme.muted)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 82)
            .background(ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}
