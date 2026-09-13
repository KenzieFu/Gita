import SwiftUI

struct ContentView: View {
    @StateObject private var account = AppleSession()
    @StateObject private var microphone = Microphone()
    @State private var progress = SetupProgress()
    @State private var route: SetupRoute = .welcome
    @State private var started = false
    @State private var returningFromReadyRetune = false

    private let store = ProgressStore()

    var body: some View {
        Group {
            if account.status == .checking {
                StageShell(step: "Loading", title: "Finding your beat…", subtitle: "Checking your Apple account on this device.") {
                    ProgressView().tint(ArcadeTheme.cyan)
                } trailing: {
                    NeonNote(symbol: "waveform.path", label: "GITA")
                }
            } else {
                stage
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { account.refreshCredentialState() }
        .onChange(of: account.status) { _, status in
            switch status {
            case .signedIn:
                if let id = account.userID {
                    progress = store.load(for: id)
                    route = SetupPolicy.route(userID: id, progress: progress, started: started)
                }
            case .signedOut, .error:
                route = SetupPolicy.route(userID: nil, progress: progress, started: started)
            case .checking:
                break
            }
        }
        .onChange(of: route) { oldRoute, newRoute in
            if oldRoute.usesMicrophone { microphone.stop() }
            if newRoute.usesMicrophone { Task { await microphone.start() } }
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
                TunerView(instrument: instrument, microphone: microphone, completed: progress.completedTuning) { tuned in
                    progress.completedTuning = tuned
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
                TutorialView(instrument: instrument, microphone: microphone, initialStep: progress.lessonStep) { nextStep in
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
                ReadyView(instrument: instrument) {
                    progress.completedTuning = []
                    saveProgress()
                    returningFromReadyRetune = true
                    route = .tuning
                } onReplay: {
                    progress.tutorialComplete = false
                    progress.lessonStep = 0
                    saveProgress()
                    route = .tutorial
                } onSwitch: {
                    route = .instrumentChoice
                }
            }
        }
    }

    private var errorMessage: String? {
        if case .error(let message) = account.status { return message }
        return nil
    }

    private func saveProgress() {
        guard let id = account.userID else { return }
        store.save(progress, for: id)
    }
}

#Preview {
    ContentView()
}
