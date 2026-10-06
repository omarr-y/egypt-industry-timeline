import SwiftUI

/// The app's main screen: three tabs along the bottom.
struct ContentView: View {
    @EnvironmentObject private var store: NewsStore

    var body: some View {
        TabView {
            TimelineView()
                .tabItem { Label("Timeline", systemImage: "list.bullet.rectangle") }
                .badge(store.unreadIDs.count)   // 0 hides the badge

            StarredView()
                .tabItem { Label("Starred", systemImage: "star") }

            ChartsView()
                .tabItem { Label("Charts", systemImage: "chart.bar.xaxis") }
        }
        .task {
            await store.refresh()
            await NewsSync.requestNotificationPermission()
        }
    }
}
