import ListenScrobblerCore
import SwiftUI

struct MobileMusicDetailView: View {
    @EnvironmentObject private var listeningStore: MobileListeningStore
    let seed: MobileMusicDetailSeed
    @State private var detail: MobileMusicDetail?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var biography: MobileArtistBiography?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                actionStrip

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let detail {
                    metadataSection(detail)
                    if !detail.tags.isEmpty {
                        tagSection(detail.tags)
                    }
                    if !detail.links.isEmpty {
                        linksSection(detail.links)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(seed.kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await load()
        }
        .task(id: seed.id) {
            await load()
        }
        .sheet(item: $biography) { item in
            MobileArtistBiographyView(item: item)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            artwork(seed.imageURL ?? detail?.imageURL ?? detail?.artistImageURL, size: 92)

            VStack(alignment: .leading, spacing: 6) {
                Label(seed.kind.title, systemImage: seed.kind.symbolName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(detail?.trackName ?? detail?.releaseName ?? seed.displayTitle)
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)

                Text(detail?.artistName ?? seed.artistName)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                if let release = detail?.releaseName ?? seed.releaseName {
                    Text(release)
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var actionStrip: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                actionButtons
            }

            VStack(alignment: .leading, spacing: 10) {
                actionButtons
            }
        }
        .buttonStyle(.bordered)
        .disabled(listeningStore.isUpdatingListenAction)
    }

    private var actionButtons: some View {
        Group {
            Button {
                Task { _ = await listeningStore.love(resolvedSeed) }
            } label: {
                Label("Love", systemImage: "heart.fill")
            }
            .disabled(!canSendFeedback)

            Button {
                Task { _ = await listeningStore.unlove(resolvedSeed) }
            } label: {
                Label("Unlove", systemImage: "heart.slash")
            }
            .disabled(!canSendFeedback)

            Button {
                Task {
                    if listeningStore.isCurrentPin(resolvedSeed) {
                        _ = await listeningStore.unpinCurrent()
                    } else {
                        _ = await listeningStore.pin(resolvedSeed)
                    }
                }
            } label: {
                Label(
                    listeningStore.isCurrentPin(resolvedSeed) ? "Unpin" : "Pin",
                    systemImage: listeningStore.isCurrentPin(resolvedSeed) ? "pin.slash" : "pin"
                )
            }
            .disabled(!canPin)

            if let item = biographyItem {
                Button {
                    biography = item
                } label: {
                    Label("Biography", systemImage: "book")
                }
            }
        }
    }

    private func metadataSection(_ detail: MobileMusicDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Open Metadata")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 142), alignment: .leading)], alignment: .leading, spacing: 10) {
                MobileMetadataChip(title: "Recording MBID", value: detail.recordingMBID)
                MobileMetadataChip(title: "Recording MSID", value: detail.recordingMSID)
                MobileMetadataChip(title: "Artist MBID", value: detail.artistMBID)
                MobileMetadataChip(title: "Release MBID", value: detail.releaseMBID)
                MobileMetadataChip(title: "Country", value: detail.country)
                MobileMetadataChip(title: "Type", value: detail.type)
            }

            if let disambiguation = detail.disambiguation {
                Text(disambiguation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func tagSection(_ tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tags")
                .font(.headline)

            MobileFlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: Capsule())
                }
            }
        }
    }

    private func linksSection(_ links: [MobileOpenMusicLink]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Links")
                .font(.headline)

            ForEach(links) { link in
                Link(destination: link.url) {
                    Label(link.title, systemImage: "link")
                }
            }
        }
    }

    @ViewBuilder
    private func artwork(_ urlString: String?, size: CGFloat) -> some View {
        if let urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image.resizable().scaledToFill()
                case .failure:
                    fallbackArtwork
                case .empty:
                    fallbackArtwork
                @unknown default:
                    fallbackArtwork
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            fallbackArtwork
                .frame(width: size, height: size)
        }
    }

    private var fallbackArtwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.thinMaterial)
            Image(systemName: seed.kind.symbolName)
                .foregroundStyle(.secondary)
        }
    }

    private var resolvedSeed: MobileMusicDetailSeed {
        guard let detail else { return seed }
        return MobileMusicDetailSeed(
            kind: seed.kind,
            trackName: detail.trackName,
            artistName: detail.artistName,
            releaseName: detail.releaseName,
            recordingMBID: detail.recordingMBID,
            recordingMSID: detail.recordingMSID,
            artistMBID: detail.artistMBID,
            releaseMBID: detail.releaseMBID,
            imageURL: detail.imageURL ?? detail.artistImageURL
        )
    }

    private var canSendFeedback: Bool {
        listeningStore.hasStoredToken &&
            (resolvedSeed.recordingMBID != nil || resolvedSeed.recordingMSID != nil)
    }

    private var canPin: Bool {
        canSendFeedback
    }

    private var biographyItem: MobileArtistBiography? {
        guard let detail,
              let summary = detail.artistSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
              !summary.isEmpty else {
            return nil
        }
        return MobileArtistBiography(
            artistName: detail.artistName,
            summary: summary,
            imageURL: detail.artistImageURL,
            sourceURL: detail.artistSummaryURL,
            languageCode: detail.artistSummaryLanguageCode
        )
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            detail = try await listeningStore.loadDetail(for: seed)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct MobileMetadataChip: View {
    let title: String
    let value: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(LocalizedStringKey(title))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? value! : "-")
                .font(.caption2.monospaced())
                .textSelection(.enabled)
                .lineLimit(2)
        }
    }
}

private struct MobileFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: maxWidth, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

private struct MobileArtistBiography: Identifiable {
    let artistName: String
    let summary: String
    let imageURL: String?
    let sourceURL: URL?
    let languageCode: String?

    var id: String {
        [artistName, languageCode ?? "unknown"].joined(separator: "|")
    }
}

private struct MobileArtistBiographyView: View {
    @Environment(\.dismiss) private var dismiss
    let item: MobileArtistBiography

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    biographyArtwork

                    Text(item.artistName)
                        .font(.title.bold())
                        .fixedSize(horizontal: false, vertical: true)

                    Text(item.summary)
                        .font(.body)
                        .lineSpacing(3)
                        .textSelection(.enabled)

                    if let sourceURL = item.sourceURL {
                        Link(destination: sourceURL) {
                            Label("Wikipedia", systemImage: "arrow.up.right.square")
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Biography")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var biographyArtwork: some View {
        if let imageURL = item.imageURL, let url = URL(string: imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image.resizable().scaledToFill()
                default:
                    Rectangle().fill(.thinMaterial)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}
