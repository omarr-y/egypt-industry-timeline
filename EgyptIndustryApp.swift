import SwiftUI

@main
struct EgyptIndustryApp: App {
    @StateObject private var store = NewsStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // Back on screen: pick up anything the background check found, then fetch.
                store.reloadSaved()
                Task { await store.refresh() }
            case .background:
                // Leaving the screen: ask iOS to check for news in a few hours.
                NewsSync.scheduleRefresh()
            default:
                break
            }
        }
        .backgroundTask(.appRefresh(NewsSync.refreshTaskID)) {
            await NewsSync.backgroundCheck()
        }
    }
}
