import Foundation

/// Where the app downloads the timeline from (your GitHub repository).
/// If you ever move the data to another account, change "omarr-y" below.
enum AppConfig {
    static let dataURL = URL(string:
        "https://raw.githubusercontent.com/omarr-y/egypt-industry-timeline/main/news.json"
    )!
}
