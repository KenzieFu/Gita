import AVFoundation
import SwiftUI

struct SongLibraryView: View {
    let songs: [SongChart]
    let scores: [SongScoreRecord]
    let audioURLForSong: (SongChart) -> URL?
    let previewRevision: Int
    let onSelect: (SongChart, SongSection, ArrangementTier?) -> Void
    let onImport: () -> Void

    @State private var searchText = ""
    @State private var sortOrder: SongSortOrder = .title
    @State private var selectedSongKey: String?
    @State private var selectedTier: ArrangementTier?
    @State private var previewPlayer: AVAudioPlayer?
    @State private var previewMuted = false
    @State private var previewUnavailable = false

    private var filteredSongs: [SongChart] {
        songs
            .filter { chart in
                let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                let matchesSearch = term.isEmpty || chart.title.localizedCaseInsensitiveContains(term) || chart.chordNames.contains { $0.localizedCaseInsensitiveContains(term) }
                let matchesMode = selectedTier.map { tier in
                    chart.experience?.availableTiers.contains(tier) == true
                } ?? true
                return matchesMode && matchesSearch
            }
            .sorted { left, right in
                switch sortOrder {
                case .title: return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
                case .difficulty:
                    let order: [SongDifficulty: Int] = [.easy: 0, .medium: 1, .hard: 2]
                    return order[left.difficulty, default: 0] == order[right.difficulty, default: 0]
                        ? left.title < right.title
                        : order[left.difficulty, default: 0] < order[right.difficulty, default: 0]
                case .tempo: return left.nominalBPM < right.nominalBPM
                }
            }
    }

    private var selectedSong: SongChart? {
        songs.first { $0.selectionKey == selectedSongKey }
    }

    private func displayedDifficulty(for chart: SongChart) -> SongDifficulty {
        selectedTier.map(\.selectionDifficulty) ?? chart.difficulty
    }

    private var loopedSongs: [LoopedSong] {
        guard filteredSongs.count > 1 else {
            return filteredSongs.enumerated().map { LoopedSong(cycle: 0, position: $0.offset, chart: $0.element) }
        }

        return (0..<15).flatMap { cycle in
            filteredSongs.enumerated().map { LoopedSong(cycle: cycle, position: $0.offset, chart: $0.element) }
        }
    }

    private var middleLoopID: String? {
        guard filteredSongs.count > 1 else { return loopedSongs.first?.id }
        return loopedSongs.first { $0.cycle == 7 && $0.position == 0 }?.id
    }

