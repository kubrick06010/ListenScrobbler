import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

struct InspectorResizeHandle: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var width: Double
    let minimum: CGFloat
    let maximum: CGFloat
    @State private var dragBaseWidth: Double?
    @State private var isHovering = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.clear)
                .frame(width: 18)
                .contentShape(Rectangle())

            Capsule(style: .continuous)
                .fill(handleColor)
                .frame(width: isHovering ? 6 : 4, height: 72)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.18 : 0.08), radius: 8, y: 0)
        }
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.resizeLeftRight.push()
            } else {
                NSCursor.pop()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    let base = dragBaseWidth ?? width
                    dragBaseWidth = base
                    let candidate = base - value.translation.width
                    width = min(max(candidate, Double(minimum)), Double(maximum))
                }
                .onEnded { _ in
                    dragBaseWidth = nil
                    width = min(max(width, Double(minimum)), Double(maximum))
                }
        )
        .accessibilityLabel("Resize inspector")
    }

    private var handleColor: Color {
        if isHovering {
            return Color(red: 1.0, green: 0.33, blue: 0.36).opacity(0.92)
        }
        return colorScheme == .dark ? Color.white.opacity(0.22) : Color.black.opacity(0.16)
    }
}
