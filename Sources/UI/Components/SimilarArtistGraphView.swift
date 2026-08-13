import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

struct SimilarArtistGraphNode: Identifiable, Equatable {
    enum Kind: String, Equatable {
        case similarity
        case connection
        case alias

        var label: String {
            switch self {
            case .similarity: return AppLocalization.string("Similar")
            case .connection: return AppLocalization.string("Connected")
            case .alias: return AppLocalization.string("Alias")
            }
        }
    }

    let id: String
    let name: String
    let value: Double
    let artworkResolution: ArtworkResolution?
    let relationship: String?
    let kind: Kind

    /// Compatibility accessor for non-rendering consumers. It can never expose
    /// a credentialed or untyped legacy URL.
    var imageURL: String? { artworkResolution?.automaticArtworkResolution?.url }

    init(
        id: String,
        name: String,
        value: Double,
        artworkResolution: ArtworkResolution? = nil,
        relationship: String? = nil,
        kind: Kind = .similarity
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.artworkResolution = artworkResolution
        self.relationship = relationship
        self.kind = kind
    }
}

struct SimilarArtistGraphView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let centerName: String
    let centerArtworkResolution: ArtworkResolution?
    let nodes: [SimilarArtistGraphNode]
    let compact: Bool
    let onSelect: ((SimilarArtistGraphNode) -> Void)?

    @State private var selectedNodeID: String?
    @State private var hoveredNodeID: String?

    init(
        centerName: String,
        centerArtworkResolution: ArtworkResolution? = nil,
        nodes: [SimilarArtistGraphNode],
        compact: Bool,
        onSelect: ((SimilarArtistGraphNode) -> Void)? = nil
    ) {
        self.centerName = centerName
        self.centerArtworkResolution = centerArtworkResolution
        self.nodes = nodes
        self.compact = compact
        self.onSelect = onSelect
    }

    private var visibleNodes: [SimilarArtistGraphNode] {
        Array(nodes.prefix(compact ? 7 : 12))
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = graphLayout(in: proxy.size)
            ZStack {
                graphBackground

                ForEach(visibleNodes) { node in
                    if let point = layout.nodePositions[node.id] {
                        Path { path in
                            path.move(to: layout.center)
                            path.addLine(to: point)
                        }
                        .stroke(
                            edgeColor(for: node).opacity(selectedNodeID == node.id ? 0.92 : 0.42),
                            style: StrokeStyle(
                                lineWidth: selectedNodeID == node.id ? 2.4 : edgeWidth(for: node),
                                lineCap: .round,
                                dash: node.kind == .alias ? [4, 5] : []
                            )
                        )
                    }
                }

                centerNode(size: layout.centerSize)
                .position(layout.center)

                ForEach(visibleNodes) { node in
                    if let point = layout.nodePositions[node.id] {
                        relationshipNode(node, size: layout.nodeSizes[node.id] ?? 66)
                        .position(point)
                    }
                }

                legend
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(14)

                if let selectedNode {
                    selectionCaption(selectedNode)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 12)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: selectedNodeID)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Artist constellation for \(centerName)")
    }

    private var graphBackground: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(red: 0.08, green: 0.10, blue: 0.14).opacity(0.86), Color.black.opacity(0.18)]
                    : [Color.white.opacity(0.72), Color(red: 0.91, green: 0.94, blue: 0.98).opacity(0.74)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color.accentColor.opacity(colorScheme == .dark ? 0.16 : 0.10), .clear],
                center: .center,
                startRadius: 18,
                endRadius: compact ? 190 : 310
            )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.09), lineWidth: 1)
        }
    }

    private func centerNode(size: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            graphArtwork(
                artist: centerName,
                resolution: centerArtworkResolution,
                name: centerName,
                size: size,
                tint: .accentColor
            )
                .overlay {
                    Circle().stroke(Color.accentColor.opacity(0.88), lineWidth: 3)
                }
                .shadow(color: Color.accentColor.opacity(0.22), radius: 18)
            Text("Current artist")
                .font(.custom("Avenir Next Demi Bold", size: 9))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.regularMaterial, in: Capsule())
                .offset(y: 9)
        }
        .frame(width: size, height: size + 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current artist, \(centerName)")
    }

    private func relationshipNode(_ node: SimilarArtistGraphNode, size: CGFloat) -> some View {
        Button {
            selectedNodeID = node.id
            onSelect?(node)
        } label: {
            VStack(spacing: 5) {
                graphArtwork(
                    artist: node.name,
                    resolution: node.artworkResolution,
                    name: node.name,
                    size: size,
                    tint: nodeColor(node)
                )
                    .overlay {
                        Circle().stroke(
                            nodeColor(node).opacity(selectedNodeID == node.id || hoveredNodeID == node.id ? 1 : 0.72),
                            lineWidth: selectedNodeID == node.id ? 3 : 2
                        )
                    }
                    .shadow(
                        color: nodeColor(node).opacity(hoveredNodeID == node.id ? 0.34 : 0.14),
                        radius: hoveredNodeID == node.id ? 12 : 6
                    )
                Text(node.name)
                    .font(.custom("Avenir Next Demi Bold", size: compact ? 10 : 11))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: max(82, size + 30))
            }
            .scaleEffect(hoveredNodeID == node.id && !reduceMotion ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredNodeID = hovering ? node.id : nil
        }
        .help("\(node.name) · \(node.relationship ?? node.kind.label)")
        .accessibilityLabel("\(node.name), \(node.relationship ?? node.kind.label)")
    }

    private func graphArtwork(
        artist: String,
        resolution: ArtworkResolution?,
        name: String,
        size: CGFloat,
        tint: Color
    ) -> some View {
        ResolvedArtworkImage(
            artist: artist,
            target: .artist,
            sourceResolution: resolution
        ) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            initials(name, tint: tint)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private func initials(_ name: String, tint: Color) -> some View {
        ZStack {
            LinearGradient(
                colors: [tint.opacity(0.82), tint.opacity(0.38)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(initials(for: name))
                .font(.custom("Avenir Next Demi Bold", size: compact ? 16 : 18))
                .foregroundStyle(.white.opacity(0.94))
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            legendItem(kind: .similarity)
            legendItem(kind: .connection)
            legendItem(kind: .alias)
        }
        .font(.custom("Avenir Next Medium", size: 10))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
    }

    private func legendItem(kind: SimilarArtistGraphNode.Kind) -> some View {
        HStack(spacing: 5) {
            Circle().fill(nodeColor(kind)).frame(width: 7, height: 7)
            Text(kind.label).foregroundStyle(.secondary)
        }
    }

    private func selectionCaption(_ node: SimilarArtistGraphNode) -> some View {
        HStack(spacing: 7) {
            Circle().fill(nodeColor(node)).frame(width: 8, height: 8)
            Text(node.name).fontWeight(.semibold)
            Text(node.relationship ?? node.kind.label).foregroundStyle(.secondary)
        }
        .font(.custom("Avenir Next Medium", size: 11))
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: Capsule())
    }

    private struct GraphLayout {
        let center: CGPoint
        let centerSize: CGFloat
        let nodePositions: [String: CGPoint]
        let nodeSizes: [String: CGFloat]
    }

    private func graphLayout(in size: CGSize) -> GraphLayout {
        let center = CGPoint(x: size.width * 0.50, y: size.height * 0.51)
        let centerSize = min(compact ? 92 : 112, min(size.width, size.height) * 0.28)
        let shortSide = min(size.width, size.height)
        let maxValue = max(1, visibleNodes.map(\.value).max() ?? 1)
        var positions: [String: CGPoint] = [:]
        var sizes: [String: CGFloat] = [:]

        for (index, node) in visibleNodes.enumerated() {
            let count = max(1, visibleNodes.count)
            let angle = (2 * Double.pi * (Double(index) / Double(count))) - Double.pi / 2
            let alternateRing = count > 8 && index.isMultiple(of: 2)
            let radius = shortSide * (alternateRing ? 0.31 : (compact ? 0.37 : 0.40))
            let x = center.x + CGFloat(cos(angle)) * radius
            let y = center.y + CGFloat(sin(angle)) * radius * (compact ? 0.78 : 0.84)
            positions[node.id] = CGPoint(
                x: min(max(x, 54), size.width - 54),
                y: min(max(y, 62), size.height - 64)
            )
            let normalized = CGFloat(node.value / maxValue)
            sizes[node.id] = (compact ? 48 : 54) + normalized * (compact ? 10 : 16)
        }

        return GraphLayout(center: center, centerSize: centerSize, nodePositions: positions, nodeSizes: sizes)
    }

    private var selectedNode: SimilarArtistGraphNode? {
        visibleNodes.first { $0.id == selectedNodeID }
    }

    private func nodeColor(_ node: SimilarArtistGraphNode) -> Color {
        nodeColor(node.kind)
    }

    private func nodeColor(_ kind: SimilarArtistGraphNode.Kind) -> Color {
        switch kind {
        case .similarity: return Color(red: 0.35, green: 0.66, blue: 0.92)
        case .connection: return Color(red: 0.96, green: 0.38, blue: 0.34)
        case .alias: return Color(red: 0.70, green: 0.52, blue: 0.91)
        }
    }

    private func edgeColor(for node: SimilarArtistGraphNode) -> Color {
        nodeColor(node).opacity(colorScheme == .dark ? 0.86 : 0.72)
    }

    private func edgeWidth(for node: SimilarArtistGraphNode) -> CGFloat {
        switch node.kind {
        case .connection: return 1.7
        case .alias: return 1.2
        case .similarity: return 1.35
        }
    }

    private func initials(for name: String) -> String {
        let words = name.split(separator: " ").filter { !$0.isEmpty }
        return words.prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
}

struct ListenBrainzRecommendationComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var scrobbleService: ScrobbleService
    let recommendation: ListenBrainzRecommendedRecording
    let onComplete: () -> Void
    @State private var selectedRecipients: Set<String> = []
    @State private var blurb = ""
    @State private var isSending = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Send Recommendation")
                .font(.custom("Avenir Next Demi Bold", size: 24))

            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.title)
                    .font(.custom("Avenir Next Demi Bold", size: 16))
                Text(recommendation.artistName ?? AppLocalization.string("Unknown artist"))
                    .font(.custom("Avenir Next Medium", size: 13))
                    .foregroundStyle(.secondary)
                if let releaseName = recommendation.releaseName {
                    Text(releaseName)
                        .font(.custom("Avenir Next Regular", size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .appPanelStyle()

            Text("Followers")
                .font(.custom("Avenir Next Demi Bold", size: 16))

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(scrobbleService.listenBrainzFollowers, id: \.self) { follower in
                        Toggle(isOn: binding(for: follower)) {
                            Text(follower)
                                .font(.custom("Avenir Next Medium", size: 13))
                        }
                        .toggleStyle(.checkbox)
                    }
                }
            }
            .frame(maxHeight: 220)
            .appPanelStyle()

            VStack(alignment: .leading, spacing: 8) {
                Text("Blurb")
                    .font(.custom("Avenir Next Demi Bold", size: 16))
                TextEditor(text: $blurb)
                    .font(.custom("Avenir Next Regular", size: 13))
                    .frame(height: 120)
                    .padding(8)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Text(scrobbleService.listenBrainzRecommendationShareStatus)
                .font(.custom("Avenir Next Medium", size: 12))
                .foregroundStyle(.secondary)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    Task {
                        isSending = true
                        let sent = await scrobbleService.shareListenBrainzRecommendation(
                            recommendation,
                            to: Array(selectedRecipients).sorted(),
                            blurb: blurb
                        )
                        isSending = false
                        if sent {
                            onComplete()
                            dismiss()
                        }
                    }
                } label: {
                    if isSending {
                        Text("Sending...")
                    } else {
                        Text("Send")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSending || selectedRecipients.isEmpty)
            }
        }
    }

    private func binding(for follower: String) -> Binding<Bool> {
        Binding(
            get: { selectedRecipients.contains(follower) },
            set: { isSelected in
                if isSelected {
                    selectedRecipients.insert(follower)
                } else {
                    selectedRecipients.remove(follower)
                }
            }
        )
    }
}
