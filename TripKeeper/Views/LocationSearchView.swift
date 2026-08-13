import SwiftUI
import MapKit

/// MKLocalSearch 地点搜索，选中后回传。
struct LocationSearchView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var query: String
    @State private var results: [MKMapItem] = []
    @State private var searching = false
    @State private var searched = false

    let onSelect: (MKMapItem) -> Void

    init(initialQuery: String = "", onSelect: @escaping (MKMapItem) -> Void) {
        _query = State(initialValue: initialQuery)
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            List(results, id: \.self) { mapItem in
                Button {
                    onSelect(mapItem)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(mapItem.name ?? "未命名地点")
                            .font(.body)
                            .foregroundStyle(.primary)
                        if let address = mapItem.placemark.title, !address.isEmpty {
                            Text(address)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            }
            .overlay {
                if searching {
                    ProgressView("搜索中…")
                } else if results.isEmpty {
                    ContentUnavailableView(
                        searched ? "没有找到相关地点" : "搜索地点",
                        systemImage: "magnifyingglass",
                        description: Text(searched ? "换个关键词试试" : "输入景点、酒店、车站名后回车")
                    )
                }
            }
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "景点、酒店、车站…"
            )
            .onSubmit(of: .search) {
                Task { await search() }
            }
            .navigationTitle("搜索地点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .task {
                if !query.isEmpty {
                    await search()
                }
            }
        }
    }

    private func search() async {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }
        searching = true
        defer {
            searching = false
            searched = true
        }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = keyword
        let search = MKLocalSearch(request: request)
        results = (try? await search.start())?.mapItems ?? []
    }
}
