import SwiftUI

struct ContentView: View {
    @StateObject private var account = AppleSession()
    @StateObject private var microphone = Microphone()
    @State private var progress = SetupProgress()
    @State private var route: SetupRoute = .welcome
    @State private var started = false
    @State private var guestMode = false
    @State private var returningFromReadyRetune = false

    private let store = ProgressStore()

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
                }
            case .signedOut, .error:
                if guestMode {
                    progress = store.loadGuest()
                }
                route = SetupPolicy.route(guestMode: guestMode, userID: nil, progress: progress, started: started)
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
                ReadyView(instrument: instrument, isGuest: guestMode) {
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
                } onSignIn: {
                    store.setGuestModeEnabled(false)
                    guestMode = false
                    started = true
                    route = .signIn
                }
            }
        }
    }

    private var errorMessage: String? {
        if case .error(let message) = account.status { return message }
        return nil
    }

    private func saveProgress() {
        if guestMode {
            store.saveGuest(progress)
        } else if let id = account.userID {
            store.save(progress, for: id)
        }
    }
}

#Preview {
    ContentView()
}
