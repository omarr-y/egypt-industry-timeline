import Foundation

/// Loads the timeline and keeps it up to date.
///
/// Order of sources:
/// 1. The last copy downloaded from GitHub (saved on the phone), so the app opens instantly and works offline.
/// 2. If there is no saved copy yet, the news.json bundled inside the app.
/// 3. Then it downloads the latest news.json from GitHub and saves it for next time.
@MainActor
final class NewsStore: ObservableObject {
    @Published private(set) var items: [NewsItem] = []
    @Published private(set) var updated: String = ""
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let cacheFile: URL = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("news.json")

    init() {
        loadLocal()
    }

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
    private func apply(_ data: Data) -> Bool {
        guard let feed = try? JSONDecoder().decode(NewsFeed.self, from: data) else { return false }
        items = feed.items.sorted { $0.date > $1.date }
        updated = feed.updated
        return true
    }
}
