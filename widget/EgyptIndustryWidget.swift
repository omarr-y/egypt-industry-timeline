import WidgetKit
import SwiftUI

// The home-screen and Lock Screen widget.
// It downloads news.json from GitHub by itself (every few hours, when iOS allows),
// so it doesn't need to share data with the app. This file belongs ONLY to the
// EgyptIndustryWidgetExtension target, not to the app.

private let feedURL = URL(string:
    "https://raw.githubusercontent.com/omarr-y/egypt-industry-timeline/main/news.json"
)!

// MARK: - Data

struct WidgetItem: Decodable, Identifiable {
    let id: String
    let date: String        // "YYYY-MM-DD"
    let title: String
    let source: String
    let category: String

    /// "5 Oct"
    var shortDate: String {
        guard let d = WidgetItem.isoDay.date(from: date) else { return date }
        return WidgetItem.dayMonth.string(from: d)
    }

    var color: Color {
        switch category {
        case "pmi": return .blue
        case "policy": return .purple
        case "investment": return .green
        case "trade": return .orange
        default: return .gray
        }
    }

    private static let isoDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let dayMonth: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "d MMM"
        return f
    }()

    /// Real items from the 6 Oct 2026 file, shown in the widget gallery before any download.
    static let samples = [
        WidgetItem(id: "n-b1252cd96927", date: "2026-10-05",
                   title: "ElAraby and South Africa's Malben team up on auto components",
                   source: "Daily News Egypt", category: "investment"),
        WidgetItem(id: "n-77b7a3870c68", date: "2026-10-05",
                   title: "ECES study identifies 50 industrial products for European investment",
                   source: "The Middle East Observer", category: "investment"),
        WidgetItem(id: "n-09d8de08bedf", date: "2026-10-05",
                   title: "Steelmakers and rolling mills push to scrap billet duties",
                   source: "Enterprise", category: "policy"),
    ]
}

/// news.json, keeping only the fields the widget shows. Items that can't be read are skipped.
private struct WidgetFeed: Decodable {
    let items: [WidgetItem]

    private enum CodingKeys: String, CodingKey { case items }
    private struct Lenient: Decodable {
        let item: WidgetItem?
        init(from decoder: Decoder) throws { item = try? WidgetItem(from: decoder) }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = try c.decode([Lenient].self, forKey: .items).compactMap(\.item)
    }
}

// MARK: - Timeline

struct NewsEntry: TimelineEntry {
    let date: Date
    let items: [WidgetItem]
}

struct Provider: TimelineProvider {
    /// The widget keeps its own saved copy, so it still shows something when offline.
    private static let cacheFile = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("widget-news.json")

    func placeholder(in context: Context) -> NewsEntry {
        NewsEntry(date: .now, items: WidgetItem.samples)
    }

    func getSnapshot(in context: Context, completion: @escaping (NewsEntry) -> Void) {
        let saved = Self.readSaved()
        completion(NewsEntry(date: .now, items: saved.isEmpty ? WidgetItem.samples : saved))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NewsEntry>) -> Void) {
        Task {
            let items = await Self.loadLatest()
            let entry = NewsEntry(date: .now, items: items)
            // Ask iOS to refresh again in about 3 hours.
            let next = Date.now.addingTimeInterval(3 * 3600)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    /// Download the latest items; fall back to the saved copy if that fails.
    private static func loadLatest() async -> [WidgetItem] {
        var request = URLRequest(url: feedURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        if let result = try? await URLSession.shared.data(for: request),
           (result.1 as? HTTPURLResponse)?.statusCode == 200 {
            let items = sorted(result.0)
            if !items.isEmpty {
                try? result.0.write(to: cacheFile, options: .atomic)
                return items
            }
        }
        return readSaved()
    }

    private static func readSaved() -> [WidgetItem] {
        guard let data = try? Data(contentsOf: cacheFile) else { return [] }
        return sorted(data)
    }

    /// Newest first, at most 6 (the most the large widget shows).
    private static func sorted(_ data: Data) -> [WidgetItem] {
        guard let feed = try? JSONDecoder().decode(WidgetFeed.self, from: data) else { return [] }
        return Array(feed.items.sorted { ($0.date, $0.id) > ($1.date, $1.id) }.prefix(6))
    }
}

// MARK: - Views

struct LatestNewsView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NewsEntry

    var body: some View {
        Group {
            if entry.items.isEmpty {
                Text("Open Egypt Industry once to load the news.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                switch family {
                case .systemSmall:
                    SmallView(item: entry.items[0])
                case .accessoryRectangular:
                    LockScreenView(item: entry.items[0])
                case .systemLarge:
                    ListView(items: Array(entry.items.prefix(6)))
                default:
                    ListView(items: Array(entry.items.prefix(3)))
                }
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

/// Small square: the single latest item.
private struct SmallView: View {
    let item: WidgetItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Header()
            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(4)
            Spacer(minLength: 0)
            Text("\(item.shortDate) · \(item.source)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Medium and large: a short list.
private struct ListView: View {
    let items: [WidgetItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Header()
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 7, height: 7)
                        .padding(.top, 5)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(2)
                        Text("\(item.shortDate) · \(item.source)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Lock Screen: the latest headline.
private struct LockScreenView: View {
    let item: WidgetItem

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Egypt Industry · \(item.shortDate)")
                .font(.caption2.weight(.semibold))
            Text(item.title)
                .font(.caption)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct Header: View {
    var body: some View {
        Label("Egypt Industry", systemImage: "building.2")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.teal)
    }
}

// MARK: - Widget setup

struct LatestNewsWidget: Widget {
    let kind = "LatestNewsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LatestNewsView(entry: entry)
        }
        .configurationDisplayName("Latest industry news")
        .description("The newest items from your Egypt Industry Timeline.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

@main
struct EgyptIndustryWidgetBundle: WidgetBundle {
    var body: some Widget {
        LatestNewsWidget()
    }
}
