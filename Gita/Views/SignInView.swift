import AuthenticationServices
import SwiftUI

struct SignInView: View {
    let errorMessage: String?
    let onCompletion: (Result<ASAuthorization, Error>) -> Void
    let onGuest: () -> Void
    let onBack: () -> Void

    var body: some View {
        StageShell(step: "02 / Account", title: "Save your progress.", subtitle: "Sign in securely with Apple, then your practice setup stays linked to this account on this device.") {
            Button("Back to welcome", action: onBack)
                .foregroundStyle(ArcadeTheme.muted)
            Text("No Gita cloud account or song upload is created in this version.")
                .font(.footnote)
                .foregroundStyle(ArcadeTheme.muted)
        } trailing: {
            StagePanel {
                VStack(alignment: .leading, spacing: 20) {
                    Text("PLAYER ONE")
                        .font(.caption.monospaced().weight(.black))
                        .foregroundStyle(ArcadeTheme.yellow)
                    Text("Ready when you are.")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    SignInWithAppleButton(.signIn, onRequest: { request in
                        request.requestedScopes = []
                    }, onCompletion: onCompletion)
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 56)
                    .accessibilityLabel("Sign in with Apple")
                    StageButton(title: "Continue as guest", symbol: "arrow.right", secondary: true, action: onGuest)
                    Text("Guest progress stays only on this device. You can sign in later, but it won't automatically merge with your Apple progress.")
                        .font(.footnote)
                        .foregroundStyle(ArcadeTheme.muted)
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(ArcadeTheme.yellow)
                    }
                }
            }
        }
    }
}
