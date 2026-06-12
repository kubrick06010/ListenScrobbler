import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

struct ProfileWebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }
}

struct AnimatedAvatarImage: NSViewRepresentable {
    let urls: [URL]
    let size: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.enclosingScrollView?.drawsBackground = false
        webView.allowsMagnification = false
        webView.allowsBackForwardNavigationGestures = false
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.load(urls: urls, into: webView)
    }

    final class Coordinator {
        private var lastMarkup: String?

        func load(urls: [URL], into webView: WKWebView) {
            let candidates = urls.map(\.absoluteString)
            guard let data = try? JSONSerialization.data(withJSONObject: candidates),
                  let json = String(data: data, encoding: .utf8) else { return }

            // Use HTML img object-fit cover so avatar is cropped like native cover mode,
            // while still preserving GIF animation.
            let markup = """
            <html>
              <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <style>
                  html,body{margin:0;padding:0;overflow:hidden;background:transparent;width:100%;height:100%;}
                  #avatar{width:100%;height:100%;object-fit:cover;border-radius:50%;display:block;}
                </style>
              </head>
              <body>
                <img id="avatar" alt="" />
                <script>
                  const urls = \(json);
                  let i = 0;
                  const img = document.getElementById('avatar');
                  function next() {
                    if (i >= urls.length) return;
                    img.src = urls[i++];
                  }
                  img.onerror = next;
                  next();
                </script>
              </body>
            </html>
            """

            guard markup != lastMarkup else { return }
            lastMarkup = markup
            webView.loadHTMLString(markup, baseURL: nil)
        }
    }
}
