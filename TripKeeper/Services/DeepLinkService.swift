import UIKit
import MapKit

/// 对外跳转：订票平台唤起、电话、剪贴板、地图导航。
@MainActor
enum DeepLinkService {
    /// 打开平台：URL Scheme（已装 App）→ 网页 → App Store 三级回落。
    static func openPlatform(_ platform: BookingPlatform) {
        if let scheme = platform.schemeURL, UIApplication.shared.canOpenURL(scheme) {
            UIApplication.shared.open(scheme)
            return
        }
        if let web = platform.webURL {
            UIApplication.shared.open(web)
            return
        }
        if let store = platform.appStoreURL {
            UIApplication.shared.open(store)
        }
    }

    /// 打开用户粘贴的订单链接（Universal Link 装了对应 App 会直接进 App）。
    static func open(_ url: URL) {
        UIApplication.shared.open(url)
    }

    static func call(_ number: String) {
        let cleaned = number
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        guard !cleaned.isEmpty, let url = URL(string: "tel://\(cleaned)") else { return }
        UIApplication.shared.open(url)
    }

    static func copy(_ text: String) {
        UIPasteboard.general.string = text
    }

    // MARK: - 地图导航

    enum MapApp: String, CaseIterable, Identifiable {
        case amap
        case baidu
        case apple

        var id: String { rawValue }

        var label: String {
            switch self {
            case .amap: return "高德地图"
            case .baidu: return "百度地图"
            case .apple: return "苹果地图"
            }
        }
    }

    /// 跳转第三方地图导航到坐标点；未安装时回落到对应网页版。
    /// 坐标为 MapKit 返回的坐标系，高德侧 dev=0 不做二次纠偏，百度侧显式声明 coord_type=wgs84。
    static func navigate(to coordinate: CLLocationCoordinate2D, name: String, via app: MapApp) {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "目的地"
        switch app {
        case .amap:
            let deepLink = "iosamap://path?sourceApplication=TripKeeper&dlat=\(coordinate.latitude)&dlon=\(coordinate.longitude)&dname=\(encodedName)&dev=0&t=0"
            if let url = URL(string: deepLink), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else if let web = URL(string: "https://uri.amap.com/navigation?to=\(coordinate.longitude),\(coordinate.latitude),\(encodedName)&mode=car") {
                UIApplication.shared.open(web)
            }
        case .baidu:
            let deepLink = "baidumap://map/direction?destination=\(coordinate.latitude),\(coordinate.longitude)&coord_type=wgs84&mode=driving&src=TripKeeper"
            if let url = URL(string: deepLink), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else if let web = URL(string: "https://map.baidu.com/") {
                UIApplication.shared.open(web)
            }
        case .apple:
            let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            mapItem.name = name
            mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
        }
    }
}
