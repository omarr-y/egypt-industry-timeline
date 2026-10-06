import SwiftUI

/// The screen you see after tapping an item.
struct NewsDetailView: View {
    let item: NewsItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label(item.kind.label, systemImage: item.kind.icon)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(item.kind.color)

                Text(item.title)
                    .font(.title2.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(item.displayDate) · \(item.source)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !item.figure.isEmpty {
                    Text(item.figure)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(item.kind.color)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(item.kind.color.opacity(0.1),
                                    in: RoundedRectangle(cornerRadius: 10))
                }

                Text(item.summary)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                if !item.sectors.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sectors")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(item.sectors.joined(separator: " · "))
                            .font(.subheadline)
                    }
                }

                if let link = item.link {
                    Link(destination: link) {
                        Label("Read on \(item.source)", systemImage: "safari")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(item.kind.color)
                    .padding(.top, 8)

                    ShareLink(item: link) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
