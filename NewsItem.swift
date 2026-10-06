import SwiftUI

/// The whole news.json file: { "updated": "...", "count": 143, "items": [ ... ] }
struct NewsFeed: Codable {
    let updated: String
    let items: [NewsItem]
}

/// One timeline entry. Field names match news.json exactly.
struct NewsItem: Codable, Identifiable, Hashable {
    let id: String
    let date: String          // "YYYY-MM-DD"
    let title: String
    let summary: String
    let figure: String        // may be ""
    let category: String      // "pmi" | "policy" | "investment" | "trade"
    let sectors: [String]
    let source: String
    let url: String
    let addedAt: String?

    var kind: NewsCategory { NewsCategory(rawValue: category) ?? .other }

    var parsedDate: Date? { NewsItem.isoDay.date(from: date) }

    /// "5 Oct 2026"
    var displayDate: String {
        guard let d = parsedDate else { return date }
        return NewsItem.shortDay.string(from: d)
    }

    /// "October 2026", used for the section headers in the list.
    var monthKey: String {
        guard let d = parsedDate else { return String(date.prefix(7)) }
        return NewsItem.monthYear.string(from: d)
    }

    var link: URL? { URL(string: url) }

    private static let isoDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let shortDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    private static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "MMMM yyyy"
        return f
    }()
}

/// The four categories, with a label, icon and colour for each.
enum NewsCategory: String, CaseIterable, Identifiable {
    case pmi, policy, investment, trade, other

    var id: String { rawValue }

    static var filterable: [NewsCategory] { [.pmi, .policy, .investment, .trade] }

    var label: String {
        switch self {
        case .pmi: return "PMI & output"
        case .policy: return "Policy"
        case .investment: return "Investment"
        case .trade: return "Trade"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .pmi: return "chart.line.uptrend.xyaxis"
        case .policy: return "building.columns"
        case .investment: return "building.2"
        case .trade: return "shippingbox"
        case .other: return "circle"
        }
    }

    var color: Color {
        switch self {
        case .pmi: return .blue
        case .policy: return .purple
        case .investment: return .green
        case .trade: return .orange
        case .other: return .gray
        }
    }
}
