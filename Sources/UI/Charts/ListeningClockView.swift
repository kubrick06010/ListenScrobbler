import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

enum ReportPeriod: CaseIterable {
    case week
    case month
    case year

    var label: String {
        switch self {
        case .week: return "Last.week"
        case .month: return "Last.month"
        case .year: return "Last.year"
        }
    }

    var currentLabel: String {
        switch self {
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        }
    }

    var previousLabel: String {
        switch self {
        case .week: return "last week"
        case .month: return "last month"
        case .year: return "last year"
        }
    }

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .year: return 365
        }
    }

    func interval(offsetUnits: Int) -> DateInterval {
        let now = Date()
        let days = self.days
        let end = Calendar.current.date(byAdding: .day, value: -(offsetUnits * days), to: now) ?? now
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end) ?? now
        return DateInterval(start: start, end: end)
    }
}

struct ListeningClockView: View {
    let thisWeek: [Int]
    let comparison: [Int]
    let accent: Color
    private let comparisonColor = Color.white.opacity(0.2)

    var body: some View {
        GeometryReader { proxy in
            let chartSize = min(proxy.size.width, 320)
            VStack(spacing: 12) {
                ZStack {
                    ForEach(0..<24, id: \.self) { hour in
                        let start = angle(for: hour, offsetDegrees: 0.8)
                        let end = angle(for: hour + 1, offsetDegrees: -0.8)
                        let current = normalized(value(for: hour, in: thisWeek))
                        let previous = normalized(value(for: hour, in: comparison))

                        ClockWedge(startAngle: start, endAngle: end, innerRatio: 0.30, outerRatio: 0.82)
                            .fill(Color.white.opacity(0.05))

                        if previous > 0 {
                            ClockWedge(
                                startAngle: start,
                                endAngle: end,
                                innerRatio: 0.30,
                                outerRatio: 0.30 + previous * 0.50
                            )
                            .fill(comparisonColor)
                        }

                        if current > 0 {
                            ClockWedge(
                                startAngle: start,
                                endAngle: end,
                                innerRatio: 0.30,
                                outerRatio: 0.30 + current * 0.50
                            )
                            .fill(
                                LinearGradient(
                                    colors: [accent.opacity(0.95), accent.opacity(0.75)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                    }

                    Circle()
                        .fill(Color.black.opacity(0.35))
                        .frame(width: chartSize * 0.36, height: chartSize * 0.36)
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        .frame(width: chartSize * 0.36, height: chartSize * 0.36)

                    Group {
                        clockLabel("00", x: 0, y: -chartSize * 0.42)
                        clockLabel("06", x: chartSize * 0.42, y: 0)
                        clockLabel("12", x: 0, y: chartSize * 0.42)
                        clockLabel("18", x: -chartSize * 0.42, y: 0)
                    }
                }
                .frame(width: chartSize, height: chartSize)
                .frame(maxWidth: .infinity)

                HStack(spacing: 14) {
                    legendSwatch(color: accent, label: "Current")
                    legendSwatch(color: comparisonColor, label: "Comparison")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 356)
    }

    private func value(for hour: Int, in source: [Int]) -> Int {
        source.indices.contains(hour) ? source[hour] : 0
    }

    private func normalized(_ value: Int) -> CGFloat {
        let peak = max(1, (thisWeek + comparison).max() ?? 1)
        return CGFloat(Double(value) / Double(peak))
    }

    private func angle(for hour: Int, offsetDegrees: Double) -> Angle {
        Angle.degrees((Double(hour % 24) / 24.0) * 360.0 - 90.0 + offsetDegrees)
    }

    private func clockLabel(_ text: String, x: CGFloat, y: CGFloat) -> some View {
        Text(text)
            .font(.custom("Avenir Next Medium", size: 11))
            .foregroundStyle(.secondary)
            .offset(x: x, y: y)
    }

    private func legendSwatch(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 14, height: 10)
            Text(label)
                .font(.custom("Avenir Next Medium", size: 12))
                .foregroundStyle(.secondary)
        }
    }
}

struct ClockWedge: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let innerRatio: CGFloat
    let outerRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let inner = radius * min(max(innerRatio, 0.0), 0.98)
        let outer = radius * min(max(outerRatio, innerRatio), 1.0)

        var path = Path()
        path.addArc(center: center, radius: outer, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        path.closeSubpath()
        return path
    }
}
