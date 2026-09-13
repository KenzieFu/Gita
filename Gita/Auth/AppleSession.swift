import AuthenticationServices
import Combine
import Security
import SwiftUI

enum AppleSessionStatus: Equatable {
    case checking
    case signedOut
    case signedIn
    case error(String)
}

@MainActor
final class AppleSession: ObservableObject {
    @Published private(set) var userID: String?
    @Published private(set) var status: AppleSessionStatus = .checking

    private let service = "com.gita.apple-account"
    private let account = "apple-user-id"

    init() {
        userID = readUserID()
    }

    func refreshCredentialState() {
        guard let storedID = readUserID() else {
            userID = nil
            status = .signedOut
            return
        }
        status = .checking
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: storedID) { [weak self] state, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if state == .authorized {
                    self.userID = storedID
                    self.status = .signedIn
                } else {
                    self.userID = nil
                    self.deleteUserID()
                    self.status = .signedOut
                }
            }
        }
    }

    func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                status = .error("Apple did not return an account. Please try again.")
                return
            }
            guard saveUserID(credential.user) else {
                status = .error("Could not save this account securely. Please try again.")
                return
            }
            userID = credential.user
            status = .signedIn
        case .failure(let error):
            let nsError = error as NSError
            if nsError.domain == ASAuthorizationError.errorDomain,
               nsError.code == ASAuthorizationError.canceled.rawValue {
                status = .signedOut
            } else {
                status = .error("Sign in could not finish. Check your Apple account and try again.")
            }
        }
    }

    private func readUserID() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func saveUserID(_ id: String) -> Bool {
        deleteUserID()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(id.utf8)
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    private func deleteUserID() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
