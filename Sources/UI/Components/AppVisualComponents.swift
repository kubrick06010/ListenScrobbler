import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

struct AppBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let glyphWidth = min(proxy.size.width * 0.50, 860)
            let glyphHeight = glyphWidth * 0.62

            ZStack {
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [
                            Color(red: 0.10, green: 0.10, blue: 0.11),
                            Color(red: 0.05, green: 0.05, blue: 0.06)
                        ]
                        : [
                            Color(red: 0.97, green: 0.96, blue: 0.95),
                            Color(red: 0.93, green: 0.92, blue: 0.90)
                        ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: colorScheme == .dark
                        ? [Color(red: 0.83, green: 0.06, blue: 0.09).opacity(0.22), .clear]
                        : [Color(red: 0.83, green: 0.06, blue: 0.09).opacity(0.12), .clear],
                    center: .topLeading,
                    startRadius: 40,
                    endRadius: 520
                )
                .offset(x: -120, y: -80)

                RadialGradient(
                    colors: colorScheme == .dark
                        ? [Color.white.opacity(0.05), .clear]
                        : [Color.white.opacity(0.18), .clear],
                    center: .center,
                    startRadius: 40,
                    endRadius: 420
                )
                .offset(x: 220, y: -120)

                backdropGlyph(
                    color: colorScheme == .dark
                        ? Color(red: 0.83, green: 0.06, blue: 0.09).opacity(0.16)
                        : Color(red: 0.83, green: 0.06, blue: 0.09).opacity(0.09),
                    width: glyphWidth,
                    height: glyphHeight
                )
                .offset(x: -proxy.size.width * 0.10, y: -proxy.size.height * 0.08)

                backdropGlyph(
                    color: colorScheme == .dark
                        ? Color.white.opacity(0.04)
                        : Color.black.opacity(0.035),
                    width: glyphWidth * 0.92,
                    height: glyphHeight * 0.92
                )
                .offset(x: -proxy.size.width * 0.085, y: -proxy.size.height * 0.06)
            }
            .ignoresSafeArea()
        }
    }

    private func backdropGlyph(color: Color, width: CGFloat, height: CGFloat) -> some View {
        // Use a scalable text-based mark here instead of the 18x18 menu bar bitmap.
        // The tray asset is intentionally tiny; blowing it up for the app backdrop
        // creates visible pixelation on large windows.
        Text("as")
            .font(.custom("Avenir Next Heavy", size: width * 0.68))
            .italic()
            .tracking(-width * 0.035)
            .foregroundStyle(color)
            .frame(width: width, height: height, alignment: .center)
            .minimumScaleFactor(0.7)
            .blur(radius: colorScheme == .dark ? 24 : 20)
            .drawingGroup()
    }
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    @State private var image: NSImage?
    @State private var loadedURL: URL?
    @State private var failedURL: URL?

    private var requestURL: URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "http" else {
            return url
        }
        components.scheme = "https"
        return components.url ?? url
    }

    var body: some View {
        Group {
            if let image, loadedURL == requestURL {
                content(Image(nsImage: image))
            } else {
                placeholder()
            }
        }
        .task(id: requestURL) {
            await load(requestURL)
        }
    }

    private func load(_ targetURL: URL) async {
        guard loadedURL != targetURL, failedURL != targetURL else { return }
        image = nil
        loadedURL = nil
        failedURL = nil

        let request = URLRequest(url: targetURL, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 12)

        if let cached = URLCache.shared.cachedResponse(for: request),
           let decoded = NSImage(data: cached.data) {
            image = decoded
            loadedURL = targetURL
            return
        }

        do {
            // Artwork must use the same proxy configuration as MusicBrainz and
            // the compatibility API. Using URLSession.shared here bypassed a
            // user's manual proxy and made otherwise valid artwork URLs appear
            // as placeholders in the UI.
            let session = URLSession.compatibilitySession(proxySettings: ProxySettingsStore().load())
            let (data, response) = try await session.data(for: request)
            guard let decoded = NSImage(data: data) else {
                failedURL = targetURL
                return
            }
            URLCache.shared.storeCachedResponse(CachedURLResponse(response: response, data: data), for: request)
            image = decoded
            loadedURL = targetURL
        } catch {
            failedURL = targetURL
        }
    }
}

/// Resolves artwork by musical identity through `ScrobbleService` and renders
/// only an allowlisted typed result. This is the reusable boundary for all
/// macOS artist/track/release surfaces; views never implement provider chains.
struct ResolvedArtworkImage<Content: View, Placeholder: View>: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService

    let artist: String
    let track: String?
    let album: String?
    let target: ArtworkLevel
    let sourceResolution: ArtworkResolution?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var resolvedResolution: ArtworkResolution?

    init(
        artist: String,
        track: String? = nil,
        album: String? = nil,
        target: ArtworkLevel,
        sourceResolution: ArtworkResolution? = nil,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.artist = artist
        self.track = track
        self.album = album
        self.target = target
        self.sourceResolution = sourceResolution
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let urlString = effectiveResolution?.url,
               let url = URL(string: urlString) {
                CachedAsyncImage(url: url, content: content, placeholder: placeholder)
            } else {
                placeholder()
            }
        }
        .task(id: requestID) {
            guard sourceResolution?.automaticArtworkResolution == nil else {
                resolvedResolution = nil
                return
            }
            resolvedResolution = await scrobbleService.artworkResolution(
                artist: artist,
                track: track,
                album: album,
                target: target,
                sourceResolution: sourceResolution
            )
        }
    }

    private var effectiveResolution: ArtworkResolution? {
        sourceResolution?.automaticArtworkResolution
            ?? resolvedResolution?.automaticArtworkResolution
    }

    private var requestID: String {
        [
            target.rawValue,
            artist,
            track ?? "",
            album ?? "",
            sourceResolution?.provider.rawValue ?? "",
            sourceResolution?.url ?? ""
        ].joined(separator: "::")
    }
}

struct HTMLSummaryText: View {
    let rawHTML: String
    let fontSize: CGFloat
    var lineLimit: Int? = nil

    var body: some View {
        Group {
            if let attributed = htmlSummaryAttributedString(from: rawHTML) {
                Text(attributed)
            } else {
                Text(rawHTML)
            }
        }
        .font(.custom("Avenir Next Regular", size: fontSize))
        .foregroundStyle(.secondary)
        .lineLimit(lineLimit)
        .tint(.accentColor)
        .textSelection(.enabled)
    }

    private func htmlSummaryAttributedString(from rawHTML: String) -> AttributedString? {
        guard let data = rawHTML.data(using: .utf8) else { return nil }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        guard let nsAttributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil),
              let attributed = try? AttributedString(nsAttributed, including: AttributeScopes.FoundationAttributes.self) else {
            return nil
        }
        return attributed
    }
}

extension View {
    func appPanelStyle() -> some View {
        modifier(AppPanelModifier())
    }
}

extension Array where Element == String {
    func uniquedCaseInsensitive() -> [String] {
        var seen = Set<String>()
        return filter { value in
            let key = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { return false }
            return seen.insert(key).inserted
        }
    }
}
