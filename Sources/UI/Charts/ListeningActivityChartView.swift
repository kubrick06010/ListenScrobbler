import Charts
import SwiftUI

struct ListeningActivityChartView: View {
    let activity: [ListenBrainzListeningActivity]
    let range: ListenBrainzStatsRange

    private var visibleActivity: [ListenBrainzListeningActivity] {
        Array(activity.suffix(28))
    }

    var body: some View {
        GeometryReader { proxy in
            let entries = visibleActivity
            let labelStride = max(Int(ceil(Double(entries.count) / Double(max(Int(proxy.size.width / 72), 2)))), 1)

            Chart(Array(entries.enumerated()), id: \.element.id) { index, entry in
                AreaMark(
                    x: .value("Period", index),
                    y: .value("Listens", entry.listenCount)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.36), Color.cyan.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .accessibilityLabel(entry.label)
                .accessibilityValue(String.localizedStringWithFormat(
                    String(localized: "%@ listens"),
                    AppLocalization.integer(entry.listenCount)
                ))

                LineMark(
                    x: .value("Period", index),
                    y: .value("Listens", entry.listenCount)
                )
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .foregroundStyle(Color.accentColor.opacity(0.92))
            }
            .chartXAxis {
                AxisMarks(values: Array(entries.indices.filter { $0.isMultiple(of: labelStride) })) { value in
                    AxisGridLine().foregroundStyle(.clear)
                    AxisTick().foregroundStyle(.secondary.opacity(0.45))
                    AxisValueLabel {
                        if let index = value.as(Int.self), entries.indices.contains(index) {
                            Text(shortLabel(entries[index]))
                                .font(.custom("Avenir Next Medium", size: 10))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                        .foregroundStyle(.secondary.opacity(0.18))
                    AxisValueLabel {
                        if let count = value.as(Int.self) {
                            Text(AppLocalization.integer(count))
                                .font(.custom("Avenir Next Medium", size: 10))
                        }
                    }
                }
            }
            .chartPlotStyle { plot in
                plot
                    .background(Color.white.opacity(0.018))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .frame(minHeight: 190, idealHeight: 230, maxHeight: 260)
        .padding(.horizontal, 4)
        .padding(.top, 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Listening Activity")
    }

    private func shortLabel(_ activity: ListenBrainzListeningActivity) -> String {
        if let from = activity.from {
            if range == .year || range == .allTime {
                return from.formatted(.dateTime.month(.abbreviated).locale(preferredAppLocale()))
            }
            return from.formatted(.dateTime.day().locale(preferredAppLocale()))
        }
        return String(activity.label.prefix(3))
    }
}
