import SwiftUI

/// The Timeline tab: newest first, grouped by month,
/// with filter chips, search and pull-to-refresh.
struct TimelineView: View {
    @EnvironmentObject private var store: NewsStore
    @State private var selected: NewsCategory? = nil   // nil = all categories
    @State private var onlyNew = false
    @State private var searchText = ""

    /// Items after the chip filter and the search box are applied.
    private var filtered: [NewsItem] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return store.items.filter { item in
            matchesFilter(item) && matchesSearch(item, query: query)
        }
    }

    private func matchesFilter(_ item: NewsItem) -> Bool {
        if onlyNew { return store.isNew(item) }
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
                    FilterChips(selected: $selected, onlyNew: $onlyNew,
                                counts: counts, newCount: store.unreadIDs.count)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } footer: {
                    if !store.updated.isEmpty {
                        Text("\(store.items.count) items · data updated \(store.updated)")
                    }
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
                                NewsRow(item: item,
                                        isNew: store.isNew(item),
                                        isStarred: store.isStarred(item))
                            }
                            .swipeActions(edge: .trailing) {
                                StarButton(item: item)
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
                    } else if !store.unreadIDs.isEmpty {
                        Button("Mark all read") { store.markAllRead() }
                    }
                }
            }
            .onChange(of: store.unreadIDs.isEmpty) {
                // Nothing new left: drop the "New" filter so the list isn't empty.
                if store.unreadIDs.isEmpty { onlyNew = false }
            }
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

/// One line in a list. Used by the Timeline and Starred tabs.
struct NewsRow: View {
    let item: NewsItem
    var isNew = false
    var isStarred = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.kind.icon)
                .font(.subheadline)
                .foregroundStyle(item.kind.color)
                .frame(width: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(isNew ? .bold : .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    if isNew {
                        Text("NEW")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.blue, in: Capsule())
                    }
                    Text(item.displayDate)
                    Text("·")
                    Text(item.source)
                        .lineLimit(1)
                    if isStarred {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                    }
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

/// Swipe-left button that stars or unstars an item.
struct StarButton: View {
    @EnvironmentObject private var store: NewsStore
    let item: NewsItem

    var body: some View {
        let starred = store.isStarred(item)
        Button {
            store.toggleStar(item)
        } label: {
            Label(starred ? "Unstar" : "Star", systemImage: starred ? "star.slash" : "star")
        }
        .tint(.yellow)
    }
}

/// Horizontal row of filter buttons: All, New, PMI, Policy, Investment, Trade.
struct FilterChips: View {
    @Binding var selected: NewsCategory?
    @Binding var onlyNew: Bool
    let counts: [NewsCategory: Int]
    let newCount: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All", color: .primary, isOn: selected == nil && !onlyNew) {
                    selected = nil
                    onlyNew = false
                }
                if newCount > 0 {
                    chip(title: "New \(newCount)", color: .blue, isOn: onlyNew) {
                        onlyNew.toggle()
                        selected = nil
                    }
                }
                ForEach(NewsCategory.filterable) { cat in
                    chip(title: "\(cat.label) \(counts[cat] ?? 0)",
                         color: cat.color,
                         isOn: selected == cat && !onlyNew) {
                        selected = (selected == cat && !onlyNew) ? nil : cat
                        onlyNew = false
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
