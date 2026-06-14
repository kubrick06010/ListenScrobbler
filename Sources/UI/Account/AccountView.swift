import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

struct AccountView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @Binding var username: String
    @Binding var password: String
    @State private var isLastFMModernOnboardingPresented = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Account And Session")
                    .font(.custom("Avenir Next Demi Bold", size: 28))

                ListenBrainzAccountSetupPanel(
                    connectionSummary: scrobbleService.listenBrainzStatus,
                    connectedUsername: scrobbleService.listenBrainzUsername,
                    hasError: scrobbleService.listenBrainzLastError != nil,
                    showOnboarding: {
                        isLastFMModernOnboardingPresented = true
                    }
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("Compatibility Session")
                        .font(.custom("Avenir Next Demi Bold", size: 16))

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
        .sheet(isPresented: $isLastFMModernOnboardingPresented) {
            MacLastFMModernOnboardingView {
                isLastFMModernOnboardingPresented = false
            }
            .frame(width: 760, height: 620)
        }
    }
}

struct ListenBrainzAccountSetupPanel: View {
    let connectionSummary: String
    let connectedUsername: String?
    let hasError: Bool
    var showOnboarding: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image("ListenPulse")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 38, height: 38)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("ListenBrainz Setup")
                        .font(.custom("Avenir Next Demi Bold", size: 18))
                    Text("A guided setup path for the open music identity OpenScrobbler uses across submissions, charts, and diagnostics.")
                        .font(.custom("Avenir Next Regular", size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Label(statusLabel, systemImage: statusSymbol)
                    .font(.custom("Avenir Next Demi Bold", size: 12))
                    .foregroundStyle(hasError ? .red : .secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 12)], alignment: .leading, spacing: 12) {
                ForEach(ListenBrainzSetupGuide.steps) { step in
                    ListenBrainzSetupStepTile(step: step)
                }
            }

            HStack(spacing: 10) {
                if let showOnboarding {
                    Button {
                        showOnboarding()
                    } label: {
                        Label("Last.fm Modern", systemImage: "sparkles")
                    }
                }

                Link(destination: ListenBrainzSetupGuide.musicBrainzSignupURL) {
                    Label("Create Account", systemImage: "person.crop.circle.badge.plus")
                }

                Link(destination: ListenBrainzSetupGuide.tokenURL) {
                    Label("Open Token", systemImage: "key")
                }

                Link(destination: ListenBrainzSetupGuide.importersURL) {
                    Label("Music Services", systemImage: "point.3.connected.trianglepath.dotted")
                }
            }
            .buttonStyle(.bordered)
            .font(.custom("Avenir Next Medium", size: 12))
        }
        .appPanelStyle()
    }

    private var statusLabel: String {
        if let connectedUsername, !connectedUsername.isEmpty {
            return connectedUsername
        }
        return connectionSummary
    }

    private var statusSymbol: String {
        if hasError {
            return "exclamationmark.triangle"
        }
        if connectedUsername != nil {
            return "checkmark.seal"
        }
        return "person.badge.key"
    }
}

struct MacLastFMModernOnboardingView: View {
    let complete: () -> Void
    @Environment(\.openURL) private var openURL

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                        ForEach(ListenBrainzSetupGuide.onboardingFeatures) { feature in
                            MacOnboardingFeatureTile(feature: feature)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Connect in minutes")
                            .font(.custom("Avenir Next Demi Bold", size: 18))

                        ForEach(ListenBrainzSetupGuide.steps) { step in
                            ListenBrainzSetupStepTile(step: step)
                        }
                    }
                    .appPanelStyle()

                    HStack(spacing: 10) {
                        ForEach(ListenBrainzSetupGuide.onboardingActions) { action in
                            Button {
                                openURL(action.url)
                            } label: {
                                Label(action.title, systemImage: action.symbolName)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .font(.custom("Avenir Next Medium", size: 12))
                }
                .padding(24)
            }

            Divider()

            HStack {
                Text("You can reopen this anytime from ListenBrainz settings.")
                    .font(.custom("Avenir Next Regular", size: 12))
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Done") {
                    complete()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image("ListenPulse")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(ListenBrainzSetupGuide.eyebrow)
                        .font(.custom("Avenir Next Demi Bold", size: 12))
                        .foregroundStyle(Color(red: 0.83, green: 0.06, blue: 0.09))
                    Text("OpenScrobbler")
                        .font(.custom("Avenir Next Demi Bold", size: 20))
                }
            }

            Text(ListenBrainzSetupGuide.headline)
                .font(.custom("Avenir Next Demi Bold", size: 34))
                .fixedSize(horizontal: false, vertical: true)

            Text(ListenBrainzSetupGuide.summary)
                .font(.custom("Avenir Next Regular", size: 14))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .appPanelStyle()
    }
}

private struct MacOnboardingFeatureTile: View {
    let feature: ListenBrainzOnboardingFeature

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: feature.symbolName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color(red: 0.83, green: 0.06, blue: 0.09), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(feature.title)
                .font(.custom("Avenir Next Demi Bold", size: 14))

            Text(feature.detail)
                .font(.custom("Avenir Next Regular", size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .appPanelStyle()
    }
}

struct ListenBrainzSetupStepTile: View {
    let step: ListenBrainzSetupStep

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: step.symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(red: 0.83, green: 0.06, blue: 0.09))
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(step.title)
                    .font(.custom("Avenir Next Demi Bold", size: 13))
                Text(step.detail)
                    .font(.custom("Avenir Next Regular", size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