    var body: some View {
        GeometryReader { geometry in
            Group {
                if songs.isEmpty {
                    emptyState
                } else if geometry.size.width >= 720 {
                    HStack(spacing: 14) {
                        selectedSongPanel
                            .frame(width: min(270, geometry.size.width * 0.34))
                        songBrowser
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            selectedSongPanel
                            songBrowser
                        }
                        .padding(16)
                    }
                }
            }
            .background {
                ZStack {
                    ArcadeTheme.background
                    RadialGradient(colors: [ArcadeTheme.pink.opacity(0.22), .clear], center: .leading, startRadius: 20, endRadius: 520)
                    RadialGradient(colors: [ArcadeTheme.cyan.opacity(0.16), .clear], center: .trailing, startRadius: 20, endRadius: 500)
                }
                .ignoresSafeArea()
            }
        }
        .safeAreaPadding(.horizontal, 8)
        .preferredColorScheme(.dark)
        .onAppear {
            ensureSelection()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { playSelectedPreview() }
        }
        .onDisappear { stopPreview() }
        .onChange(of: selectedSongKey) { _, _ in playSelectedPreview() }
        .onChange(of: previewRevision) { _, _ in playSelectedPreview() }
        .onChange(of: songs.map(\.selectionKey)) { _, _ in ensureSelection() }
        .onChange(of: searchText) { _, _ in ensureVisibleSelection() }
        .onChange(of: selectedTier) { _, _ in ensureVisibleSelection() }
    }

    private var selectedSongPanel: some View {
        ScrollView {
            if let chart = selectedSong {
                VStack(alignment: .leading, spacing: 14) {
                    cover(for: chart)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(chart.title)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .lineLimit(2)
                        Text("\(chart.instrument.displayName) · \(Int(chart.nominalBPM.rounded())) BPM · \(chart.style.displayTitle)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ArcadeTheme.muted)
                    }

                    if !chart.chordNames.isEmpty {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("CHORDS IN THIS SONG").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(ArcadeTheme.yellow)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 7) {
                                    ForEach(chart.chordNames, id: \.self) { chord in
                                        Text(chord).font(.headline.monospaced().weight(.black)).padding(.horizontal, 12).padding(.vertical, 7).background(ArcadeTheme.cyan.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }
                    }

                    if let experience = chart.experience {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("SELECTED MODE").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(ArcadeTheme.yellow)
                            if let tier = selectedTier, let arrangement = experience.arrangement(for: tier) {
                                HStack(spacing: 9) {
                                    Text(tier.title.uppercased())
                                        .font(.system(size: 10, weight: .black, design: .rounded))
                                        .foregroundStyle(ArcadeTheme.background)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(ArcadeTheme.cyan, in: Capsule())
                                    Text(arrangement.chordIDs.joined(separator: " · "))
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(ArcadeTheme.muted)
                                }
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text("FULL SONG · \(time(chart.audioDurationSeconds))")
                        Spacer()
                        Button {
                            previewMuted.toggle()
                            previewMuted ? stopPreview() : playSelectedPreview()
                        } label: {
                            Label(
                                previewUnavailable ? "AUDIO UNAVAILABLE" : (previewMuted ? "PREVIEW OFF" : "NOW PREVIEWING"),
                                systemImage: previewMuted || previewUnavailable ? "speaker.slash.fill" : "speaker.wave.2.fill"
                            )
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(previewUnavailable ? .red : ArcadeTheme.cyan)
                    }
                    .font(.caption.monospaced().weight(.black))
                    .foregroundStyle(ArcadeTheme.yellow)

                }
                .padding(16)
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                .id(chart.selectionKey)
            }
        }
        .animation(.smooth(duration: 0.25), value: selectedSongKey)
        .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 18))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var songBrowser: some View {
        VStack(spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    searchField
                    sortPicker
                    importButton
                }
                VStack(spacing: 7) {
                    searchField
                    HStack(spacing: 8) {
                        sortPicker
                        importButton
                    }
                }
            }

            HStack(spacing: 7) {
                ForEach(ArrangementTier.allCases) { tier in
                    modeCategoryButton(tier)
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 5) {
                        if filteredSongs.isEmpty {
                            ContentUnavailableView("No matching songs", systemImage: "music.note.list", description: Text("Try another search or play mode."))
                                .foregroundStyle(ArcadeTheme.muted)
                                .padding(.top, 35)
                        }
                        ForEach(loopedSongs) { item in
                            songRow(item.chart)
                                .padding(.leading, rowIndent(item.position))
                                .padding(.trailing, max(0, 28 - rowIndent(item.position)))
                                .id(item.id)
                        }
                    }
                    .padding(.vertical, 18)
                }
                .scrollIndicators(.hidden)
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.08),
                            .init(color: .black, location: 0.92),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .onAppear {
                    guard let middleLoopID else { return }
                    DispatchQueue.main.async { proxy.scrollTo(middleLoopID, anchor: .center) }
                }
                .onChange(of: filteredSongs.map(\.selectionKey)) { _, _ in
                    guard let middleLoopID else { return }
                    DispatchQueue.main.async { proxy.scrollTo(middleLoopID, anchor: .center) }
                }
            }

            HStack(spacing: 12) {
                Label("FINGERSTYLE COMING SOON", systemImage: "lock.fill")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(ArcadeTheme.muted)
                    .lineLimit(1)
                Spacer(minLength: 8)
                startButton
            }
        }
        .padding(14)
        .background(Color(red: 0.04, green: 0.045, blue: 0.10).opacity(0.76), in: RoundedRectangle(cornerRadius: 18))
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(ArcadeTheme.muted)
            TextField("Song title or chord", text: $searchText)
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 11)
        .frame(maxWidth: .infinity, minHeight: 38, maxHeight: 38)
        .background(ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 10))
    }

    private var sortPicker: some View {
        Picker("Sort", selection: $sortOrder) {
            ForEach(SongSortOrder.allCases) { order in Text(order.title).tag(order) }
        }
        .pickerStyle(.menu)
        .tint(.white)
        .frame(minWidth: 92, minHeight: 38, maxHeight: 38)
        .background(ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 10))
    }

    private var importButton: some View {
        Button(action: onImport) {
            Label("IMPORT", systemImage: "square.and.arrow.down.fill")
                .font(.system(size: 9, weight: .black, design: .rounded))
                .padding(.horizontal, 10)
                .frame(minHeight: 38)
                .foregroundStyle(ArcadeTheme.background)
                .background(ArcadeTheme.cyan, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(ArcadePressButtonStyle())
        .accessibilityLabel("Import chart and audio")
    }

    private var startButton: some View {
        Button {
            guard let chart = selectedSong else { return }
            stopPreview()
            onSelect(chart, chart.fullSongSection, selectedTier)
        } label: {
            HStack(spacing: 10) {
                Text("START!")
                    .font(.system(size: 20, weight: .black, design: .rounded).italic())
                Image(systemName: "play.fill")
            }
            .padding(.horizontal, 26)
            .frame(minHeight: 48)
            .foregroundStyle(ArcadeTheme.background)
            .background(StartButtonShape().fill(ArcadeTheme.yellow))
            .overlay(StartButtonShape().stroke(Color.white.opacity(0.45), lineWidth: 1))
            .shadow(color: ArcadeTheme.yellow.opacity(0.34), radius: 14, y: 5)
        }
        .buttonStyle(ArcadePressButtonStyle())
        .disabled(selectedSong == nil)
    }

    private func rowIndent(_ position: Int) -> CGFloat {
        let pattern: [CGFloat] = [26, 12, 0, 12, 26, 16]
        return pattern[position % pattern.count]
    }

    private func songRow(_ chart: SongChart) -> some View {
        let selected = selectedSongKey == chart.selectionKey
        let score = selectedTier.flatMap { tier in
            scores.first {
                $0.songID == chart.id && $0.songVersion == chart.version && $0.tier == tier
            }
        }
        return Button { select(chart) } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(coverGradient(for: chart))
                    Image(systemName: chart.style == .basicStrum ? "guitars.fill" : "music.note")
                        .font(.title2.weight(.black)).foregroundStyle(.white)
                }
                .frame(width: 58, height: 58)
                VStack(alignment: .leading, spacing: 4) {
                    Text(chart.title).font(.headline.weight(.black)).lineLimit(1)
                    Text("\(chart.instrument.displayName) · \(Int(chart.nominalBPM.rounded())) BPM").font(.caption).foregroundStyle(ArcadeTheme.muted)
                    HStack(spacing: 7) {
                        difficultyBadge(displayedDifficulty(for: chart))
                        difficultyStars(displayedDifficulty(for: chart))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(score.map { "BEST \($0.bestScore)" } ?? "NO SCORE")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(score == nil ? ArcadeTheme.muted : ArcadeTheme.yellow)
                    if let score {
                        Text("\(score.totalPlays) PLAY\(score.totalPlays == 1 ? "" : "S")")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundStyle(selected ? ArcadeTheme.background.opacity(0.65) : ArcadeTheme.muted)
                    }
                }
                Image(systemName: selected ? "play.circle.fill" : "chevron.right")
                    .font(.title3.weight(.black))
                    .foregroundStyle(selected ? ArcadeTheme.pink : ArcadeTheme.muted)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Color.white.opacity(0.94) : ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 11))
            .foregroundStyle(selected ? ArcadeTheme.background : .white)
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(selected ? ArcadeTheme.cyan : Color.white.opacity(0.07), lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(ArcadePressButtonStyle())
    }

    private func cover(for chart: SongChart) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 22).fill(coverGradient(for: chart))
            Image(systemName: chart.style == .basicStrum ? "guitars.fill" : "music.note")
                .font(.system(size: 88, weight: .black))
                .foregroundStyle(.white.opacity(0.22))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: 22))
            HStack {
                difficultyBadge(displayedDifficulty(for: chart))
                Spacer()
                Text("LOCAL CHART").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.8))
            }
            .padding(15)
        }
        .frame(height: 158)
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(ArcadeTheme.cyan.opacity(0.55), lineWidth: 1))
        .shadow(color: ArcadeTheme.pink.opacity(0.22), radius: 20, y: 8)
    }

    private func modeCategoryButton(_ tier: ArrangementTier) -> some View {
        let selected = selectedTier == tier
        let detail = tier.learningChordIDs.map { "\($0.count) CHORDS" } ?? "ALL CHORDS"
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { selectedTier = tier }
        } label: {
            VStack(spacing: 1) {
                Text(tier.title.uppercased())
                    .font(.system(size: 11, weight: .black, design: .rounded))
                Text(detail)
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .opacity(0.72)
            }
                .frame(maxWidth: .infinity, minHeight: 40)
                .foregroundStyle(selected ? ArcadeTheme.background : ArcadeTheme.muted)
                .background(selected ? ArcadeTheme.cyan : ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? Color.white.opacity(0.65) : Color.white.opacity(0.08)))
        }
        .buttonStyle(ArcadePressButtonStyle())
        .accessibilityLabel("\(tier.title), \(detail)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func difficultyBadge(_ difficulty: SongDifficulty) -> some View {
        Text(difficulty.rawValue.uppercased())
            .font(.system(size: 8, weight: .black, design: .monospaced))
            .foregroundStyle(difficulty.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(difficulty.color.opacity(0.14), in: Capsule())
            .overlay(Capsule().stroke(difficulty.color.opacity(0.75), lineWidth: 1))
    }

    private func difficultyStars(_ difficulty: SongDifficulty) -> some View {
        let filled = difficulty == .easy ? 2 : difficulty == .medium ? 4 : 6
        return HStack(spacing: 2) {
            ForEach(0..<6, id: \.self) { index in
                Image(systemName: index < filled ? "star.fill" : "star")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(index < filled ? difficulty.color : ArcadeTheme.muted.opacity(0.45))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 15) {
            Image(systemName: "music.note.list").font(.system(size: 56, weight: .black)).foregroundStyle(ArcadeTheme.cyan)
            Text("Your song list is empty").font(.title2.weight(.black))
            Text("Import a Gita chart and its matching MP3/M4A to begin.").foregroundStyle(ArcadeTheme.muted)
            Button(action: onImport) { Label("Import first song", systemImage: "plus.circle.fill") }.buttonStyle(.borderedProminent).tint(ArcadeTheme.cyan)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func select(_ chart: SongChart) {
        let preferredTier = selectedTier
        withAnimation(.smooth(duration: 0.25)) {
            selectedSongKey = chart.selectionKey
            if let preferredTier,
               chart.experience?.availableTiers.contains(preferredTier) == true {
                selectedTier = preferredTier
            } else {
                selectedTier = chart.experience?.defaultTier
            }
        }
    }

    private func ensureSelection() {
        guard let current = selectedSong, songs.contains(where: { $0.selectionKey == current.selectionKey }) else {
            if let first = songs.first { select(first) }
            return
        }
        if let experience = current.experience, selectedTier == nil || !experience.availableTiers.contains(selectedTier!) { selectedTier = experience.defaultTier }
    }

    private func ensureVisibleSelection() {
        if let current = selectedSong, filteredSongs.contains(where: { $0.selectionKey == current.selectionKey }) { return }
        if let first = filteredSongs.first { select(first) }
        else { selectedSongKey = nil; selectedTier = nil }
    }

    private func playSelectedPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
        previewUnavailable = false
        guard !previewMuted, let chart = selectedSong, let url = audioURLForSong(chart) else {
            if !previewMuted { previewUnavailable = true }
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0.38
            player.currentTime = min(max(0, chart.firstBeatOffsetSeconds), max(0, player.duration - 1))
            player.prepareToPlay()
            guard player.play() else { throw SongPreviewError.couldNotStart }
            previewPlayer = player
        } catch {
            previewUnavailable = true
        }
    }

    private func stopPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
    }

    private func coverGradient(for chart: SongChart) -> LinearGradient {
        switch displayedDifficulty(for: chart) {
        case .easy: LinearGradient(colors: [ArcadeTheme.cyan, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .medium: LinearGradient(colors: [ArcadeTheme.pink, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .hard: LinearGradient(colors: [Color.orange, ArcadeTheme.pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func time(_ seconds: Double) -> String {
        String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }
}

private enum SongPreviewError: Error {
    case couldNotStart
}

private struct LoopedSong: Identifiable {
    let cycle: Int
    let position: Int
    let chart: SongChart

    var id: String { "\(cycle)-\(position)-\(chart.selectionKey)" }
}

private struct StartButtonShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            let cut = min(13, rect.height * 0.28)
            path.move(to: CGPoint(x: cut, y: 0))
            path.addLine(to: CGPoint(x: rect.maxX, y: 0))
            path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
            path.addLine(to: CGPoint(x: 0, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private enum SongSortOrder: String, CaseIterable, Identifiable {
    case title
    case difficulty
    case tempo
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

private extension SongChart {
    var selectionKey: String { "\(id)-v\(version)" }
}

private extension SongPlayStyle {
    var displayTitle: String { self == .singleNote ? "Single notes" : "Chord strums" }
}

private extension SongDifficulty {
    var color: Color {
        switch self {
        case .easy: ArcadeTheme.green
        case .medium: ArcadeTheme.cyan
        case .hard: ArcadeTheme.pink
        }
    }
}

private struct ArcadePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}
