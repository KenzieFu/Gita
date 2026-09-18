import AVFoundation
import SwiftUI

struct ChallengeHistoryView: View {
    let days: [ChallengeDay]
    let store: ChallengeDayStore
    let onClose: () -> Void

    @State private var audioPlayer: AVAudioPlayer?
    @State private var playbackMessage: String?

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Button(action: onClose) { Label("Back", systemImage: "chevron.left") }
                        .foregroundStyle(ArcadeTheme.cyan)
                    Text("YOUR PRACTICE DAYS")
                        .font(.caption.monospaced().weight(.black))
                        .tracking(3)
                        .foregroundStyle(ArcadeTheme.yellow)
                    Text("Every session counts.")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                    Text("Day numbers count distinct practice dates. Missing a day never resets your progress.")
                        .foregroundStyle(ArcadeTheme.muted)

                    if days.isEmpty {
                        Text("No recorded days yet. Choose a part and play with wired headphones to save your first take.")
                            .foregroundStyle(ArcadeTheme.muted)
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 16))
                    }
                    ForEach(days.sorted { $0.ordinal > $1.ordinal }) { day in
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Day \(day.ordinal) · \(day.localDate)")
                                .font(.title3.weight(.black))
                                .foregroundStyle(ArcadeTheme.yellow)
                            ForEach(day.recordings) { recording in
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("\(recording.chartID) · \(recording.sectionID)")
                                            .font(.subheadline.weight(.bold))
                                        Text("\(Int(recording.take.speed * 100))% speed · \(recording.take.hitCount)/\(recording.take.noteCount) notes heard · provisional")
                                            .font(.caption)
                                            .foregroundStyle(ArcadeTheme.muted)
                                    }
                                    Spacer()
                                    Button {
                                        play(recording)
                                    } label: {
                                        Label("Listen", systemImage: "play.fill")
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(ArcadeTheme.cyan)
                                }
                                .padding(10)
                                .background(ArcadeTheme.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 16))
                    }
                    if let playbackMessage {
                        Text(playbackMessage).foregroundStyle(ArcadeTheme.pink)
                    }
                }
                .padding(24)
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
            .background(ArcadeTheme.background.ignoresSafeArea())
        }
        .onDisappear { audioPlayer?.stop() }
        .preferredColorScheme(.dark)
    }

    private func play(_ recording: ChallengeRecording) {
        do {
            audioPlayer?.stop()
            let player = try AVAudioPlayer(contentsOf: store.recordingURL(for: recording))
            player.prepareToPlay()
            player.play()
            audioPlayer = player
            playbackMessage = nil
        } catch {
            playbackMessage = "This recording could not be played."
        }
    }
}
