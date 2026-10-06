import Foundation
import BackgroundTasks
import UserNotifications
import WidgetKit

/// Work shared by the app and its background refresh: downloading news.json,
/// the saved copy on the phone, remembering which items are new, and notifications.
enum NewsSync {
    /// Must match the entry under "Permitted background task scheduler identifiers"
    /// in the app target's Info tab.
    static let refreshTaskID = "com.omar.EgyptIndustry.refresh"

    enum Keys {
        static let starred = "starredIDs"
        static let unread = "unreadIDs"
        static let known = "knownIDs"    // every item id the app has ever seen
    }

    static let cacheFile: URL = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("news.json")

    // MARK: - Downloading

    /// Downloads news.json from GitHub. Throws if offline or if GitHub doesn't answer normally.
    static func download() async throws -> Data {
        var request = URLRequest(url: AppConfig.dataURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    /// Reads a news.json file. Returns nil if it isn't valid or has no items.
    static func decode(_ data: Data) -> NewsFeed? {
        guard let feed = try? JSONDecoder().decode(NewsFeed.self, from: data),
              !feed.items.isEmpty else { return nil }
        return feed
    }

    // MARK: - Which items are new

    /// Records the items the app has now seen. Items never seen before are added to the
    /// "New" list and returned. On the very first run nothing counts as new,
    /// otherwise all 143 items would be "new".
    @discardableResult
    static func registerItems(_ items: [NewsItem]) -> [NewsItem] {
        let defaults = UserDefaults.standard
        let ids = Set(items.map(\.id))
        guard let known = defaults.stringArray(forKey: Keys.known) else {
            defaults.set(Array(ids), forKey: Keys.known)
            return []
        }
        let knownSet = Set(known)
        let fresh = items.filter { !knownSet.contains($0.id) }

        var unread = Set(defaults.stringArray(forKey: Keys.unread) ?? [])
        unread.formUnion(fresh.map(\.id))
        unread.formIntersection(ids)    // forget items that are no longer in the file
        defaults.set(Array(unread), forKey: Keys.unread)
        defaults.set(Array(knownSet.union(ids)), forKey: Keys.known)
        return fresh
    }

    // MARK: - Background refresh

    /// Asks iOS to wake the app in a few hours to check for news.
    /// iOS decides the exact time, based on how often you use the app.
    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Runs while the app is in the background: download, save, notify about new items.
    static func backgroundCheck() async {
        scheduleRefresh()   // book the next check first, in case this one is cut short
        guard let data = try? await download(), let feed = decode(data) else { return }
        try? data.write(to: cacheFile, options: .atomic)
        let fresh = registerItems(feed.items)
        WidgetCenter.shared.reloadAllTimelines()
        if !fresh.isEmpty {
            await notify(about: fresh)
        }
    }

    // MARK: - Notifications

    /// Shows the "Allow notifications?" question. iOS only ever asks once.
    static func requestNotificationPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Sets the red number on the app icon.
    static func setBadge(_ count: Int) {
        Task { try? await UNUserNotificationCenter.current().setBadgeCount(count) }
    }

    private static func notify(about fresh: [NewsItem]) async {
        let items = fresh.sorted { $0.date > $1.date }
        let content = UNMutableNotificationContent()
        if items.count == 1, let item = items.first {
            content.title = item.title
            content.body = item.summary
        } else {
            content.title = "\(items.count) new items in Egypt Industry"
            content.body = items.prefix(3).map { "• \($0.title)" }.joined(separator: "\n")
        }
        content.sound = .default
        let unread = UserDefaults.standard.stringArray(forKey: Keys.unread)?.count ?? items.count
        content.badge = NSNumber(value: unread)

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
