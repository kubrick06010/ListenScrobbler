import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

struct SimilarArtistGraphNode: Identifiable, Equatable {
    let id: String
    let name: String
    let value: Double
    let imageURL: String?
}

struct SimilarArtistGraphView: View {
    @Environment(\.colorScheme) private var colorScheme
    let centerName: String
    let nodes: [SimilarArtistGraphNode]
    let compact: Bool

    private var visibleNodes: [SimilarArtistGraphNode] {
        Array(nodes.prefix(compact ? 8 : 14))
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
                        .stroke(edgeColor(for: node).opacity(colorScheme == .dark ? 0.46 : 0.34), lineWidth: 1.25)
                    }
                }

                ForEach(clusterEdges(in: layout.nodePositions), id: \.0) { edge in
                    if let from = layout.nodePositions[edge.0], let to = layout.nodePositions[edge.1] {
                        Path { path in
                            path.move(to: from)
                            path.addLine(to: to)
                        }
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                    }
                }

                artistNode(
                    title: centerName,
                    fill: Color(red: 0.24, green: 0.20, blue: 0.50),
                    textColor: .white,
                    size: layout.centerSize,
                    fontSize: compact ? 20 : 25
                )
                .position(layout.center)

                ForEach(Array(visibleNodes.enumerated()), id: \.element.id) { index, node in
                    if let point = layout.nodePositions[node.id] {
                        artistNode(
                            title: node.name,
                            fill: nodeFill(index: index, node: node),
                            textColor: nodeTextColor(index: index),
                            size: layout.nodeSizes[node.id] ?? 72,
                            fontSize: compact ? 11 : 13
                        )
                        .position(point)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var graphBackground: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color.white.opacity(0.04), Color.white.opacity(0.015)]
                : [Color.white.opacity(0.82), Color(red: 0.91, green: 0.94, blue: 0.99)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
        }
    }

    private func artistNode(
        title: String,
        fill: Color,
        textColor: Color,
        size: CGFloat,
        fontSize: CGFloat
    ) -> some View {
        ZStack {
            Circle()
                .fill(fill)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.10), radius: 7, x: 0, y: 4)
            Text(title)
                .font(.custom("Avenir Next Medium", size: fontSize))
                .foregroundStyle(textColor)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.68)
                .padding(.horizontal, 8)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .help(title)
    }

    private struct GraphLayout {
        let center: CGPoint
        let centerSize: CGFloat
        let nodePositions: [String: CGPoint]
        let nodeSizes: [String: CGFloat]
    }

    private func graphLayout(in size: CGSize) -> GraphLayout {
        let center = CGPoint(x: size.width * 0.52, y: size.height * 0.53)
        let centerSize = min(compact ? 108 : 136, min(size.width, size.height) * 0.34)
        let baseRadius = max(92, min(size.width, size.height) * (compact ? 0.34 : 0.38))
        let maxValue = max(1, visibleNodes.map(\.value).max() ?? 1)
        var positions: [String: CGPoint] = [:]
        var sizes: [String: CGFloat] = [:]

        for (index, node) in visibleNodes.enumerated() {
            let count = max(1, visibleNodes.count)
            let spread = count > 10 ? 0.94 : 0.88
            let angle = (2 * Double.pi * (Double(index) / Double(count))) - Double.pi / 2
            let radiusJitter = CGFloat(index % 3) * (compact ? 8 : 14)
            let radius = baseRadius * spread + radiusJitter
            let x = center.x + CGFloat(cos(angle)) * radius
            let y = center.y + CGFloat(sin(angle)) * radius * (compact ? 0.86 : 0.92)
            positions[node.id] = CGPoint(
                x: min(max(x, 44), size.width - 44),
                y: min(max(y, 44), size.height - 44)
            )
            let normalized = CGFloat(node.value / maxValue)
            sizes[node.id] = (compact ? 62 : 76) + normalized * (compact ? 18 : 26)
        }

        return GraphLayout(center: center, centerSize: centerSize, nodePositions: positions, nodeSizes: sizes)
    }

    private func clusterEdges(in positions: [String: CGPoint]) -> [(String, String)] {
        guard visibleNodes.count >= 6 else { return [] }
        return stride(from: 1, to: visibleNodes.count, by: 4).compactMap { index in
            guard index + 1 < visibleNodes.count else { return nil }
            return (visibleNodes[index].id, visibleNodes[index + 1].id)
        }
    }

    private func nodeFill(index: Int, node: SimilarArtistGraphNode) -> Color {
        let palette: [Color] = [
            Color(red: 0.48, green: 0.59, blue: 0.82),
            Color(red: 0.50, green: 0.54, blue: 0.64),
            Color(red: 0.54, green: 0.52, blue: 0.44),
            Color(red: 0.42, green: 0.52, blue: 0.77)
        ]
        return palette[index % palette.count].opacity(node.imageURL == nil ? 0.92 : 1)
    }

    private func nodeTextColor(index: Int) -> Color {
        index % 4 == 0 ? Color.primary.opacity(colorScheme == .dark ? 0.95 : 0.78) : .white
    }

    private func edgeColor(for node: SimilarArtistGraphNode) -> Color {
        node.imageURL == nil ? .secondary : Color(red: 0.48, green: 0.58, blue: 0.82)
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
                Text(recommendation.artistName ?? "Unknown artist")
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

                Button(isSending ? "Sending..." : "Send") {
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
