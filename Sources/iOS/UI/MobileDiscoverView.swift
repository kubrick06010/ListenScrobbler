import ListenScrobblerCore
import SwiftUI
import WidgetKit

struct MobileDiscoverView: View {
    @EnvironmentObject private var listeningStore: MobileListeningStore

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image("DiscoveryRadio")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 54, height: 54)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Open Discovery")
                            .font(.headline)
                        Text(listeningStore.recommendationsStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(listeningStore.socialStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Recommendations") {
                if listeningStore.recommendedRecordings.isEmpty {
                    Label(listeningStore.recommendationsStatus, systemImage: "sparkles")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(listeningStore.recommendedRecordings) { recommendation in
                        NavigationLink {
                            MobileMusicDetailView(seed: recommendationSeed(recommendation))
                        } label: {
                            MobileRecommendationRow(recommendation: recommendation)
                        }
                    }
                }

                Button {
                    Task {
                        await listeningStore.refreshRecommendations()
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                } label: {
                    if listeningStore.isRefreshingRecommendations {
                        Label("Refreshing", systemImage: "hourglass")
                    } else {
                        Label("Refresh Recommendations", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(!canRefreshRecommendations)
            }

            Section("Social Feed") {
                if let snapshot = listeningStore.socialSnapshot {
                    MobileSocialSummaryView(snapshot: snapshot)

                    if snapshot.neighborListens.isEmpty {
                        Label(listeningStore.socialStatus, systemImage: "person.2")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.neighborListens.prefix(8)) { listen in
                            NavigationLink {
                                MobileMusicDetailView(seed: socialSeed(listen))
                            } label: {
                                MobileSocialListenRow(listen: listen)
                            }
                        }
                    }
                } else {
                    Label(listeningStore.socialStatus, systemImage: "person.2")
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task {
                        await listeningStore.refreshSocial()
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                } label: {
                    if listeningStore.isRefreshingSocial {
                        Label("Refreshing", systemImage: "hourglass")
                    } else {
                        Label("Refresh Social", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(!canRefreshSocial)
            }

            Section("Explore") {
                NavigationLink {
                    MobileDiscoverSearchView()
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }

                NavigationLink {
                    MobileDiscoverRadioView()
                } label: {
                    Label("Radio", systemImage: "dot.radiowaves.left.and.right")
                }
            }
        }
        .navigationTitle("Discover")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await refreshDiscovery()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(!canRefreshDiscovery)
                .accessibilityLabel("Refresh Discover")
            }
        }
        .refreshable {
            await refreshDiscovery()
        }
        .task {
            if listeningStore.recommendedRecordings.isEmpty {
                await listeningStore.refreshRecommendations()
            }
            if listeningStore.socialSnapshot == nil {
                await listeningStore.refreshSocial()
            }
        }
    }

    private var canRefreshRecommendations: Bool {
        guard case .connected = listeningStore.connectionState else { return false }
        return !listeningStore.isRefreshingRecommendations
    }

    private var canRefreshSocial: Bool {
        guard case .connected = listeningStore.connectionState else { return false }
        return !listeningStore.isRefreshingSocial
    }

    private var canRefreshDiscovery: Bool {
        canRefreshRecommendations && canRefreshSocial
    }

    private func refreshDiscovery() async {
        await listeningStore.refreshRecommendations()
        await listeningStore.refreshSocial()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func recommendationSeed(_ recommendation: MobileRecommendedRecording) -> MobileMusicDetailSeed {
        MobileMusicDetailSeed(
            kind: .track,
            trackName: recommendation.title,
            artistName: recommendation.artistName ?? String(localized: "Unknown artist"),
            releaseName: recommendation.releaseName,
            recordingMBID: recommendation.recordingMBID
        )
    }

    private func socialSeed(_ listen: MobileSocialListen) -> MobileMusicDetailSeed {
        MobileMusicDetailSeed(
            kind: .track,
            trackName: listen.trackName,
            artistName: listen.artistName,
            releaseName: listen.releaseName
        )
    }
}

private struct MobileDiscoverSearchView: View {
    @EnvironmentObject private var listeningStore: MobileListeningStore
    @State private var query = ""
    @State private var scope: MobileDiscoverySearchScope = .tracks

    var body: some View {
        List {
            Section {
                Picker("Scope", selection: $scope) {
                    ForEach(MobileDiscoverySearchScope.allCases) { scope in
                        Label(scope.title, systemImage: scope.symbolName)
                            .tag(scope)
                    }
                }
                .pickerStyle(.segmented)

                TextField("Search MusicBrainz", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await search() }
                    }

                Button {
                    Task { await search() }
                } label: {
                    if listeningStore.isSearching {
                        Label("Searching", systemImage: "hourglass")
                    } else {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                }
                .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || listeningStore.isSearching)
            }

            Section("Results") {
                if listeningStore.searchResults.isEmpty {
                    Label(listeningStore.searchStatus, systemImage: "magnifyingglass")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(listeningStore.searchResults) { result in
                        NavigationLink {
                            MobileMusicDetailView(seed: result.seed)
                        } label: {
                            MobileSearchResultRow(result: result)
                        }
                    }
                }
            }
        }
        .navigationTitle("Search")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await search() }
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || listeningStore.isSearching)
            }
        }
    }

    private func search() async {
        await listeningStore.searchDiscovery(query: query, scope: scope)
    }
}

