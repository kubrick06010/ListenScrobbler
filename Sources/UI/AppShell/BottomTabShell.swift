import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

struct BottomTabShell: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedTab: WorkspaceTab
    private let tabs: [WorkspaceTab] = [.scrobbles, .charts, .social]
    private let accent = Color(red: 1.0, green: 0.30, blue: 0.35)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.id) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 18, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.custom("Avenir Next Medium", size: 13))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(selectedTab == tab ? accent : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color.black.opacity(0.9), Color(red: 0.12, green: 0.13, blue: 0.16)]
                    : [Color.white.opacity(0.88), Color(red: 0.92, green: 0.94, blue: 0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08))
                .frame(height: 1)
        }
    }
}
