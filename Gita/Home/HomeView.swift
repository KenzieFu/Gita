import SwiftUI

struct HomeView: View {
    @ObservedObject var model: PlayerProgressModel
    let instrument: Instrument
    let isGuest: Bool
    let onPractice: () -> Void
    let onHistory: () -> Void
    let onFretFinder: () -> Void
    let onRetune: () -> Void
    let onReplay: () -> Void
    let onSwitch: () -> Void
    let onSignIn: () -> Void
    let onStartDailyTask: (DailyTask) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                stats
                dailyPath
            }
            .padding(22)
        }
        .background {
            ZStack {
                ArcadeTheme.background
                RadialGradient(colors: [ArcadeTheme.pink.opacity(0.14), .clear], center: .topTrailing, startRadius: 20, endRadius: 430)
            }.ignoresSafeArea()
        }
        .navigationTitle("Home")
        .onAppear { model.reload() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Practice history", systemImage: "calendar", action: onHistory)
                    Button("Fret Finder", systemImage: "hand.point.up.left.fill", action: onFretFinder)
                    Button("Tune again", systemImage: "waveform", action: onRetune)
                    Button("Replay tutorial", systemImage: "arrow.counterclockwise", action: onReplay)
                    Button("Switch instrument", systemImage: "guitars", action: onSwitch)
                    if isGuest { Button("Sign in with Apple", systemImage: "person.crop.circle", action: onSignIn) }
                } label: {
                    Image(systemName: "person.crop.circle.fill").font(.title2)
                }
            }
        }
    }

    private var hero: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle().fill(ArcadeTheme.cyan.opacity(0.14))
                Image(systemName: "music.note").font(.system(size: 36, weight: .black)).foregroundStyle(ArcadeTheme.cyan)
            }
            .frame(width: 78, height: 78)
            VStack(alignment: .leading, spacing: 4) {
                Text("READY TO PLAY?").font(.caption.monospaced().weight(.black)).tracking(2).foregroundStyle(ArcadeTheme.yellow)
                Text("Keep your rhythm alive.").font(.title2.weight(.black))
                Text("Your next ukulele step is ready.").font(.subheadline).foregroundStyle(ArcadeTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 24))
    }

    private var stats: some View {
        HStack(spacing: 10) {
            stat(symbol: "flame.fill", value: "\(model.snapshot.profile.currentStreak)", label: "DAY STREAK", color: .orange)
            stat(symbol: "checkmark.circle.fill", value: "\(model.snapshot.dailyPlan.completedTaskIDs.count)/\(model.snapshot.dailyPlan.tasks.count)", label: "DAILY TASKS", color: ArcadeTheme.green)
            stat(symbol: "snowflake", value: "\(model.snapshot.profile.streakFreezes)", label: "STREAK FREEZE", color: ArcadeTheme.cyan)
        }
    }

    private func stat(symbol: String, value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(value).font(.title3.monospaced().weight(.black))
            Text(label).font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(ArcadeTheme.muted).lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 94, alignment: .leading)
        .padding(14)
        .background(ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 18))
    }

    private var dailyPath: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("TODAY'S PATH").font(.caption.monospaced().weight(.black)).tracking(2).foregroundStyle(ArcadeTheme.yellow)
                    Text("Daily guidance").font(.title2.weight(.black))
                }
                Spacer()
                Text("\(model.snapshot.dailyPlan.completedTaskIDs.count)/\(model.snapshot.dailyPlan.tasks.count)").font(.headline.monospaced().weight(.black)).foregroundStyle(ArcadeTheme.cyan)
            }
            ProgressView(value: Double(model.snapshot.dailyPlan.completedTaskIDs.count), total: Double(model.snapshot.dailyPlan.tasks.count))
                .tint(ArcadeTheme.green)

            ForEach(Array(model.snapshot.dailyPlan.tasks.enumerated()), id: \.element.id) { index, task in
                let completed = model.snapshot.dailyPlan.completedTaskIDs.contains(task.id)
                Button {
                    if !completed { onStartDailyTask(task) }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(completed ? ArcadeTheme.green : (index == model.snapshot.dailyPlan.completedTaskIDs.count ? ArcadeTheme.cyan : ArcadeTheme.panel))
                            Image(systemName: completed ? "checkmark" : symbol(for: task.kind))
                                .font(.headline.weight(.black))
                                .foregroundStyle(completed || index == model.snapshot.dailyPlan.completedTaskIDs.count ? ArcadeTheme.background : ArcadeTheme.muted)
                        }
                        .frame(width: 46, height: 46)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title).font(.headline.weight(.black))
                            Text(task.detail).font(.caption).foregroundStyle(ArcadeTheme.muted).lineLimit(2)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("+\(task.xp) XP").foregroundStyle(ArcadeTheme.yellow)
                            Text("+\(task.gems) ◆").foregroundStyle(ArcadeTheme.cyan)
                        }.font(.caption.monospaced().weight(.black))
                    }
                    .padding(16)
                    .background(ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(completed ? ArcadeTheme.green.opacity(0.6) : ArcadeTheme.cyan.opacity(index == model.snapshot.dailyPlan.completedTaskIDs.count ? 0.65 : 0.12)))
                }
                .buttonStyle(.plain)
                .disabled(completed)
            }

            if model.snapshot.dailyPlan.isComplete {
                Label("Daily chest claimed · +30 XP · +10 gems · streak protection", systemImage: "gift.fill")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(ArcadeTheme.green)
                    .frame(maxWidth: .infinity)
                    .padding(15)
                    .background(ArcadeTheme.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
            } else {
                Label("Complete all tasks: reward chest · +30 XP · +10 gems · streak freeze", systemImage: "gift.fill")
                    .font(.caption.monospaced().weight(.bold))
                    .foregroundStyle(ArcadeTheme.yellow)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(ArcadeTheme.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func symbol(for kind: DailyTaskKind) -> String {
        switch kind {
        case .chordLesson: "hand.raised.fingers.spread.fill"
        case .transition: "arrow.left.arrow.right"
        case .song: "music.note"
        case .review: "arrow.counterclockwise"
        }
    }

}
