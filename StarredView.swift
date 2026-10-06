import SwiftUI

/// The Starred tab: items you've kept for a briefing note,
/// with a button to share them all as text.
struct StarredView: View {
    @EnvironmentObject private var store: NewsStore

    private var starred: [NewsItem] {
        store.items.filter { store.isStarred($0) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if starred.isEmpty {
                    ContentUnavailableView(
                        "No starred items",
                        systemImage: "star",
                        description: Text("Tap the star on an item, or swipe left on it in the timeline, to keep it here for your notes.")
                    )
                } else {
                    List {
                        ForEach(starred) { item in
                            NavigationLink(value: item) {
                                NewsRow(item: item, isNew: store.isNew(item))
                            }
                        }
                        .onDelete { offsets in
                            let items = starred
                            for i in offsets { store.toggleStar(items[i]) }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Starred")
            .navigationDestination(for: NewsItem.self) { item in
                NewsDetailView(item: item)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: citationText) {
                        Label("Share all", systemImage: "square.and.arrow.up")
                    }
                    .disabled(starred.isEmpty)
                }
            }
        }
    }

    /// All starred items as plain text, ready to paste into a note or email.
    private var citationText: String {
        starred.map { item in
            var lines = ["• \(item.title) (\(item.source), \(item.displayDate))"]
            if !item.figure.isEmpty { lines.append("  Key figure: \(item.figure)") }
            lines.append("  \(item.summary)")
            lines.append("  \(item.url)")
            return lines.joined(separator: "\n")
        }
        .joined(separator: "\n\n")
    }
}
