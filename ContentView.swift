import SwiftUI

/// Main screen: the timeline, newest first, grouped by month,
/// with category chips, search and pull-to-refresh.
struct ContentView: View {
    @EnvironmentObject private var store: NewsStore
    @State private var selected: NewsCategory? = nil   // nil = all categories
    @State private var searchText = ""

    /// Items after the category filter and the search box are applied.
    private var filtered: [NewsItem] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return store.items.filter { item in
            matchesCategory(item) && matchesSearch(item, query: query)
        }
    }

    private func matchesCategory(_ item: NewsItem) -> Bool {
        guard let selected else { return true }
        return item.kind == selected
    }

    private func matchesSearch(_ item: NewsItem, query: String) -> Bool {
        if query.isEmpty { return true }
        if item.title.lowercased().contains(query) { return true }
        if item.summary.lowercased().contains(query) { return true }
        if item.source.lowercased().contains(query) { return true }
        return item.sectors.contains { $0.lowercased().contains(query) }
    }

    /// Groups the filtered items into months, keeping newest-first order.
    private var sections: [MonthSection] {
        var result: [MonthSection] = []
        for item in filtered {
            if let last = result.indices.last, result[last].month == item.monthKey {
                result[last].items.append(item)
            } else {
                result.append(MonthSection(month: item.monthKey, items: [item]))
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    CategoryChips(selected: $selected, counts: counts)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                if let message = store.errorMessage {
                    Label(message, systemImage: "wifi.exclamationmark")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if filtered.isEmpty {
                    Text(store.items.isEmpty ? "No data yet. Pull down to refresh." : "No matching items.")
                        .foregroundStyle(.secondary)
                }

                ForEach(sections) { section in
                    Section(section.month) {
                        ForEach(section.items) { item in
                            NavigationLink(value: item) {
                                NewsRow(item: item)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Egypt Industry")
            .navigationDestination(for: NewsItem.self) { item in
                NewsDetailView(item: item)
            }
            .searchable(text: $searchText, prompt: "Search titles, sectors, sources")
            .refreshable { await store.refresh() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if store.isLoading {
                        ProgressView()
                    } else if !store.updated.isEmpty {
                        Text("Updated \(store.updated)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .task { await store.refresh() }
        }
    }

    /// How many items each category has in total, shown on the chips.
    private var counts: [NewsCategory: Int] {
        var c: [NewsCategory: Int] = [:]
        for item in store.items { c[item.kind, default: 0] += 1 }
        return c
    }
}

/// A month heading and the items under it.
struct MonthSection: Identifiable {
    let month: String
    var items: [NewsItem]
    var id: String { month }
}

/// One line in the list.
struct NewsRow: View {
    let item: NewsItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.kind.icon)
                .font(.subheadline)
                .foregroundStyle(item.kind.color)
                .frame(width: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Text(item.displayDate)
                    Text("·")
                    Text(item.source)
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if !item.figure.isEmpty {
                    Text(item.figure)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(item.kind.color)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// Horizontal row of filter buttons: All, PMI, Policy, Investment, Trade.
struct CategoryChips: View {
    @Binding var selected: NewsCategory?
    let counts: [NewsCategory: Int]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All", color: .primary, isOn: selected == nil) {
                    selected = nil
                }
                ForEach(NewsCategory.filterable) { cat in
                    chip(title: "\(cat.label) \(counts[cat] ?? 0)",
                         color: cat.color,
                         isOn: selected == cat) {
                        selected = (selected == cat) ? nil : cat
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    private func chip(title: String, color: Color, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isOn ? color.opacity(0.18) : Color(.secondarySystemBackground),
                            in: Capsule())
                .overlay(Capsule().stroke(isOn ? color : .clear, lineWidth: 1))
                .foregroundStyle(isOn ? color : .primary)
        }
        .buttonStyle(.plain)
    }
}
