import Foundation

struct DayWeather {
    let date: Date
    let code: Int
    let tMax: Double
    let tMin: Double

    var tempText: String {
        "\(Int(tMin.rounded()))°~\(Int(tMax.rounded()))°"
    }

    /// WMO weather code → SF Symbol。
    var symbol: String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...57: return "cloud.drizzle.fill"
        case 61...67: return "cloud.rain.fill"
        case 71...77, 85, 86: return "cloud.snow.fill"
        case 80...82: return "cloud.heavyrain.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
}

enum WeatherService {
    private struct Response: Decodable {
        struct Daily: Decodable {
            let time: [String]
            let weatherCode: [Int]
            let temperatureMax: [Double]
            let temperatureMin: [Double]

            enum CodingKeys: String, CodingKey {
                case time
                case weatherCode = "weather_code"
                case temperatureMax = "temperature_2m_max"
                case temperatureMin = "temperature_2m_min"
            }
        }

        let daily: Daily
    }

    /// Open-Meteo 免费日预报（无需 key）。
    /// 只请求「今天起 16 天预报窗口」与行程区间的交集；无交集或请求失败返回空字典，UI 显示「—」。
    static func forecast(latitude: Double, longitude: Double, start: Date, end: Date) async -> [Date: DayWeather] {
        let today = Date().startOfDay
        guard let horizon = Calendar.current.date(byAdding: .day, value: 15, to: today) else { return [:] }
        let clampedStart = max(start.startOfDay, today)
        let clampedEnd = min(end.startOfDay, horizon)
        guard clampedStart <= clampedEnd else { return [:] }

        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"

        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        comps?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", longitude)),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "start_date", value: fmt.string(from: clampedStart)),
            URLQueryItem(name: "end_date", value: fmt.string(from: clampedEnd))
        ]
        guard let url = comps?.url else { return [:] }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(Response.self, from: data)
            var result: [Date: DayWeather] = [:]
            for (index, dayString) in response.daily.time.enumerated() {
                guard let date = fmt.date(from: dayString),
                      index < response.daily.weatherCode.count,
                      index < response.daily.temperatureMax.count,
                      index < response.daily.temperatureMin.count else { continue }
                result[date.startOfDay] = DayWeather(
                    date: date,
                    code: response.daily.weatherCode[index],
                    tMax: response.daily.temperatureMax[index],
                    tMin: response.daily.temperatureMin[index]
                )
            }
            return result
        } catch {
            return [:]
        }
    }
}
