import WidgetKit
import SwiftUI

// The home-screen and Lock Screen widget.
// It downloads news.json from GitHub by itself (every few hours, when iOS allows),
// so it doesn't need to share data with the app. This file belongs ONLY to the
// EgyptIndustryWidgetExtension target, not to the app.
//
// Look: same as the app icon. Black background, white text, red accents.

private let feedURL = URL(string:
    "https://raw.githubusercontent.com/omarr-y/egypt-industry-timeline/main/news.json"
)!

/// The red from the app icon's arrow.
private let brandRed = Color(red: 1.0, green: 0.23, blue: 0.19)

// MARK: - Data

struct WidgetItem: Decodable, Identifiable {
    let id: String
    let date: String        // "YYYY-MM-DD"
    let title: String
    let source: String
    let category: String
    var figure: String? = nil

    /// "5 Oct"
    var shortDate: String {
        guard let d = WidgetItem.isoDay.date(from: date) else { return date }
        return WidgetItem.dayMonth.string(from: d)
    }

    /// "INVESTMENT", "PMI", ...
    var categoryLabel: String {
        switch category {
        case "pmi": return "PMI & OUTPUT"
        case "policy": return "POLICY"
        case "investment": return "INVESTMENT"
        case "trade": return "TRADE"
        default: return category.uppercased()
        }
    }

    /// The key number, if the item has one ("47.2", "$6.1bn", ...).
    var keyFigure: String? {
        guard let f = figure?.trimmingCharacters(in: .whitespaces), !f.isEmpty else { return nil }
        return f
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
                   source: "The Middle East Observer", category: "investment", figure: "50 products"),
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

    /// Newest first, at most 5 (the most the large widget shows).
    private static func sorted(_ data: Data) -> [WidgetItem] {
        guard let feed = try? JSONDecoder().decode(WidgetFeed.self, from: data) else { return [] }
        return Array(feed.items.sorted { ($0.date, $0.id) > ($1.date, $1.id) }.prefix(5))
    }
}

// MARK: - Views

struct LatestNewsView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NewsEntry

    var body: some View {
        Group {
            if entry.items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Header(date: nil)
                    Text("Open the app once to load the news.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer(minLength: 0)
                }
            } else {
                switch family {
                case .systemSmall:
                    SmallView(item: entry.items[0])
                case .accessoryRectangular:
                    LockScreenView(item: entry.items[0])
                case .systemLarge:
                    ListView(items: Array(entry.items.prefix(5)))
                default:
                    ListView(items: Array(entry.items.prefix(2)))
                }
            }
        }
        .containerBackground(for: .widget) {
            Color.black
        }
    }
}

/// Small square: the latest item, with its key number large if it has one.
private struct SmallView: View {
    let item: WidgetItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Header(date: item.shortDate)
            Spacer(minLength: 6)
            if let figure = item.keyFigure {
                Text(figure)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(brandRed)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.bottom, 2)
            }
            Text(item.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(item.keyFigure == nil ? 4 : 3)
            Spacer(minLength: 6)
            Text(item.categoryLabel)
                .font(.system(size: 9, weight: .bold))
                .kerning(0.8)
                .foregroundStyle(brandRed)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Medium (2 items) and large (5 items).
private struct ListView: View {
    let items: [WidgetItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Header(date: items.first?.shortDate)
                .padding(.bottom, 10)
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Rectangle()
                        .fill(.white.opacity(0.12))
                        .frame(height: 0.5)
                        .padding(.vertical, 8)
                }
                Row(item: item)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct Row: View {
    let item: WidgetItem

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(item.categoryLabel)
                    .foregroundStyle(brandRed)
                Text(item.shortDate)
                    .foregroundStyle(.white.opacity(0.5))
                if let figure = item.keyFigure {
                    Spacer(minLength: 4)
                    Text(figure)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }
            .font(.system(size: 9, weight: .bold))
            .kerning(0.6)

            Text(item.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Lock Screen: the latest headline. iOS tints this one itself.
private struct LockScreenView: View {
    let item: WidgetItem

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(item.categoryLabel) · \(item.shortDate)")
                .font(.system(size: 10, weight: .bold))
            Text(item.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Small pyramid mark + name, like the app icon.
private struct Header: View {
    let date: String?

    var body: some View {
        HStack(spacing: 5) {
            PyramidMark()
                .fill(.white)
                .frame(width: 11, height: 9)
            Text("EGYPT INDUSTRY")
                .font(.system(size: 9, weight: .heavy))
                .kerning(1)
                .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
    }
}

private struct PyramidMark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
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
