import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

struct ArtistAffinityGraphView: View {
    let graph: ArtistAffinityGraphSnapshot
    let onOpenArtist: (String) -> Void
    private let accent = Color(red: 1.0, green: 0.30, blue: 0.35)

    @State private var zoom: CGFloat = 1
    @State private var accumulatedZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var accumulatedOffset: CGSize = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Connected through ListenBrainz similarity data")
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Pinch to zoom, drag to pan")
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(.secondary)
                Button("Reset") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        zoom = 1
                        accumulatedZoom = 1
                        offset = .zero
                        accumulatedOffset = .zero
                    }
                }
                .buttonStyle(.plain)
                .font(.custom("Avenir Next Medium", size: 11))
            }

            GeometryReader { geo in
                let positions = layoutPositions(in: geo.size)
                ZStack {
                    ForEach(graph.edges) { edge in
                        if let from = positions[edge.from], let to = positions[edge.to] {
                            Path { path in
                                path.move(to: from)
                                path.addLine(to: to)
                            }
                            .stroke(Color.white.opacity(0.12), lineWidth: edgeWidth(edge.weight))
                        }
                    }

                    ForEach(graph.nodes) { node in
                        if let point = positions[node.id] {
                            Button {
                                onOpenArtist(node.displayName)
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(nodeColor(node))
                                    Circle()
                                        .stroke(Color.white.opacity(0.24), lineWidth: node.isSeed ? 2 : 1)
                                }
                                .frame(width: nodeSize(node), height: nodeSize(node))
                            }
                            .buttonStyle(.plain)
                            .position(point)

                            if node.isSeed || node.connectionCount > 1 {
                                Text(node.displayName)
                                    .font(.custom("Avenir Next Medium", size: 10))
                                    .lineLimit(1)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                                    .position(x: point.x, y: point.y + 16)
                            }
                        }
                    }
                }
                .scaleEffect(zoom)
                .offset(offset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: accumulatedOffset.width + value.translation.width,
                                height: accumulatedOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            accumulatedOffset = offset
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            zoom = min(4.0, max(0.55, accumulatedZoom * value))
                        }
                        .onEnded { _ in
                            accumulatedZoom = zoom
                        }
                )
            }

            HStack(spacing: 14) {
                legendDot(accent, "Seeds")
                legendDot(.cyan, "Cross-linked")
                legendDot(.white.opacity(0.65), "Related")
            }
        }
    }

    private func layoutPositions(in size: CGSize) -> [String: CGPoint] {
        guard !graph.nodes.isEmpty else { return [:] }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let seeds = graph.nodes.filter(\.isSeed)
        let nonSeeds = graph.nodes.filter { !$0.isSeed }
        var positions: [String: CGPoint] = [:]

        if seeds.isEmpty {
            return positions
        }

        let innerRadius = min(size.width, size.height) * 0.18
        for (index, node) in seeds.enumerated() {
            let angle = (2 * Double.pi * (Double(index) / Double(max(1, seeds.count)))) - Double.pi / 2
            positions[node.id] = CGPoint(
                x: center.x + CGFloat(cos(angle)) * innerRadius,
                y: center.y + CGFloat(sin(angle)) * innerRadius
            )
        }

        let outerRadius = min(size.width, size.height) * 0.39
        for (index, node) in nonSeeds.enumerated() {
            let angle = (2 * Double.pi * (Double(index) / Double(max(1, nonSeeds.count)))) - Double.pi / 2
            positions[node.id] = CGPoint(
                x: center.x + CGFloat(cos(angle)) * outerRadius,
                y: center.y + CGFloat(sin(angle)) * outerRadius
            )
        }

        return positions
    }

    private func nodeColor(_ node: ArtistAffinityNode) -> Color {
        if node.isSeed { return accent }
        if node.connectionCount > 1 { return .cyan }
        return .white.opacity(0.72)
    }

    private func nodeSize(_ node: ArtistAffinityNode) -> CGFloat {
        if node.isSeed { return 18 }
        if node.connectionCount > 1 { return 14 }
        return 10
    }

    private func edgeWidth(_ weight: Int) -> CGFloat {
        if weight > 100_000 { return 2.4 }
        if weight > 10_000 { return 1.8 }
        return 1.2
    }

    private func legendDot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)
        }
    }
}
