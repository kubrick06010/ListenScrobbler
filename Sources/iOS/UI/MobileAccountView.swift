import ListenScrobblerCore
import SwiftUI

struct MobileAccountView: View {
    @EnvironmentObject private var listeningStore: MobileListeningStore
    @EnvironmentObject private var musicLibraryScanner: MusicLibraryScrobbleScanner
    let showOnboarding: () -> Void
    @State private var token = ""
    @State private var isPendingQueuePresented = false
    @State private var diagnosticsSnapshot: MobileDiagnosticsSnapshot?

    var body: some View {
        Form {
            Section {
                MobileListenBrainzSetupGuide(
                    connectionState: listeningStore.connectionState,
                    showOnboarding: showOnboarding
                )
            }

            Section("ListenBrainz") {
                Text(listeningStore.connectionState.statusText)
                    .foregroundStyle(.secondary)

                SecureField("User token", text: $token)
                    .textContentType(.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button {
                    Task {
                        await listeningStore.connect(token: token)
                        token = ""
                    }
                } label: {
                    Label("Connect", systemImage: "person.badge.key")
                }
                .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if listeningStore.hasStoredToken {
                    Button(role: .destructive) {
                        listeningStore.disconnect()
                    } label: {
                        Label("Disconnect", systemImage: "xmark.circle")
                    }
                }
            }

            Section("Music Library Scrobbling") {
                HStack(spacing: 12) {
                    Image("LibraryScan")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 34)
                        .accessibilityHidden(true)

                    Text(musicLibraryScanner.authorizationState.statusText)
                        .foregroundStyle(.secondary)
                }

                if let summary = musicLibraryScanner.lastSummary {
                    Text(summary.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    LabeledContent("Detected", value: "\(summary.detected)")
                    LabeledContent("Submitted", value: "\(summary.submitted + summary.retrySubmitted)")
                    LabeledContent("Failed", value: "\(summary.failed)")
                }

                if let lastScanAt = musicLibraryScanner.lastScanAt {
                    LabeledContent("Last Scan", value: lastScanAt.formatted(date: .abbreviated, time: .shortened))
                }

                LabeledContent("Pending Retry", value: "\(musicLibraryScanner.pendingRetryCount)")

                if musicLibraryScanner.pendingRetryCount > 0 {
                    Button {
                        musicLibraryScanner.refreshPendingScrobbles()
                        isPendingQueuePresented = true
                    } label: {
                        Label("Pending Queue", systemImage: "tray.full")
                    }
                }

                if let error = musicLibraryScanner.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    Task {
                        await musicLibraryScanner.scan(using: listeningStore)
                    }
                } label: {
                    if musicLibraryScanner.isScanning {
                        Label("Scanning", systemImage: "hourglass")
                    } else {
                        Label("Scan Music Library", systemImage: "music.note.list")
                    }
                }
                .disabled(musicLibraryScanner.isScanning || !listeningStore.hasStoredToken)

                Button(role: .destructive) {
                    musicLibraryScanner.resetBaseline()
                } label: {
                    Label("Reset Scan Baseline", systemImage: "arrow.counterclockwise")
                }
            }

            Section("Mobile Scope") {
                Text("Music library scanning compares local play counts with a saved baseline. The first scan does not submit old history; later scans submit detected new plays to ListenBrainz. Failed submissions stay pending for the next scan.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Beta Diagnostics") {
                LabeledContent("ListenBrainz", value: listeningStore.connectionState.statusText)
                LabeledContent("Music Access", value: musicLibraryScanner.authorizationState.statusText)
                LabeledContent("Pending Retry", value: "\(musicLibraryScanner.pendingRetryCount)")

                Button {
                    musicLibraryScanner.refreshPendingScrobbles()
                    diagnosticsSnapshot = MobileDiagnosticsSnapshot.make(
                        listeningStore: listeningStore,
                        musicLibraryScanner: musicLibraryScanner
                    )
                } label: {
                    Label("Export Diagnostics", systemImage: "doc.text.magnifyingglass")
                }
            }

            Section("Open Music Data") {
                Text("ListenScrobbler submits listens to ListenBrainz and uses official ListenBrainz logo assets from the MetaBrainz Design System.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Link(destination: URL(string: "https://listenbrainz.org/")!) {
                    Label("ListenBrainz", systemImage: "link")
                }
            }
        }
        .navigationTitle("Account")
        .sheet(isPresented: $isPendingQueuePresented) {
            MobilePendingQueueView()
                .environmentObject(musicLibraryScanner)
        }
        .sheet(item: $diagnosticsSnapshot) { snapshot in
            MobileDiagnosticsView(snapshot: snapshot)
        }
    }
}

private struct MobilePendingQueueView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var musicLibraryScanner: MusicLibraryScrobbleScanner

    var body: some View {
        NavigationStack {
            List {
                ForEach(musicLibraryScanner.pendingScrobbles) { item in
                    MobilePendingScrobbleRow(item: item)
                }
            }
            .navigationTitle("Pending Queue")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if !musicLibraryScanner.pendingScrobbles.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Clear", role: .destructive) {
                            musicLibraryScanner.clearPendingRetries()
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                musicLibraryScanner.refreshPendingScrobbles()
            }
        }
    }
}

