import SwiftUI
import Charts

/// The Charts tab: items per month by category, which categories are picking up,
/// and the sectors mentioned most often.
struct ChartsView: View {
    @EnvironmentObject private var store: NewsStore
    @State private var monthsShown = 12

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Period", selection: $monthsShown) {
                        Text("6 months").tag(6)
                        Text("12 months").tag(12)
                    }
                    .pickerStyle(.segmented)
                    monthlyChart
                } header: {
                    Text("Items per month")
                } footer: {
                    Text("The latest month is still in progress, so its bar is incomplete.")
                }

                Section {
                    ForEach(momentum) { row in
                        MomentumRow(row: row)
                    }
                } header: {
                    Text("Last 90 days vs the 90 days before")
                }

                Section {
                    sectorChart
                } header: {
                    Text("Most-mentioned sectors (\(monthsShown) months)")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Charts")
        }
    }

    // MARK: - Charts

    private var monthlyChart: some View {
        let labelStyle: Date.FormatStyle.Symbol.Month = monthsShown > 6 ? .narrow : .abbreviated
        return Chart(monthCounts) { row in
            BarMark(x: .value("Month", row.month, unit: .month),
                    y: .value("Items", row.count))
                .foregroundStyle(by: .value("Category", row.category.label))
        }
        .chartForegroundStyleScale(domain: NewsCategory.filterable.map(\.label),
                                   range: NewsCategory.filterable.map(\.color))
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(labelStyle), centered: true)
            }
        }
        .chartLegend(position: .bottom)
        .frame(height: 240)
        .padding(.vertical, 8)
    }

    private var sectorChart: some View {
        Chart(topSectors) { sector in
            BarMark(x: .value("Items", sector.count),
                    y: .value("Sector", sector.name))
                .foregroundStyle(Color.teal)
                .annotation(position: .trailing) {
                    Text("\(sector.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
        }
        .chartXAxis(.hidden)
        .frame(height: CGFloat(max(topSectors.count, 1)) * 30)
        .padding(.vertical, 8)
    }

    // MARK: - Data for the charts

    /// Dates in news.json are whole days, read as UTC, so months are counted in UTC too.
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private var latestDate: Date? {
        store.items.compactMap(\.parsedDate).max()
    }

    /// The first day of each month shown, oldest first, ending with the latest month in the data.
    private var months: [Date] {
        guard let latest = latestDate,
              let lastMonth = calendar.dateInterval(of: .month, for: latest)?.start else { return [] }
        return (0..<monthsShown).reversed().compactMap {
            calendar.date(byAdding: .month, value: -$0, to: lastMonth)
        }
    }

    /// Items that fall inside the months shown.
    private var itemsInRange: [NewsItem] {
        guard let first = months.first else { return [] }
        return store.items.filter { ($0.parsedDate ?? .distantPast) >= first }
    }

    /// One bar segment per month and category (zero where there were no items).
    private var monthCounts: [MonthCount] {
        var counts: [Date: [NewsCategory: Int]] = [:]
        for item in itemsInRange {
            guard let d = item.parsedDate,
                  let month = calendar.dateInterval(of: .month, for: d)?.start else { continue }
            counts[month, default: [:]][item.kind, default: 0] += 1
        }
        return months.flatMap { month in
            NewsCategory.filterable.map { cat in
                MonthCount(month: month, category: cat, count: counts[month]?[cat] ?? 0)
            }
        }
    }

    /// Items per category in the last 90 days, compared with the 90 days before.
    private var momentum: [Momentum] {
        guard let latest = latestDate,
              let recentStart = calendar.date(byAdding: .day, value: -90, to: latest),
              let earlierStart = calendar.date(byAdding: .day, value: -180, to: latest) else { return [] }
        var recent: [NewsCategory: Int] = [:]
        var earlier: [NewsCategory: Int] = [:]
        for item in store.items {
            guard let d = item.parsedDate else { continue }
            if d > recentStart && d <= latest {
                recent[item.kind, default: 0] += 1
            } else if d > earlierStart && d <= recentStart {
                earlier[item.kind, default: 0] += 1
            }
        }
        return NewsCategory.filterable.map {
            Momentum(category: $0, recent: recent[$0] ?? 0, earlier: earlier[$0] ?? 0)
        }
    }

    /// The 8 sectors mentioned most often in the months shown.
    private var topSectors: [SectorCount] {
        var counts: [String: Int] = [:]
        for item in itemsInRange {
            for sector in item.sectors { counts[sector, default: 0] += 1 }
        }
        return counts
            .map { SectorCount(name: $0.key, count: $0.value) }
            .sorted { ($0.count, $1.name) > ($1.count, $0.name) }
            .prefix(8)
            .map { $0 }
    }
}

// MARK: - Small data types

struct MonthCount: Identifiable {
    let month: Date
    let category: NewsCategory
    let count: Int
    var id: String { "\(month.timeIntervalSince1970)-\(category.rawValue)" }
}

struct Momentum: Identifiable {
    let category: NewsCategory
    let recent: Int
    let earlier: Int
    var id: String { category.rawValue }
}

struct SectorCount: Identifiable {
    let name: String
    let count: Int
    var id: String { name }
}

/// One line of the "last 90 days" table, e.g. "Policy   9 → 14   +5".
struct MomentumRow: View {
    let row: Momentum

    private var change: Int { row.recent - row.earlier }

    private var changeText: String { change > 0 ? "+\(change)" : "\(change)" }

    private var changeColor: Color {
        if change > 0 { return .green }
        if change < 0 { return .red }
        return .secondary
    }

    var body: some View {
        HStack {
            Label(row.category.label, systemImage: row.category.icon)
                .foregroundStyle(row.category.color)
            Spacer()
            Text("\(row.earlier) → \(row.recent)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Text(changeText)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(changeColor)
                .frame(minWidth: 40, alignment: .trailing)
        }
    }
}
