import Foundation
import WidgetKit

/// Loads the timeline and keeps it up to date.
///
/// Order of sources:
/// 1. The last copy downloaded from GitHub (saved on the phone), so the app opens instantly and works offline.
/// 2. If there is no saved copy yet, the news.json bundled inside the app.
/// 3. Then it downloads the latest news.json from GitHub and saves it for next time.
///
/// It also remembers, on the phone, which items you starred and which ones are new to you.
/// The downloading and "new" bookkeeping live in NewsSync (BackgroundRefresh.swift),
/// so the background refresh can use them too.
@MainActor
final class NewsStore: ObservableObject {
    @Published private(set) var items: [NewsItem] = []
    @Published private(set) var updated: String = ""
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    /// Items you starred. Saved on the phone, so they survive restarts.
    @Published private(set) var starredIDs: Set<String> = [] {
        didSet { defaults.set(Array(starredIDs), forKey: NewsSync.Keys.starred) }
    }

    /// Items that arrived since you last saw the timeline and that you haven't opened yet.
    /// The same number appears as the red badge on the app icon.
    @Published private(set) var unreadIDs: Set<String> = [] {
        didSet {
            defaults.set(Array(unreadIDs), forKey: NewsSync.Keys.unread)
            NewsSync.setBadge(unreadIDs.count)
        }
    }

    private let defaults = UserDefaults.standard

    init() {
        reloadSaved()
    }

    /// Re-reads stars, "New" badges and the saved news.json from the phone.
    /// Called at launch and whenever the app comes back to the screen,
    /// because a background refresh may have updated them in the meantime.
    func reloadSaved() {
        starredIDs = Set(defaults.stringArray(forKey: NewsSync.Keys.starred) ?? [])
        unreadIDs = Set(defaults.stringArray(forKey: NewsSync.Keys.unread) ?? [])
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

    // MARK: - Loading

    /// Read the saved copy, or the bundled one if nothing is saved yet.
    private func loadLocal() {
        if let data = try? Data(contentsOf: NewsSync.cacheFile), apply(data) { return }
        if let bundled = Bundle.main.url(forResource: "news", withExtension: "json"),
           let data = try? Data(contentsOf: bundled) {
            _ = apply(data)
        }
    }

    /// Download the latest file from GitHub. Called on launch, when the app
    /// comes back to the screen, and on pull-to-refresh.
    func refresh() async {
        guard !isLoading else { return }   // launch and "back on screen" can both ask at once
        isLoading = true
        defer { isLoading = false }
        do {
            let data = try await NewsSync.download()
            if apply(data) {
                try? data.write(to: NewsSync.cacheFile, options: .atomic)
                errorMessage = nil
                WidgetCenter.shared.reloadAllTimelines()
            } else {
                errorMessage = "The downloaded file couldn't be read. Showing the saved copy."
            }
        } catch let error as URLError where error.code == .badServerResponse {
            errorMessage = "Couldn't reach GitHub. Showing the saved copy."
        } catch {
            errorMessage = "You're offline. Showing the saved copy."
        }
    }

    /// Decode a news.json file and publish it. Returns false if the file is not valid.
    /// A single broken item is skipped (see NewsFeed), so it can't hide the rest of an update.
    private func apply(_ data: Data) -> Bool {
        guard let feed = NewsSync.decode(data) else { return false }
        items = feed.items.sorted { ($0.date, $0.id) > ($1.date, $1.id) }
        updated = feed.updated
        NewsSync.registerItems(feed.items)
        unreadIDs = Set(defaults.stringArray(forKey: NewsSync.Keys.unread) ?? [])
        return true
    }
}
