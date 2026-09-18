import SwiftUI

struct SongPlayResultView: View {
    let result: SongPlayResult
    let onClose: () -> Void

    @State private var firePulse = false
    @State private var showDailyChest = false
    @State private var chestOpened = false
    @State private var revealRewardCards = false

    private var gradeCounts: [(String, Int, Color)] {
        [
            ("PERFECT", result.take.hits.filter { $0.grade == .perfect }.count, ArcadeTheme.yellow),
            ("GREAT", result.take.hits.filter { $0.grade == .great }.count, .purple),
            ("GOOD", result.take.hits.filter { $0.grade == .good }.count, .green),
            ("MISS", result.take.hits.filter { $0.grade == .miss }.count, .red),
        ]
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 24) {
                VStack(spacing: 10) {
                    Text(result.heading)
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(result.didPass ? ArcadeTheme.yellow : .red)
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.1), lineWidth: 14)
                        Circle()
                            .trim(from: 0, to: CGFloat(result.score) / 100)
                            .stroke(result.didPass ? ArcadeTheme.cyan : Color.red, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 0) {
                            Text("\(result.score)")
                                .font(.system(size: 48, weight: .black, design: .rounded))
                            Text("SCORE")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(ArcadeTheme.muted)
                        }
                    }
                    .frame(width: 150, height: 150)
                    Text(result.songTitle).font(.headline.weight(.black)).lineLimit(1)
                    Text("\(result.tier.title) · Best \(result.bestScore)")
                        .font(.caption.monospaced().weight(.bold))
                        .foregroundStyle(ArcadeTheme.muted)
                    Text("\(Int((result.take.accuracy * 100).rounded()))% note match · \(result.take.hitCount)/\(result.take.noteCount)")
                        .font(.caption2.monospaced().weight(.bold))
                        .foregroundStyle(ArcadeTheme.muted)
                    if result.isDailyTask && !result.didPass {
                        Text("60% needed to complete")
                            .font(.caption2.monospaced().weight(.black))
                            .foregroundStyle(.red)
                    }
                }
                .frame(width: min(250, geometry.size.width * 0.3))

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        ForEach(gradeCounts, id: \.0) { item in
                            metric(item.0, value: "\(item.1)", color: item.2)
                        }
                    }

                    HStack(spacing: 10) {
                        reward("+\(result.earnedXP) XP", symbol: "bolt.fill", color: ArcadeTheme.yellow)
                        reward("+\(result.earnedGems) GEMS", symbol: "diamond.fill", color: ArcadeTheme.cyan)
                        streakReward
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(result.levelAfter > result.levelBefore ? "LEVEL UP!" : "LEVEL \(result.levelAfter)")
                                .font(.headline.weight(.black))
                                .foregroundStyle(result.levelAfter > result.levelBefore ? ArcadeTheme.yellow : .white)
                            Text("\(result.totalXP) total XP · \(result.gems) gems")
                                .font(.caption.monospaced())
                                .foregroundStyle(ArcadeTheme.muted)
                            Text(result.recordingMessage)
                                .font(.caption)
                                .foregroundStyle(ArcadeTheme.muted)
                                .lineLimit(2)
                        }
                        Spacer()
                        Button(action: onClose) {
                            Label(result.isDailyTask ? "Back to daily tasks" : "Back to songs", systemImage: result.isDailyTask ? "checklist" : "music.note.list")
                                .font(.headline.weight(.black))
                                .padding(.horizontal, 20)
                                .frame(minHeight: 48)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ArcadeTheme.cyan)
                    }
                    .padding(14)
                    .background(ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(24)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background {
                ZStack {
                    ArcadeTheme.background
                    RadialGradient(colors: [ArcadeTheme.cyan.opacity(0.18), .clear], center: .leading, startRadius: 10, endRadius: 460)
                    RadialGradient(colors: [ArcadeTheme.pink.opacity(0.14), .clear], center: .trailing, startRadius: 10, endRadius: 430)
                }
                .ignoresSafeArea()
            }
        }
        .overlay {
            if showDailyChest, let bonus = result.rewards.first(where: { $0.id.hasSuffix(":complete") }) {
                DailyRewardChestOverlay(
                    reward: bonus,
                    freezeBalance: result.streakFreezesAvailable,
                    opened: chestOpened,
                    revealCards: revealRewardCards
                ) {
                    withAnimation(.easeInOut(duration: 0.25)) { showDailyChest = false }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                firePulse = true
            }
            guard result.unlockedDailyChest else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.74)) { showDailyChest = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.spring(response: 0.48, dampingFraction: 0.62)) { chestOpened = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.65) {
                withAnimation(.spring(response: 0.52, dampingFraction: 0.72)) { revealRewardCards = true }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func metric(_ title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(color)
            Text(value).font(.title2.monospaced().weight(.black))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 12))
    }

    private func reward(_ title: String, symbol: String, color: Color) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 11, weight: .black, design: .monospaced))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.35)))
    }

    private var streakReward: some View {
        HStack(spacing: 7) {
            ZStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.red.opacity(0.8))
                    .scaleEffect(firePulse ? 1.2 : 0.9)
                    .blur(radius: firePulse ? 3 : 1)
                Image(systemName: "flame.fill")
                    .foregroundStyle(.yellow, .orange)
                    .scaleEffect(firePulse ? 1.06 : 0.94)
                    .rotationEffect(.degrees(firePulse ? 3 : -3))
            }
            Text("\(result.streak) DAY STREAK")
        }
        .font(.system(size: 11, weight: .black, design: .monospaced))
        .foregroundStyle(.orange)
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(firePulse ? 0.65 : 0.3)))
        .shadow(color: .orange.opacity(firePulse ? 0.45 : 0.15), radius: firePulse ? 10 : 4)
    }
}

