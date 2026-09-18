import SwiftUI

struct RhythmPlaySurface: View {
    let chart: SongChart
    let section: SongSection
    let tier: ArrangementTier
    let position: Double
    let rate: Double
    let grade: PracticeGrade?
    let feedbackSequence: Int
    let combo: Int
    let consumedCueOnsets: Set<Double>
    let judgedCueGrades: [Double: PracticeGrade]
    var hintCardWidth: CGFloat? = nil
    var hintTitle: String? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var timeline: RhythmTimeline { RhythmTimeline(chart: chart, tier: tier, section: section) }
    private var pendingEvents: [RhythmEvent] {
        timeline.events.filter { event in
            !consumedCueOnsets.contains(where: { abs($0 - event.onset) < 0.001 })
        }
    }
    private func judgedGrade(for event: RhythmEvent) -> PracticeGrade? {
        judgedCueGrades.first(where: { abs($0.key - event.onset) < 0.001 })?.value
    }
    private func color(for grade: PracticeGrade) -> Color {
        switch grade {
        case .perfect: ArcadeTheme.yellow
        case .great: .purple
        case .good: .green
        case .miss: .red
        }
    }
    private var targetIndex: Int? {
        pendingEvents.firstIndex { $0.onset + 0.35 * rate >= position }
    }
    private var target: RhythmEvent? { targetIndex.flatMap { pendingEvents[safe: $0] } }
    private var next: RhythmEvent? {
        guard let index = targetIndex, pendingEvents.indices.contains(index + 1) else { return nil }
        return pendingEvents[safe: index + 1]
    }
    private var modeChords: [ChordDefinition] {
        guard let experience = chart.experience,
              let arrangement = experience.arrangement(for: tier) else { return [] }
        return arrangement.chordIDs.compactMap { experience.chord(id: $0) }
    }
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = finiteDimension(geometry.size.width)
            HStack(spacing: 10) {
                chordOverview
                    .frame(width: hintCardWidth ?? (modeChords.count <= 3 ? 76 : min(132, availableWidth * 0.18)))

                highway
                VStack(spacing: 8) {
                    Text("COMBO").font(.caption2.monospaced().weight(.black)).tracking(2)
                    Text(combo == 0 ? "—" : String(combo))
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .contentTransition(.numericText())
                    Spacer()
                    if let grade {
                        VStack(spacing: 6) {
                            Image(systemName: grade == .miss ? "arrow.right" : "sparkles")
                            Text(grade.rawValue.uppercased())
                                .font(.system(size: 21, weight: .black, design: .rounded))
                                .minimumScaleFactor(0.6).lineLimit(1)
                            Text(grade == .miss ? "Next one!" : "Keep it going!")
                                .font(.caption2)
                        }
                        .foregroundStyle(feedbackColor)
                        .shadow(color: feedbackColor.opacity(0.6), radius: 10)
                        .id(feedbackSequence)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.7).combined(with: .opacity))
                        .accessibilityLabel("\(grade.rawValue) judgement")
                    } else {
                        Text("STRUM AT\nTHE LINE")
                            .font(.caption2.monospaced().weight(.bold))
                            .foregroundStyle(ArcadeTheme.muted)
                    }
                    Spacer().frame(height: 22)
                }
                .multilineTextAlignment(.center)
                .foregroundStyle(ArcadeTheme.cyan)
                .frame(width: min(115, availableWidth * 0.15))
                .padding(.top, 12)
            }
        }
    }

    private var chordOverview: some View {
        VStack(spacing: 5) {
            Text(hintTitle ?? "\(tier.title.uppercased()) CHORDS")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(ArcadeTheme.yellow)
                .lineLimit(1)

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.fixed(52), spacing: 5),
                    count: modeChords.count <= 3 ? 1 : 2
                ),
                spacing: 5
            ) {
                ForEach(modeChords) { chord in
                    let isCurrent = target?.name == chord.displayName
                    let isNext = !isCurrent && next?.name == chord.displayName
                    VStack(spacing: 0) {
                        Text(chord.displayName)
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(isCurrent ? ArcadeTheme.cyan : isNext ? ArcadeTheme.yellow : .white)
                        RhythmChordDiagram(
                            frets: chord.frets,
                            labels: chart.stringLabels,
                            color: isCurrent ? ArcadeTheme.cyan : isNext ? ArcadeTheme.yellow : .white.opacity(0.7),
                            compact: true
                        )
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background((isCurrent ? ArcadeTheme.cyan : isNext ? ArcadeTheme.yellow : ArcadeTheme.panel).opacity(isCurrent || isNext ? 0.16 : 0.8), in: RoundedRectangle(cornerRadius: 9))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(isCurrent ? ArcadeTheme.cyan : isNext ? ArcadeTheme.yellow : .white.opacity(0.12), lineWidth: isCurrent ? 2 : 1)
                    }
                    .animation(.smooth(duration: 0.18), value: target?.id)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tier.title) chords: \(modeChords.map(\.displayName).joined(separator: ", "))")
    }

    private var feedbackColor: Color {
        switch grade {
        case .perfect: ArcadeTheme.yellow
        case .great: Color.purple
        case .good: .green
        case .miss: .red
        case nil: ArcadeTheme.cyan
        }
    }

    private var highway: some View {
        GeometryReader { geometry in
            let width = finiteDimension(geometry.size.width)
            let height = finiteDimension(geometry.size.height)
            let layoutIsReady = width >= 2 && height >= 2
            let top = min(12, height * 0.08)
            let hitY = max(top, min(height, height * 0.84))
            let safePosition = position.isFinite ? min(max(position, 0), chart.audioDurationSeconds) : section.startSeconds
            let safeRate = rate.isFinite ? max(0.01, rate) : 1
            if layoutIsReady {
              ZStack {
                Canvas { context, size in
                    var track = Path()
                    track.move(to: CGPoint(x: width * 0.34, y: top))
                    track.addLine(to: CGPoint(x: width * 0.66, y: top))
                    track.addLine(to: CGPoint(x: width * 0.97, y: height))
                    track.addLine(to: CGPoint(x: width * 0.03, y: height))
                    track.closeSubpath()
                    context.fill(track, with: .linearGradient(Gradient(colors: [ArcadeTheme.panel.opacity(0.5), ArcadeTheme.cyan.opacity(0.12)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: height)))
                    context.stroke(track, with: .color(ArcadeTheme.cyan.opacity(0.35)), lineWidth: 1.5)
                    let laneCount = max(1, chart.stringLabels.count)
                    for index in 0...laneCount {
                        let fraction = CGFloat(index) / CGFloat(laneCount)
                        var lane = Path()
                        lane.move(to: CGPoint(x: width * (0.34 + 0.32 * fraction), y: top))
                        lane.addLine(to: CGPoint(x: width * (0.03 + 0.94 * fraction), y: height))
                        context.stroke(lane, with: .color(.white.opacity(0.12)), lineWidth: 1)
                    }
                    let beatSeconds = 60 / chart.nominalBPM
                    let startBeat = Int(floor((safePosition - chart.firstBeatOffsetSeconds) / beatSeconds))
                    for beat in startBeat...(startBeat + Int(ceil(4 * safeRate / beatSeconds)) + 1) {
                        let onset = chart.firstBeatOffsetSeconds + Double(beat) * beatSeconds
                        let p = RhythmTimeline.approach(onset: onset, position: safePosition, rate: safeRate)
                        if p >= 0 && p <= 1.15 {
                            let y = top + CGFloat(p) * (hitY - top)
                            let verticalRatio = min(max(y / height, 0), 1.15)
                            let half = finiteDimension(width * (0.16 + 0.31 * verticalRatio))
                            var line = Path()
                            line.move(to: CGPoint(x: width / 2 - half, y: y))
                            line.addLine(to: CGPoint(x: width / 2 + half, y: y))
                            context.stroke(line, with: .color(.white.opacity(0.12)), lineWidth: 1)
                        }
                    }
                }
                ForEach(timeline.events.filter { event in
                    let p = RhythmTimeline.approach(onset: event.onset, position: safePosition, rate: safeRate)
                    let isPending = !consumedCueOnsets.contains(where: { abs($0 - event.onset) < 0.001 })
                    let isShowingJudgement = judgedGrade(for: event) != nil
                    return p >= 0 && p <= 1.15 && (isPending || isShowingJudgement)
                }) { event in
                    let progress = RhythmTimeline.approach(onset: event.onset, position: safePosition, rate: safeRate)
                    let y = top + CGFloat(progress) * (hitY - top)
                    let verticalRatio = min(max(y / height, 0), 1.15)
                    let noteWidth = finiteDimension(width * (0.32 + 0.62 * verticalRatio), minimum: 1)
                    let noteHeight = finiteDimension(18 + 15 * progress, minimum: 1)
                    let resultGrade = judgedGrade(for: event)
                    let noteColor = resultGrade.map(color(for:)) ?? ArcadeTheme.cyan
                    Text(event.name)
                        .font(.system(size: 14 + 8 * progress, weight: .black, design: .rounded))
                        .foregroundStyle(ArcadeTheme.background)
                        .frame(width: noteWidth, height: noteHeight)
                        .background(noteColor, in: RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(.white.opacity(0.7), lineWidth: 1))
                        .shadow(color: noteColor.opacity(0.7), radius: resultGrade == nil ? 8 : 16)
                        .position(x: width / 2, y: y)
                        .transition(.opacity)
                }
                // A bounded target is easier to read than a single hit line. The
                // entire box is the acceptable strum area; its center is the ideal beat.
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill((grade == nil ? ArcadeTheme.yellow : feedbackColor).opacity(0.18))
                        .frame(width: width * 0.86, height: 42)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(grade == nil ? ArcadeTheme.yellow : feedbackColor, lineWidth: grade == nil ? 2 : 4)
                        }
                        .shadow(color: (grade == nil ? ArcadeTheme.yellow : feedbackColor).opacity(0.75), radius: grade == nil ? 8 : 18)
                    Rectangle()
                        .fill(grade == nil ? ArcadeTheme.yellow : feedbackColor)
                        .frame(width: width * 0.86, height: 4)
                    Text(timeline.events.isEmpty ? "No cues in this section" : "STRUM ZONE")
                        .font(.system(size: 9, weight: .black, design: .monospaced)).tracking(2)
                        .foregroundStyle(grade == nil ? ArcadeTheme.yellow : feedbackColor)
                        .offset(y: 26)
                }
                .position(x: width / 2, y: hitY)
                .modifier(JudgementShake(animatableData: CGFloat(feedbackSequence), enabled: !reduceMotion))
                .animation(.linear(duration: 0.22), value: feedbackSequence)
                .accessibilityLabel(grade.map { "\($0.rawValue) judgement" } ?? "Strum zone")
            }
            .clipped()
            } else {
                // A physical device can report a zero-sized geometry for one pass
                // while presenting or rotating into landscape. Wait for the next
                // layout pass instead of producing an infinite/NaN note frame.
                Color.clear
            }
        }
        .accessibilityLabel("Descending notes. Play when each bar reaches the yellow line.")
    }
}

