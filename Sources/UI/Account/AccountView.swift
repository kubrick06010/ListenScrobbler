import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

struct AccountView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @Binding var username: String
    @Binding var password: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Account And Session")
                    .font(.custom("Avenir Next Demi Bold", size: 28))

                VStack(alignment: .leading, spacing: 12) {
                    TextField("Username", text: $username)
                    SecureField("Password", text: $password)

                    HStack {
                        Button("Sign In") {
                            Task { await scrobbleService.signIn(username: username, password: password) }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Sign Out") {
                            scrobbleService.signOut()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .appPanelStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Backend: \(scrobbleService.backendName)")
                    Text("Auth State: \(scrobbleService.isAuthenticated ? "Authenticated" : "Not authenticated")")
                    Text("Session: \(scrobbleService.sessionStatus)")
                    Text("Capabilities: \(scrobbleService.capabilitiesStatus)")
                    Text("Operational state: Preferences > Advanced")
                        .foregroundStyle(.secondary)
                }
                .font(.custom("Avenir Next Medium", size: 13))
                .appPanelStyle()

                if let authError = scrobbleService.authError {
                    Text(authError)
                        .font(.custom("Avenir Next Medium", size: 13))
                        .foregroundStyle(.red)
                        .padding(10)
                        .appPanelStyle()
                }
            }
            .padding(24)
            .frame(maxWidth: 1280, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}
