import SwiftUI

@main
struct EgyptIndustryApp: App {
    @StateObject private var store = NewsStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
