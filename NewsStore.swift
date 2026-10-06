import Foundation

/// Loads the timeline and keeps it up to date.
///
/// Order of sources:
/// 1. The last copy downloaded from GitHub (saved on the phone), so the app opens instantly and works offline.
/// 2. If there is no saved copy yet, the news.json bundled inside the app.
/// 3. Then it downloads the latest news.json from GitHub and saves it for next time.
///
/// It also remembers, on the phone, which items you starred and which ones are new to you.
@MainActor
final class NewsStore: ObservableObject {
    @Published private(set) var items: [NewsItem] = []
    @Published private(set) var updated: String = ""
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    /// Items you starred. Saved on the phone, so they survive restarts.
    @Published private(set) var starredIDs: Set<String> = [] {
        didSet { defaults.set(Array(starredIDs), forKey: Keys.starred) }
    }

    /// Items that arrived since you last saw the timeline and that you haven't opened yet.
    @Published private(set) var unreadIDs: Set<String> = [] {
        didSet { defaults.set(Array(unreadIDs), forKey: Keys.unread) }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let starred = "starredIDs"
        static let unread = "unreadIDs"
        static let known = "knownIDs"    // every item id the app has ever shown
    }

    private let cacheFile: URL = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("news.json")

    init() {
        starredIDs = Set(defaults.stringArray(forKey: Keys.starred) ?? [])
        unreadIDs = Set(defaults.stringArray(forKey: Keys.unread) ?? [])
        loadLocal()
    }

    // MARK: - Stars and "New"

    func isStarred(_ item: NewsItem) -> Bool { starredIDs.contains(item.id) }

    func isNew(_ item: NewsItem) -> Bool { unreadIDs.contains(item.id) }

    func toggleStar(_ item: NewsItem) {
        if starredIDs.contains(item.id) {
            starredIDs.remove(item.id)
        } else {
            starredIDs.insert(item.id)
        }
    }

    /// Called when you open an item, so its "New" badge goes away.
    func markRead(_ item: NewsItem) {
        if unreadIDs.contains(item.id) { unreadIDs.remove(item.id) }
    }

    func markAllRead() {
        unreadIDs = []
    }

    /// Any item the app hasn't shown before is marked as new.
    /// On the very first launch nothing is marked, otherwise all 143 items would be "new".
    private func trackNewItems() {
        let ids = Set(items.map(\.id))
        if let known = defaults.stringArray(forKey: Keys.known) {
            let fresh = ids.subtracting(known)
            if !fresh.isEmpty { unreadIDs.formUnion(fresh) }
            defaults.set(Array(ids.union(known)), forKey: Keys.known)
        } else {
            defaults.set(Array(ids), forKey: Keys.known)
        }
        // Forget badges for items that are no longer in the file.
        if !unreadIDs.isSubset(of: ids) { unreadIDs.formIntersection(ids) }
    }

    // MARK: - Loading

    /// Read the saved copy, or the bundled one if nothing is saved yet.
    private func loadLocal() {
        if let data = try? Data(contentsOf: cacheFile), apply(data) { return }
        if let bundled = Bundle.main.url(forResource: "news", withExtension: "json"),
           let data = try? Data(contentsOf: bundled) {
            _ = apply(data)
        }
    }

    /// Download the latest file from GitHub. Called on launch and on pull-to-refresh.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            var request = URLRequest(url: AppConfig.dataURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                errorMessage = "Couldn't reach GitHub. Showing the saved copy."
                return
            }
            if apply(data) {
                try? data.write(to: cacheFile, options: .atomic)
                errorMessage = nil
            } else {
                errorMessage = "The downloaded file couldn't be read. Showing the saved copy."
            }
        } catch {
            errorMessage = "You're offline. Showing the saved copy."
        }
    }

    /// Decode a news.json file and publish it. Returns false if the file is not valid.
    /// A single broken item is skipped (see NewsFeed), so it can't hide the rest of an update.
    private func apply(_ data: Data) -> Bool {
        guard let feed = try? JSONDecoder().decode(NewsFeed.self, from: data),
              !feed.items.isEmpty else { return false }
        items = feed.items.sorted { ($0.date, $0.id) > ($1.date, $1.id) }
        updated = feed.updated
        trackNewItems()
        return true
    }
}