private struct MobileSearchResultRow: View {
    let result: MobileDiscoverySearchResult

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: result.seed.kind.symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(red: 0.83, green: 0.06, blue: 0.09))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.headline)
                    .lineLimit(2)
                if let subtitle = result.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let detail = result.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct MobileDiscoverRadioView: View {
    @EnvironmentObject private var listeningStore: MobileListeningStore

    var body: some View {
        List {
            Section {
                Label(listeningStore.radioStatus, systemImage: "dot.radiowaves.left.and.right")
                    .foregroundStyle(.secondary)

                Button {
                    Task { await listeningStore.refreshRadio() }
                } label: {
                    if listeningStore.isRefreshingRadio {
                        Label("Loading Radio", systemImage: "hourglass")
                    } else {
                        Label("Recommendation Radio", systemImage: "sparkles")
                    }
                }
                .disabled(!canRefreshRadio)
            }

            Section("Artist Seeds") {
                if listeningStore.radioSeeds.isEmpty {
                    Label("Refresh stats or listens to seed artist radio", systemImage: "person.wave.2")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(listeningStore.radioSeeds.prefix(10)) { seed in
                        Button {
                            Task { await listeningStore.refreshRadio(seed: seed) }
                        } label: {
                            Label(seed.artistName, systemImage: seed.artistMBID == nil ? "person" : "person.wave.2")
                        }
                        .disabled(!canRefreshRadio)
                    }
                }
            }

            Section("Queue") {
                if listeningStore.radioQueue.isEmpty {
                    Label("No radio queue loaded", systemImage: "music.note.list")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(listeningStore.radioQueue) { item in
                        NavigationLink {
                            MobileMusicDetailView(seed: item.seed)
                        } label: {
                            MobileRadioQueueRow(item: item)
                        }
                    }
                }
            }

            if !listeningStore.radioArtists.isEmpty {
                Section("Related Artists") {
                    ForEach(listeningStore.radioArtists) { artist in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(artist.name)
                                .font(.headline)
                            Text(String.localizedStringWithFormat(String(localized: "%d listens in radio graph"), artist.totalListenCount))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Radio")
        .refreshable {
            await listeningStore.refreshRadio()
        }
        .task {
            if listeningStore.statsSnapshot == nil {
                await listeningStore.refreshStats()
            }
            if listeningStore.radioQueue.isEmpty {
                await listeningStore.refreshRadio()
            }
        }
    }

    private var canRefreshRadio: Bool {
        guard case .connected = listeningStore.connectionState else { return false }
        return !listeningStore.isRefreshingRadio
    }
}

private struct MobileRadioQueueRow: View {
    let item: MobileRadioQueueItem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(red: 0.83, green: 0.06, blue: 0.09))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)
                if let artist = item.artistName {
                    Text(artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let release = item.releaseName {
                    Text(release)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text(item.score, format: .number.precision(.fractionLength(2)))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct MobileRecommendationRow: View {
    let recommendation: MobileRecommendedRecording

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.title)
                    .font(.headline)
                    .lineLimit(2)

                if let artistName = recommendation.artistName, !artistName.isEmpty {
                    Text(artistName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let releaseName = recommendation.releaseName, !releaseName.isEmpty {
                    Text(releaseName)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 10)

            Image(systemName: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(red: 0.83, green: 0.06, blue: 0.09))
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
    }
}

private struct MobileSocialSummaryView: View {
    let snapshot: MobileSocialSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                MobileSocialMetric(title: "Followers", value: snapshot.followers.count)
                MobileSocialMetric(title: "Following", value: snapshot.following.count)
                MobileSocialMetric(title: "Similar", value: snapshot.similarUsers.count)
            }

            if !snapshot.similarUsers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(snapshot.similarUsers.prefix(8)) { user in
                            Label(user.userName, systemImage: "person.crop.circle")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.thinMaterial, in: Capsule())
                        }
                    }
                }
            }

            Text("Updated \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

private struct MobileSocialMetric: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value.formatted())
                .font(.headline.monospacedDigit())
            Text(LocalizedStringKey(title))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MobileSocialListenRow: View {
    let listen: MobileSocialListen

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "person.crop.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(red: 0.83, green: 0.06, blue: 0.09))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(listen.trackName)
                    .font(.headline)
                    .lineLimit(2)

                Text(listen.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(listen.userName)
                    if let listenedAt = listen.listenedAt {
                        Text(listenedAt.formatted(date: .omitted, time: .shortened))
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
