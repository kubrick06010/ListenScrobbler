import SwiftUI

struct MacOpenMusicOnboardingView: View {
    let complete: () -> Void
    @Environment(\.openURL) private var openURL

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                        ForEach(ListenBrainzSetupGuide.onboardingFeatures) { feature in
                            MacOnboardingFeatureTile(feature: feature)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Setup checklist")
                            .font(.custom("Avenir Next Demi Bold", size: 18))

                        ForEach(Array(ListenBrainzSetupGuide.steps.enumerated()), id: \.element.id) { offset, step in
                            ListenBrainzNumberedSetupStepTile(index: offset + 1, step: step)
                        }
                    }
                    .appPanelStyle()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Use these only when you need the web step.")
                            .font(.custom("Avenir Next Regular", size: 12))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            ForEach(ListenBrainzSetupGuide.onboardingActions) { action in
                                Button {
                                    openURL(action.url)
                                } label: {
                                    Label(action.title, systemImage: action.symbolName)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .font(.custom("Avenir Next Medium", size: 12))
                }
                .padding(24)
            }

            Divider()

            HStack {
                Text("You can reopen this anytime from ListenBrainz settings.")
                    .font(.custom("Avenir Next Regular", size: 12))
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Done") {
                    complete()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image("ListenPulse")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(ListenBrainzSetupGuide.eyebrow)
                        .font(.custom("Avenir Next Demi Bold", size: 12))
                        .foregroundStyle(Color(red: 0.83, green: 0.06, blue: 0.09))
                    Text("ListenScrobbler")
                        .font(.custom("Avenir Next Demi Bold", size: 20))
                }
            }

            Text(ListenBrainzSetupGuide.headline)
                .font(.custom("Avenir Next Demi Bold", size: 34))
                .fixedSize(horizontal: false, vertical: true)

            Text(ListenBrainzSetupGuide.summary)
                .font(.custom("Avenir Next Regular", size: 14))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .appPanelStyle()
    }
}

private struct MacOnboardingFeatureTile: View {
    let feature: ListenBrainzOnboardingFeature

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: feature.symbolName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color(red: 0.83, green: 0.06, blue: 0.09), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(feature.title)
                .font(.custom("Avenir Next Demi Bold", size: 14))

            Text(feature.detail)
                .font(.custom("Avenir Next Regular", size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .appPanelStyle()
    }
}
