import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

struct ReportsView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @State private var period: ReportPeriod = .week
    private let accent = Color(red: 1.0, green: 0.30, blue: 0.35)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Reports")
                    .font(.custom("Avenir Next Demi Bold", size: 24))

                Picker("Period", selection: $period) {
                    ForEach(ReportPeriod.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .appPanelStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(currentCount.formatted()) Listens")
                        .font(.custom("Avenir Next Demi Bold", size: 34))
                    Text("vs. \(comparisonCount.formatted()) \(comparisonTitle)")
                        .font(.custom("Avenir Next Medium", size: 20))
                    Text("\(periodTitle) trend: \(trendPercentString)")
                        .font(.custom("Avenir Next Medium", size: 15))
                        .foregroundStyle(.secondary)
                }
                .appPanelStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Avg. listens per day")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    reportBar("This \(periodTitle)", value: currentAvg, max: max(currentAvg, comparisonAvg))
                    reportBar(period.previousLabel, value: comparisonAvg, max: max(currentAvg, comparisonAvg))
                }
                .appPanelStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Top tags")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    if topTags.isEmpty {
                        Text("No tags available yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(topTags.prefix(5), id: \.name) { tag in
                            reportBar(tag.name, value: tag.count, max: topTags.first?.count ?? 1)
                        }
                    }
                }
                .appPanelStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Listening clock")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    Text("You listened the most at \(peakHourLabel) this period.")
                        .font(.custom("Avenir Next Medium", size: 14))
                        .foregroundStyle(.secondary)
                    ListeningClockView(
                        thisWeek: hourlyCountsCurrent,
                        comparison: hourlyCountsComparison,
                        accent: accent
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .appPanelStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Mainstream score")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    Text("With a \(mainstreamScore)% mainstream score, you are \(mainstreamTone) compared to your recent baseline.")
                        .font(.custom("Avenir Next Medium", size: 15))
                        .foregroundStyle(.secondary)
                    reportBar("Mainstream", value: mainstreamScore, max: 100)
                    Text("vs. \(mainstreamBaseline)% baseline")
                        .font(.custom("Avenir Next Medium", size: 13))
                        .foregroundStyle(.secondary)
                }
                .appPanelStyle()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Trends vs. \(comparisonTitle)")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    ForEach(weekdayTrends, id: \.day) { point in
                        HStack {
                            Text(point.day)
                                .font(.custom("Avenir Next Medium", size: 13))
                                .frame(width: 42, alignment: .leading)
                            reportBarInline(value: point.current, max: weekdayMax)
                            Text(point.current.formatted())
                                .font(.custom("Avenir Next Medium", size: 12))
                                .foregroundStyle(.secondary)
                            Text("vs \(point.previous.formatted())")
                                .font(.custom("Avenir Next Medium", size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .appPanelStyle()
            }
            .padding(24)
        }
    }

    private func reportBar(_ label: String, value: Int, max: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.custom("Avenir Next Medium", size: 15))
                Spacer()
                Text(value.formatted())
                    .font(.custom("Avenir Next Medium", size: 15))
            }
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .mask(
                            GeometryReader { geo in
                                let ratio = max > 0 ? Double(value) / Double(max) : 0
                                Rectangle().frame(width: geo.size.width * ratio)
                            }
                        )
                }
                .frame(height: 12)
        }
    }

    private var currentCount: Int {
        let direct = countScrobbles(in: rangeCurrent)
        if direct > 0 { return direct }
        // If local recent history is too shallow, fall back to period top-artist aggregates.
        return topArtistAggregate(for: period)
    }

    private var comparisonCount: Int {
        let direct = countScrobbles(in: rangeComparison)
        if direct > 0 { return direct }
        return 0
    }

    private var currentAvg: Int {
        currentCount / max(1, period.days)
    }

    private var comparisonAvg: Int {
        comparisonCount / max(1, period.days)
    }

    private var trendPercentString: String {
        guard comparisonCount > 0 else { return "Not enough historical data" }
        let delta = Double(currentCount - comparisonCount) / Double(comparisonCount)
        let pct = Int((delta * 100).rounded())
        return pct >= 0 ? "+\(pct)%" : "\(pct)%"
    }

    private func countScrobbles(in range: DateInterval) -> Int {
        return scrobbleService.latestScrobbles.filter { item in
            guard let played = item.playedAt else { return false }
            return range.contains(played)
        }.count
    }

    private var topTags: [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for artist in topArtistsForPeriod(period).prefix(12) {
            let name = artist.name.lowercased()
            counts[name, default: 0] += max(1, artist.playcount ?? 0)
        }
        return counts
            .map { ($0.key, $0.value) }
            .sorted { $0.1 > $1.1 }
    }

    private var rangeCurrent: DateInterval {
        period.interval(offsetUnits: 0)
    }

    private var rangeComparison: DateInterval {
        period.interval(offsetUnits: 1)
    }

    private var comparisonTitle: String {
        period.previousLabel
    }

    private var periodTitle: String {
        period.currentLabel
    }

    private func topArtistsForPeriod(_ period: ReportPeriod) -> [CompatibilityTopArtist] {
        switch period {
        case .week:
            return scrobbleService.weeklyTopArtists
        case .month:
            return scrobbleService.monthlyTopArtists
        case .year:
            return scrobbleService.yearlyTopArtists
        }
    }

    private func topArtistAggregate(for period: ReportPeriod) -> Int {
        topArtistsForPeriod(period).reduce(0) { $0 + max(0, $1.playcount ?? 0) }
    }

    private var hourlyCountsCurrent: [Int] {
        hourCounts(in: rangeCurrent)
    }

    private var hourlyCountsComparison: [Int] {
        hourCounts(in: rangeComparison)
    }

    private func hourCounts(in range: DateInterval) -> [Int] {
        var bins = Array(repeating: 0, count: 24)
        for item in scrobbleService.latestScrobbles {
            guard let played = item.playedAt, range.contains(played) else { continue }
            let hour = Calendar.current.component(.hour, from: played)
            bins[hour] += 1
        }
        return bins
    }

    private var peakHourLabel: String {
        let counts = hourlyCountsCurrent
        guard let max = counts.max(), max > 0, let idx = counts.firstIndex(of: max) else { return "00:00" }
        return String(format: "%02d:00", idx)
    }

    private var mainstreamScore: Int {
        switch period {
        case .week:
            let weeklyScore = mainstreamScore(from: scrobbleService.weeklyTopArtists)
            if weeklyScore > 0 {
                return weeklyScore
            }
            return mainstreamScore(in: rangeCurrent)
        case .month:
            let monthlyScore = mainstreamScore(from: scrobbleService.monthlyTopArtists)
            if monthlyScore > 0 {
                return monthlyScore
            }
            return mainstreamScore(from: scrobbleService.overallTopArtists)
        case .year:
            let yearlyScore = mainstreamScore(from: scrobbleService.yearlyTopArtists)
            if yearlyScore > 0 {
                return yearlyScore
            }
            return mainstreamScore(from: scrobbleService.overallTopArtists)
        }
    }

    private var mainstreamBaseline: Int {
        let baseline: Int
        switch period {
        case .week:
            baseline = mainstreamScore(from: scrobbleService.overallTopArtists)
        case .month:
            baseline = mainstreamScore(from: scrobbleService.yearlyTopArtists)
        case .year:
            baseline = mainstreamScore(from: scrobbleService.overallTopArtists)
        }
        if baseline > 0 {
            return baseline
        }
        let previous = mainstreamScore(in: rangeComparison)
        return previous > 0 ? previous : max(0, min(100, mainstreamScore - 6))
    }

    private var mainstreamTone: String {
        if mainstreamScore >= 55 { return "more mainstream" }
        if mainstreamScore <= 25 { return "more adventurous" }
        return "balanced"
    }

    private var mainstreamReferenceArtists: Set<String> {
        let global = Set(scrobbleService.globalTopArtistNames.map { $0.lowercased() })
        if !global.isEmpty {
            return global
        }
        return [
            "drake", "taylor swift", "the weeknd", "billie eilish",
            "bad bunny", "dua lipa", "ariana grande", "coldplay",
            "radiohead", "pink floyd"
        ]
    }

    private var mainstreamRankByArtist: [String: Int] {
        var map: [String: Int] = [:]
        for (index, artist) in scrobbleService.globalTopArtistNames.enumerated() {
            map[artist.lowercased()] = index + 1
        }
        return map
    }

    private func mainstreamScore(from artists: [CompatibilityTopArtist]) -> Int {
        let rankedArtists = artists.filter { !$0.name.isEmpty }
        guard !rankedArtists.isEmpty else { return 0 }

        let weighted = rankedArtists.map { (name: $0.name.lowercased(), weight: max(1, $0.playcount ?? 1)) }
        let totalWeight = weighted.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return 0 }

        let rank = mainstreamRankByArtist
        if !rank.isEmpty {
            let maxRank = max(1, rank.count)
            let score = weighted.reduce(0.0) { partial, item in
                let popularity: Double
                if let artistRank = rank[item.name] {
                    popularity = Double(maxRank - artistRank + 1) / Double(maxRank)
                } else {
                    popularity = 0.03
                }
                return partial + Double(item.weight) * popularity
            }
            return Int((score / Double(totalWeight) * 100).rounded())
        }

        let mainstreamWeight = weighted
            .filter { mainstreamReferenceArtists.contains($0.name) }
            .reduce(0) { $0 + $1.weight }
        return Int((Double(mainstreamWeight) / Double(totalWeight) * 100).rounded())
    }

    private func mainstreamScore(in range: DateInterval) -> Int {
        var counts: [String: Int] = [:]
        for item in scrobbleService.latestScrobbles {
            guard let playedAt = item.playedAt, range.contains(playedAt) else { continue }
            counts[item.artist.lowercased(), default: 0] += 1
        }
        guard !counts.isEmpty else { return 0 }

        let rank = mainstreamRankByArtist
        let total = counts.values.reduce(0, +)
        guard total > 0 else { return 0 }
        if !rank.isEmpty {
            let maxRank = max(1, rank.count)
            let weightedScore = counts.reduce(0.0) { partial, entry in
                let popularity: Double
                if let artistRank = rank[entry.key] {
                    popularity = Double(maxRank - artistRank + 1) / Double(maxRank)
                } else {
                    popularity = 0.03
                }
                return partial + Double(entry.value) * popularity
            }
            return Int((weightedScore / Double(total) * 100).rounded())
        }

        let mainstreamHits = counts.reduce(0) { partial, entry in
            mainstreamReferenceArtists.contains(entry.key) ? partial + entry.value : partial
        }
        return Int((Double(mainstreamHits) / Double(total) * 100).rounded())
    }

    private var weekdayTrends: [(day: String, current: Int, previous: Int)] {
        let symbols = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
        var current = Array(repeating: 0, count: 7)
        var previous = Array(repeating: 0, count: 7)
        for item in scrobbleService.latestScrobbles {
            guard let played = item.playedAt else { continue }
            let weekday = Calendar.current.component(.weekday, from: played)
            let idx = (weekday + 5) % 7
            if rangeCurrent.contains(played) {
                current[idx] += 1
            } else if rangeComparison.contains(played) {
                previous[idx] += 1
            }
        }
        return symbols.indices.map { (symbols[$0], current[$0], previous[$0]) }
    }

    private var weekdayMax: Int {
        max(1, weekdayTrends.map { max($0.current, $0.previous) }.max() ?? 1)
    }

    private func reportBarInline(value: Int, max: Int) -> some View {
        let ratio = max > 0 ? Double(value) / Double(max) : 0
        return RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .mask(
                        GeometryReader { geo in
                            Rectangle().frame(width: geo.size.width * ratio)
                        }
                    )
            }
            .frame(height: 10)
    }
}