/// SwiftUI occasionally supplies a transient zero/non-finite geometry while a
/// full-screen view rotates on a physical device. Frame dimensions must always
/// remain finite and non-negative.
private func finiteDimension(_ value: CGFloat, minimum: CGFloat = 0) -> CGFloat {
    guard value.isFinite else { return minimum }
    return max(minimum, value)
}

private struct JudgementShake: GeometryEffect {
    var animatableData: CGFloat
    let enabled: Bool

    func effectValue(size: CGSize) -> ProjectionTransform {
        guard enabled else { return ProjectionTransform(.identity) }
        let horizontal = 3 * sin(animatableData * .pi * 5)
        return ProjectionTransform(CGAffineTransform(translationX: horizontal, y: 0))
    }
}

/// All markers share the string x-coordinate; fretted markers sit BETWEEN frets.
private struct RhythmChordDiagram: View {
    let frets: [Int?]
    let labels: [String]
    let color: Color
    var compact = false

    var body: some View {
        Canvas { context, size in
            let left: CGFloat = compact ? 5 : 10
            let top: CGFloat = compact ? 10 : 20
            let bottom = size.height - (compact ? 8 : 16)
            let step = (bottom - top) / 4
            let highest = frets.compactMap { $0 }.max() ?? 0
            let firstFret = highest <= 4 ? 1 : max(1, (frets.compactMap { $0 }.filter { $0 > 0 }.min() ?? 1))
            for fret in 0...4 {
                var path = Path()
                path.move(to: CGPoint(x: left, y: top + CGFloat(fret) * step))
                path.addLine(to: CGPoint(x: size.width - left, y: top + CGFloat(fret) * step))
                context.stroke(path, with: .color(.white.opacity(0.35)), lineWidth: fret == 0 && firstFret == 1 ? 3 : 1)
            }
            for index in frets.indices {
                let x = left + CGFloat(index) * (size.width - 2 * left) / CGFloat(max(1, frets.count - 1))
                var path = Path()
                path.move(to: CGPoint(x: x, y: top))
                path.addLine(to: CGPoint(x: x, y: bottom))
                context.stroke(path, with: .color(.white.opacity(0.5)), lineWidth: 1)
                if let fret = frets[index], fret > 0 {
                    let y = top + (CGFloat(fret - firstFret) + 0.5) * step
                    let radius: CGFloat = compact ? 4.5 : 7
                    let dot = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                    context.fill(dot, with: .color(color))
                    context.draw(Text(String(fret)).font(.system(size: compact ? 6 : 9, weight: .black)).foregroundStyle(ArcadeTheme.background), at: CGPoint(x: x, y: y))
                } else {
                    context.draw(Text(frets[index] == nil ? "×" : "○").font(.system(size: compact ? 8 : 12, weight: .bold)).foregroundStyle(color), at: CGPoint(x: x, y: compact ? 5 : 9))
                }
                context.draw(Text(labels[safe: index] ?? "?").font(.system(size: compact ? 6 : 8, weight: .bold)).foregroundStyle(.white.opacity(0.7)), at: CGPoint(x: x, y: size.height - (compact ? 3 : 5)))
            }
        }
        .frame(
            minWidth: compact ? 42 : 60,
            idealWidth: compact ? 42 : 80,
            maxWidth: compact ? 42 : 90,
            minHeight: compact ? 38 : nil,
            idealHeight: compact ? 38 : nil,
            maxHeight: compact ? 38 : nil
        )
        .accessibilityLabel(zip(labels, frets).map { "\($0.0) \($0.1.map { $0 == 0 ? "open" : "fret \($0)" } ?? "muted")" }.joined(separator: ", "))
    }
}