private struct MobileListenBrainzSetupGuide: View {
    let connectionState: MobileListeningStore.ConnectionState
    let showOnboarding: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image("ListenPulse")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Guided Setup")
                        .font(.headline)
                    Label(statusText, systemImage: statusSymbol)
                        .font(.subheadline)
                        .foregroundStyle(statusTint)
                }
            }

            ForEach(ListenBrainzSetupGuide.steps) { step in
                MobileSetupStepRow(step: step)
            }

            VStack(alignment: .leading, spacing: 8) {
                Button {
                    showOnboarding()
                } label: {
                    Label("Open Onboarding", systemImage: "sparkles")
                }

                Link(destination: ListenBrainzSetupGuide.musicBrainzSignupURL) {
                    Label("Create Account", systemImage: "person.crop.circle.badge.plus")
                }

                Link(destination: ListenBrainzSetupGuide.tokenURL) {
                    Label("Open User Token", systemImage: "key")
                }

                Link(destination: ListenBrainzSetupGuide.addDataURL) {
                    Label("Add Existing Data", systemImage: "arrow.down.doc")
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }

    private var statusText: String {
        connectionState.statusText
    }

    private var statusSymbol: String {
        switch connectionState {
        case .connected:
            return "checkmark.seal"
        case .failed:
            return "exclamationmark.triangle"
        case .loading:
            return "hourglass"
        case .disconnected:
            return "person.badge.key"
        }
    }

    private var statusTint: Color {
        switch connectionState {
        case .connected:
            return .green
        case .failed:
            return .red
        default:
            return .secondary
        }
    }
}

struct MobileOpenMusicOnboardingView: View {
    let complete: () -> Void
    @Environment(\.openURL) private var openURL
    @State private var selectedPage = 0

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedPage) {
                introPage
                    .tag(0)

                featuresPage
                    .tag(1)

                setupPage
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .background(onboardingBackground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                onboardingFooter
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        complete()
                    }
                }
            }
        }
    }

    private var introPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                OpenMusicOnboardingBadge()

                VStack(alignment: .leading, spacing: 12) {
                    Text(ListenBrainzSetupGuide.headline)
                        .font(.largeTitle.weight(.bold))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(ListenBrainzSetupGuide.summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    ForEach(["Scrobble", "Discover", "Export"], id: \.self) { label in
                        Text(label)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.thinMaterial, in: Capsule())
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var featuresPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("What carries forward")
                    .font(.title.bold())

                ForEach(ListenBrainzSetupGuide.onboardingFeatures) { feature in
                    OnboardingFeatureRow(feature: feature)
                }
            }
            .padding(20)
        }
    }

    private var setupPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Setup checklist")
                    .font(.title.bold())

                ForEach(Array(ListenBrainzSetupGuide.steps.enumerated()), id: \.element.id) { offset, step in
                    MobileSetupStepRow(step: step, index: offset + 1)
                        .padding(14)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                VStack(spacing: 10) {
                    ForEach(ListenBrainzSetupGuide.onboardingActions) { action in
                        Button {
                            openURL(action.url)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: action.symbolName)
                                    .frame(width: 24, height: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(action.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(action.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 8)
            }
            .padding(20)
        }
    }

    private var onboardingFooter: some View {
        HStack(spacing: 12) {
            Button {
                complete()
            } label: {
                Label("Skip", systemImage: "xmark")
            }
            .buttonStyle(.bordered)

            Button {
                if selectedPage < 2 {
                    withAnimation(.snappy) {
                        selectedPage += 1
                    }
                } else {
                    complete()
                }
            } label: {
                Label(selectedPage < 2 ? "Continue" : "Start Scrobbling", systemImage: selectedPage < 2 ? "arrow.right" : "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .background(.bar)
    }

    private var onboardingBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.58, green: 0.02, blue: 0.04).opacity(0.24),
                Color(.systemBackground),
                Color(red: 0.08, green: 0.11, blue: 0.16).opacity(0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct OpenMusicOnboardingBadge: View {
    var body: some View {
        HStack(spacing: 10) {
            Image("ListenPulse")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(ListenBrainzSetupGuide.eyebrow)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(red: 0.83, green: 0.06, blue: 0.09))
                Text("ListenScrobbler")
                    .font(.headline)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct OnboardingFeatureRow: View {
    let feature: ListenBrainzOnboardingFeature

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: feature.symbolName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Color(red: 0.83, green: 0.06, blue: 0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.headline)
                Text(feature.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct MobileSetupStepRow: View {
    let step: ListenBrainzSetupStep
    var index: Int?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: step.symbolName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 0.83, green: 0.06, blue: 0.09))
                    .frame(width: 26, height: 26)

                if let index {
                    Text("\(index)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(Color(red: 0.83, green: 0.06, blue: 0.09), in: Circle())
                        .offset(x: 5, y: 5)
                }
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(step.title)
                    .font(.subheadline.weight(.semibold))
                Text(step.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let actionTitle = step.actionTitle, let actionURL = step.actionURL {
                    Link(destination: actionURL) {
                        Label(actionTitle, systemImage: "arrow.up.right")
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
                }
            }
        }
    }
}

private struct MobilePendingScrobbleRow: View {
    let item: MobilePendingScrobble

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.candidate.title)
                    .font(.headline)
                Text(item.candidate.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let album = item.candidate.album, !album.isEmpty {
                Label(album, systemImage: "opticaldisc")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text("Attempts")
                        .foregroundStyle(.secondary)
                    Text("\(item.attempts)")
                }
                GridRow {
                    Text("Listened")
                        .foregroundStyle(.secondary)
                    Text(item.candidate.listenedAt.formatted(date: .abbreviated, time: .shortened))
                }
                GridRow {
                    Text("Updated")
                        .foregroundStyle(.secondary)
                    Text(item.updatedAt.formatted(date: .abbreviated, time: .shortened))
                }
            }
            .font(.caption)

            if let lastError = item.lastError, !lastError.isEmpty {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}
