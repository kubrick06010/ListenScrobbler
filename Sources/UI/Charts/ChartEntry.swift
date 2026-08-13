import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

struct ChartEntry {
    let id: String
    let title: String
    let artist: String
    var artworkResolution: ArtworkResolution?
    var count: Int
}