private struct DailyRewardChestOverlay: View {
    let reward: RewardTransaction
    let freezeBalance: Int
    let opened: Bool
    let revealCards: Bool
    let onCollect: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            RadialGradient(colors: [ArcadeTheme.yellow.opacity(0.24), .clear], center: .center, startRadius: 10, endRadius: 380)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("DAILY PATH COMPLETE")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(ArcadeTheme.yellow)

                RewardChest(opened: opened)
                    .frame(width: 132, height: 96)

                HStack(spacing: 12) {
                    RewardRevealCard(title: "+\(reward.xp)", subtitle: "XP", symbol: "bolt.fill", color: ArcadeTheme.yellow, delay: 0)
                    RewardRevealCard(title: "+\(reward.gems)", subtitle: "GEMS", symbol: "diamond.fill", color: ArcadeTheme.cyan, delay: 0.08)
                    RewardRevealCard(
                        title: reward.streakFreezes > 0 ? "+\(reward.streakFreezes)" : "MAX",
                        subtitle: "STREAK FREEZE",
                        symbol: "snowflake",
                        color: .blue,
                        delay: 0.16
                    )
                }
                .opacity(revealCards ? 1 : 0)
                .offset(y: revealCards ? 0 : 24)

                Text("You now have \(freezeBalance) freeze\(freezeBalance == 1 ? "" : "s"). One freeze protects your streak after one missed day.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ArcadeTheme.muted)
                    .multilineTextAlignment(.center)
                    .opacity(revealCards ? 1 : 0)

                Button(action: onCollect) {
                    Text("COLLECT")
                        .font(.headline.weight(.black))
                        .frame(minWidth: 150, minHeight: 42)
                }
                .buttonStyle(.borderedProminent)
                .tint(ArcadeTheme.yellow)
                .foregroundStyle(ArcadeTheme.background)
                .opacity(revealCards ? 1 : 0)
                .disabled(!revealCards)
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 20)
            .background(ArcadeTheme.panel.opacity(0.98), in: RoundedRectangle(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(ArcadeTheme.yellow.opacity(0.55), lineWidth: 2))
            .shadow(color: ArcadeTheme.yellow.opacity(0.32), radius: 28)
        }
    }
}

private struct RewardChest: View {
    let opened: Bool

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                Circle()
                    .fill(index.isMultiple(of: 2) ? ArcadeTheme.yellow : ArcadeTheme.cyan)
                    .frame(width: 5, height: 5)
                    .offset(x: opened ? cos(Double(index) * .pi / 4) * 72 : 0,
                            y: opened ? sin(Double(index) * .pi / 4) * 48 - 18 : 8)
                    .opacity(opened ? 1 : 0)
            }
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(colors: [Color.orange, ArcadeTheme.yellow], startPoint: .top, endPoint: .bottom))
                .frame(width: 116, height: 55)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.7), lineWidth: 2))
                .offset(y: 19)
            RoundedRectangle(cornerRadius: 9)
                .fill(LinearGradient(colors: [ArcadeTheme.yellow, Color.orange], startPoint: .top, endPoint: .bottom))
                .frame(width: 124, height: 34)
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(0.8), lineWidth: 2))
                .rotationEffect(.degrees(opened ? -14 : 0), anchor: .bottomLeading)
                .offset(x: opened ? -8 : 0, y: opened ? -28 : -8)
            Image(systemName: "music.note")
                .font(.title2.weight(.black))
                .foregroundStyle(ArcadeTheme.background)
                .offset(y: 20)
        }
        .scaleEffect(opened ? 1.08 : 0.94)
        .shadow(color: ArcadeTheme.yellow.opacity(opened ? 0.8 : 0.28), radius: opened ? 24 : 8)
    }
}

private struct RewardRevealCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color
    let delay: Double

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: symbol).font(.title2.weight(.black)).foregroundStyle(color)
            Text(title).font(.title3.monospaced().weight(.black))
            Text(subtitle)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(ArcadeTheme.muted)
        }
        .frame(width: 112, height: 82)
        .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.55)))
        .transition(.scale(scale: 0.65).combined(with: .opacity))
        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay), value: title)
    }
}
