import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

struct InteractiveSeparationGraphView: View {
    let graph: SocialGraphSnapshot
    let onOpenUser: (String) -> Void
    private let accent = Color(red: 1.0, green: 0.30, blue: 0.35)

    @State private var zoom: CGFloat = 1
    @State private var accumulatedZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var accumulatedOffset: CGSize = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Separation Network")
                    .font(.custom("Avenir Next Demi Bold", size: 18))
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
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        }
                    }

                    ForEach(graph.nodes) { node in
                        if let point = positions[node.id] {
                            Button {
                                onOpenUser(node.displayName)
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(nodeColor(node))
                                    Circle()
                                        .stroke(Color.white.opacity(0.24), lineWidth: node.isSource ? 2 : 1)
                                }
                                .frame(width: nodeSize(node), height: nodeSize(node))
                            }
                            .buttonStyle(.plain)
                            .position(point)

                            if node.isSource || node.isTarget || node.degree <= 1 {
                                Text(node.displayName)
                                    .font(.custom("Avenir Next Medium", size: 10))
                                    .lineLimit(1)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                                    .position(x: point.x, y: point.y + 14)
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
                legendDot(accent, "You")
                legendDot(.cyan, "Target")
                legendDot(.white.opacity(0.6), "Intermediate")
            }
        }
    }

    private func layoutPositions(in size: CGSize) -> [String: CGPoint] {
        guard !graph.nodes.isEmpty else { return [:] }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxDegree = max(1, graph.nodes.map(\.degree).max() ?? 1)
        let baseRadius = min(size.width, size.height) * 0.44
        let ringStep = baseRadius / CGFloat(maxDegree)
        let groups = Dictionary(grouping: graph.nodes, by: \.degree)
        var positions: [String: CGPoint] = [:]
        positions.reserveCapacity(graph.nodes.count)

        for degree in groups.keys.sorted() {
            guard let nodesAtDegree = groups[degree] else { continue }
            if degree == 0 {
                if let source = nodesAtDegree.first {
                    positions[source.id] = center
                }
                continue
            }
            let radius = ringStep * CGFloat(degree)
            let count = nodesAtDegree.count
            for (idx, node) in nodesAtDegree.enumerated() {
                let angle = (2 * Double.pi * (Double(idx) / Double(max(1, count)))) - Double.pi / 2
                let x = center.x + CGFloat(cos(angle)) * radius
                let y = center.y + CGFloat(sin(angle)) * radius
                positions[node.id] = CGPoint(x: x, y: y)
            }
        }
        return positions
    }

    private func nodeColor(_ node: SocialGraphNode) -> Color {
        if node.isSource { return accent }
        if node.isTarget { return .cyan }
        return .white.opacity(0.72)
    }

    private func nodeSize(_ node: SocialGraphNode) -> CGFloat {
        if node.isSource { return 12 }
        if node.isTarget { return 10 }
        return 8
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
