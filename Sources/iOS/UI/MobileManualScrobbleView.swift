import OpenScrobblerCore
import SwiftUI

struct MobileManualScrobbleView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var listeningStore: MobileListeningStore

    @State private var title = ""
    @State private var artist = ""
    @State private var album = ""
    @State private var durationMinutes = 3
    @State private var durationSeconds = 0
    @State private var listenedAt = Date()
    @State private var isSubmitting = false
    @State private var result: SubmissionResult?

    var body: some View {
        NavigationStack {
            Form {
                Section("Track") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                    TextField("Artist", text: $artist)
                        .textInputAutocapitalization(.words)
                    TextField("Album", text: $album)
                        .textInputAutocapitalization(.words)
                }

                Section("Listen") {
                    DatePicker("Listened", selection: $listenedAt, in: ...Date())
                    Stepper(value: $durationMinutes, in: 0...90) {
                        LabeledContent("Minutes", value: "\(durationMinutes)")
                    }
                    Stepper(value: $durationSeconds, in: 0...59) {
                        LabeledContent("Seconds", value: "\(durationSeconds)")
                    }
                }

                if let result {
                    Section {
                        Label(result.message, systemImage: result.symbol)
                            .foregroundStyle(result.tint)
                    }
                }
            }
            .navigationTitle("Manual Scrobble")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await submit()
                        }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Submit")
                        }
                    }
                    .disabled(!canSubmit || isSubmitting)
                }
            }
        }
    }

    private var canSubmit: Bool {
        !trimmed(title).isEmpty &&
        !trimmed(artist).isEmpty &&
        duration >= 30 &&
        listeningStore.hasStoredToken
    }

    private var duration: TimeInterval {
        TimeInterval((durationMinutes * 60) + durationSeconds)
    }

    private func submit() async {
        guard canSubmit else { return }

        isSubmitting = true
        result = nil
        defer { isSubmitting = false }

        let candidate = MobileScrobbleCandidate(
            title: trimmed(title),
            artist: trimmed(artist),
            album: trimmed(album).nilIfBlank,
            duration: duration,
            listenedAt: listenedAt,
            source: "OpenScrobbler iOS Manual"
        )

        do {
            try await listeningStore.submitScrobble(candidate)
            result = SubmissionResult(message: "Submitted to ListenBrainz.", symbol: "checkmark.circle", tint: .green)
            title = ""
            artist = ""
            album = ""
            durationMinutes = 3
            durationSeconds = 0
            listenedAt = Date()
            await listeningStore.refresh()
        } catch {
            result = SubmissionResult(message: error.localizedDescription, symbol: "exclamationmark.triangle", tint: .red)
        }
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct SubmissionResult {
    let message: String
    let symbol: String
    let tint: Color
}

private extension String {
    var nilIfBlank: String? {
        isEmpty ? nil : self
    }
}
