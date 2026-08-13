import Foundation
import MapKit

enum GeocodeService {
    /// 用 MKLocalSearch 把目的地文字转成坐标；查不到返回 nil。
    static func coordinate(for query: String) async -> CLLocationCoordinate2D? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        let search = MKLocalSearch(request: request)
        guard let response = try? await search.start() else { return nil }
        return response.mapItems.first?.placemark.coordinate
    }
}
